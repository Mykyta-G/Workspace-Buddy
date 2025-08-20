import Foundation
import AppKit
import Combine
import CoreGraphics
import ApplicationServices

/// Manages workspace presets and handles application launching/closing
class PresetHandler: ObservableObject {
    @Published var presets: [Preset] = []
    @Published var currentPreset: Preset?
    @Published var isLoading = false
    
    private let presetsFile = "presets.json"
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadPresets()
        setupBindings()
    }
    
    // MARK: - Preset Management
    
    /// Force refresh presets from file and update UI
    func forceRefreshPresets() {
        print("🔄 Force refreshing presets...")
        if let loadedPresets = loadPresetsFromFile() {
            print("✅ Successfully loaded \(loadedPresets.count) presets from file")
            DispatchQueue.main.async {
                self.presets = loadedPresets
                print("✅ UI updated with \(self.presets.count) presets")
            }
        } else {
            print("⚠️  Failed to load presets from file, using defaults")
            DispatchQueue.main.async {
                self.presets = Preset.defaults
                print("✅ UI updated with \(self.presets.count) default presets")
            }
            savePresets()
        }
    }
    
    /// Load presets from storage or create defaults
    func refreshPresets() {
        print("Refreshing presets...")
        if let loadedPresets = loadPresetsFromFile() {
            print("Successfully loaded \(loadedPresets.count) presets from file")
            presets = loadedPresets
        } else {
            print("Failed to load presets from file, using defaults")
            presets = Preset.defaults
            savePresets()
        }
        print("Total presets available: \(presets.count)")
    }
    
    private func loadPresets() {
        refreshPresets()
    }
    
    /// Save presets to storage
    func savePresets() {
        savePresetsToFile(presets)
    }
    
    /// Add a new preset
    func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }
    
    /// Update an existing preset
    func updatePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
    
    /// Delete a preset
    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        if currentPreset?.id == preset.id {
            currentPreset = nil
        }
        savePresets()
    }
    
    /// Add an application to a preset
    func addAppToPreset(_ appName: String, preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            var updatedPreset = preset
            let normalizedAppName = normalizeAppName(appName)
            
            if !updatedPreset.apps.contains(where: { $0.name == normalizedAppName }) {
                let newApp = AppWithPosition(name: normalizedAppName)
                updatedPreset.apps.append(newApp)
                presets[index] = updatedPreset
                
                // Update current preset if it's the same one
                if currentPreset?.id == preset.id {
                    currentPreset = updatedPreset
                }
                
                savePresets()
            }
        }
    }
    
    /// Normalize app names for better matching
    private func normalizeAppName(_ appName: String) -> String {
        let normalized = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common app name mappings
        let appMappings = [
            "google": "Google Chrome",
            "chrome": "Google Chrome",
            "safari": "Safari",
            "mail": "Mail",
            "messages": "Messages",
            "notes": "Notes",
            "calendar": "Calendar",
            "finder": "Finder",
            "terminal": "Terminal",
            "xcode": "Xcode",
            "steam": "Steam",
            "discord": "Discord",
            "spotify": "Spotify",
            "slack": "Slack",
            "zoom": "Zoom",
            "teams": "Microsoft Teams",
            "word": "Microsoft Word",
            "excel": "Microsoft Excel",
            "powerpoint": "Microsoft PowerPoint"
        ]
        
        // Check if we have a mapping for this app name
        let lowercased = normalized.lowercased()
        for (key, value) in appMappings {
            if lowercased.contains(key) || key.contains(lowercased) {
                return value
            }
        }
        
        // If no mapping found, return the normalized name
        return normalized
    }
    
    /// Remove an application from a preset
    func removeAppFromPreset(_ appName: String, preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            var updatedPreset = preset
            updatedPreset.apps.removeAll { $0.name == appName }
            presets[index] = updatedPreset
            
            // Update current preset if it's the same one
            if currentPreset?.id == preset.id {
                currentPreset = updatedPreset
            }
            
            savePresets()
        }
    }
    
    /// Add a website to a browser app in a preset
    func addWebsiteToApp(_ website: BrowserWebsite, appName: String, preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            var updatedPreset = preset
            updatedPreset.addWebsite(website, to: appName)
            presets[index] = updatedPreset
            
            // Update current preset if it's the same one
            if currentPreset?.id == preset.id {
                currentPreset = updatedPreset
            }
            
            savePresets()
        }
    }
    
    /// Remove a website from a browser app in a preset
    func removeWebsiteFromApp(_ website: BrowserWebsite, appName: String, preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            var updatedPreset = preset
            updatedPreset.removeWebsite(website, from: appName)
            presets[index] = updatedPreset
            
            // Update current preset if it's the same one
            if currentPreset?.id == preset.id {
                currentPreset = updatedPreset
            }
            
            savePresets()
        }
    }
    
    // MARK: - Window Position Management
    
    /// Capture current window positions for all running apps
    private func captureCurrentWindowPositions() -> [String: [WindowPosition]] {
        var appPositions: [String: [WindowPosition]] = [:]
        
        // Get all window information using Core Graphics
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        
        // Group windows by owner name (app name)
        var windowsByApp: [String: [[String: Any]]] = [:]
        
        for windowInfo in windowList {
            if let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
               let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any] {
                
                // Only include windows from regular applications (not system windows)
                if let runningApps = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == ownerName }),
                   runningApps.activationPolicy == .regular {
                    
                    if windowsByApp[ownerName] == nil {
                        windowsByApp[ownerName] = []
                    }
                    
                    var windowInfoWithBounds = windowInfo
                    windowInfoWithBounds["bounds"] = bounds
                    windowsByApp[ownerName]?.append(windowInfoWithBounds)
                }
            }
        }
        
        // Convert to WindowPosition objects
        for (appName, windows) in windowsByApp {
            var positions: [WindowPosition] = []
            
            for windowInfo in windows {
                if let bounds = windowInfo["bounds"] as? [String: Any],
                   let x = bounds["X"] as? Double,
                   let y = bounds["Y"] as? Double,
                   let width = bounds["Width"] as? Double,
                   let height = bounds["Height"] as? Double {
                    
                    // Determine which screen this window is on
                    let windowCenter = CGPoint(x: x + width/2, y: y + height/2)
                    let screenIndex = getScreenIndex(for: windowCenter)
                    
                    let position = WindowPosition(
                        x: x,
                        y: y,
                        width: width,
                        height: height,
                        screenIndex: screenIndex
                    )
                    positions.append(position)
                }
            }
            
            if !positions.isEmpty {
                appPositions[appName] = positions
            }
        }
        
        return appPositions
    }
    
    /// Get the screen index for a given point
    private func getScreenIndex(for point: CGPoint) -> Int {
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            if screen.frame.contains(point) {
                return index
            }
        }
        return 0 // Default to first screen
    }
    
    /// Restore window positions for apps in a preset
    private func restoreWindowPositions(for preset: Preset) async {
        // Wait a bit for apps to fully launch and create their windows
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        for appWithPosition in preset.apps {
            let appName = appWithPosition.name
            let positions = appWithPosition.windowPositions
            
            // Find the running app
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.localizedName == appName }) {
                
                // Use Accessibility API to restore window positions
                restoreWindowPositionsForApp(app, positions: positions)
            }
        }
    }
    
    /// Restore window positions for a specific app using Accessibility API
    private func restoreWindowPositionsForApp(_ app: NSRunningApplication, positions: [WindowPosition]) {
        // Get the app's accessibility element
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Get all windows for this app
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        guard result == .success, let windows = windowList as? [AXUIElement] else {
            print("Could not get windows for \(app.localizedName ?? "unknown app")")
            return
        }
        
        // Restore positions for each window
        for (index, position) in positions.enumerated() {
            if index < windows.count {
                let window = windows[index]
                restoreWindowPosition(window: window, to: position)
            }
        }
    }
    
    /// Restore a specific window to a given position using Accessibility API
    private func restoreWindowPosition(window: AXUIElement, to position: WindowPosition) {
        // Ensure the window is on the correct screen
        if position.screenIndex < NSScreen.screens.count {
            let targetScreen = NSScreen.screens[position.screenIndex]
            
            // Convert coordinates to the target screen's coordinate system
            let screenFrame = targetScreen.frame
            let newX = position.x + screenFrame.origin.x
            let newY = position.y + screenFrame.origin.y
            
            // Create the new position value
            var newPosition = CGPoint(x: newX, y: newY)
            var newSize = CGSize(width: position.width, height: position.height)
            
            // Set the window position using Accessibility API
            if let positionValue = AXValueCreate(.cgPoint, &newPosition) {
                let positionResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
                if positionResult != .success {
                    print("Failed to set window position: \(positionResult)")
                }
            }
            
            // Set size
            if let sizeValue = AXValueCreate(.cgSize, &newSize) {
                let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
                if sizeResult != .success {
                    print("Failed to set window size: \(sizeResult)")
                }
            }
        }
    }
    
    // MARK: - Workspace Switching
    
    /// Switch to a specific preset
    func switchToPreset(_ preset: Preset) async {
        print("Starting to switch to preset: \(preset.name)")
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Capture current window positions before switching
            let currentPositions = captureCurrentWindowPositions()
            
            // Update the current preset with window positions if it exists
            if let current = currentPreset {
                var updatedCurrent = current
                for (appName, positions) in currentPositions {
                    updatedCurrent.updateWindowPositions(for: appName, positions: positions)
                }
                
                // Update the preset in our list
                if let index = presets.firstIndex(where: { $0.id == current.id }) {
                    presets[index] = updatedCurrent
                }
                
                // Save the updated preset
                savePresets()
            }
            
            // Check if there are other running apps not in the preset
            let otherRunningApps = getOtherRunningApps(notIn: preset)
            
            if !otherRunningApps.isEmpty {
                // Ask user what to do with other running apps
                let shouldTerminateOthers = await askUserAboutOtherApps(otherRunningApps)
                
                if shouldTerminateOthers {
                    // Terminate other running apps
                    try await terminateApps(otherRunningApps)
                }
            }
            
            // Close previous apps if needed
            if let current = currentPreset, preset.closePrevious {
                print("Closing previous apps from current preset")
                try await closeApps(from: current)
            }
            
            // Launch new apps
            print("Launching apps for preset: \(preset.name)")
            print("Apps to launch: \(preset.apps.map { $0.name })")
            try await launchApps(from: preset)
            
            // Restore window positions for the new preset
            await restoreWindowPositions(for: preset)
            
            await MainActor.run {
                currentPreset = preset
                isLoading = false
            }
            
            print("Successfully switched to preset: \(preset.name)")
            
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("Error switching to preset: \(error)")
        }
    }
    
    /// Launch applications for a preset
    private func launchApps(from preset: Preset) async throws {
        print("Starting to launch apps for preset: \(preset.name)")
        for appWithPosition in preset.apps {
            print("Launching app: \(appWithPosition.name)")
            try await launchApp(named: appWithPosition.name)
            
            // If this is a browser app with websites, open them
            if appWithPosition.isBrowser && !appWithPosition.websites.isEmpty {
                print("Opening websites for browser app: \(appWithPosition.name)")
                await openWebsitesForApp(appWithPosition)
            }
        }
        print("Finished launching all apps for preset: \(preset.name)")
    }
    
    /// Open websites for a browser app
    private func openWebsitesForApp(_ appWithPosition: AppWithPosition) async {
        // Wait a bit for the browser to fully launch
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        for website in appWithPosition.websites {
            if website.isValidURL {
                await openWebsite(website.url, in: appWithPosition.name)
            }
        }
    }
    
    /// Open a specific website in a browser
    private func openWebsite(_ urlString: String, in browserName: String) async {
        guard let url = URL(string: urlString) else { return }
        
        // Use NSWorkspace to open the URL, which will use the default browser
        // or we can try to open it in the specific browser if it's running
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Check if the browser is running, but always use NSWorkspace.open for consistency
        let _ = runningApps.first(where: { $0.localizedName == browserName })
        
        // Use NSWorkspace to open the URL (will use default browser if specific one isn't available)
        NSWorkspace.shared.open(url)
    }
    
    /// Close applications from a preset
    private func closeApps(from preset: Preset) async throws {
        for appWithPosition in preset.apps {
            try await closeApp(named: appWithPosition.name)
        }
    }
    
    // MARK: - Application Management
    
    /// Launch an application by name
    private func launchApp(named appName: String) async throws {
        print("Attempting to launch app: \(appName)")
        
        // Try to find the app in common locations
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "/Applications/Google Chrome.app", // Handle Google Chrome specifically
            "/Applications/Microsoft Word.app", // Handle Microsoft apps
            "/Applications/Microsoft Excel.app",
            "/Applications/Microsoft PowerPoint.app"
        ]
        
        for path in appPaths {
            if fileManager.fileExists(atPath: path) {
                print("Found app at path: \(path)")
                let url = URL(fileURLWithPath: path)
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                
                try await NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: config
                )
                print("Successfully launched app: \(appName)")
                return
            }
        }
        
        // If not found in common locations, try to launch by bundle identifier
        print("App not found in common locations, trying bundle identifier for: \(appName)")
        try await launchAppByBundleIdentifier(appName)
    }
    
    /// Launch app by bundle identifier (for apps like Steam, Discord, etc.)
    private func launchAppByBundleIdentifier(_ appName: String) async throws {
        // Common app bundle identifiers
        let bundleIdentifiers = [
            "Google Chrome": "com.google.Chrome",
            "Steam": "com.valvesoftware.Steam",
            "Discord": "com.hnc.Discord",
            "Spotify": "com.spotify.client",
            "Slack": "com.tinyspeck.slackmacgap",
            "Zoom": "us.zoom.xos",
            "Microsoft Teams": "com.microsoft.teams",
            "Microsoft Word": "com.microsoft.Word",
            "Microsoft Excel": "com.microsoft.Excel",
            "Microsoft PowerPoint": "com.microsoft.Powerpoint"
        ]
        
        if let bundleId = bundleIdentifiers[appName] {
            print("Attempting to launch \(appName) with bundle ID: \(bundleId)")
            
            // For now, just fall back to trying to find the app in Applications
            // since the bundle identifier method doesn't exist
            print("Bundle identifier method not available, trying to find in Applications")
            try await findAndLaunchApp(appName)
        } else {
            print("No bundle identifier found for \(appName), trying to find in Applications")
            try await findAndLaunchApp(appName)
        }
    }
    
    /// Fallback method to find and launch an app
    private func findAndLaunchApp(_ appName: String) async throws {
        // Try to find the app by searching in common locations with fuzzy matching
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities"
        ]
        
        for searchPath in searchPaths {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: searchPath) {
                for item in contents {
                    if item.hasSuffix(".app") {
                        let appNameWithoutExtension = String(item.dropLast(4))
                        // Check if the app name contains our target name (case-insensitive)
                        if appNameWithoutExtension.lowercased().contains(appName.lowercased()) ||
                           appName.lowercased().contains(appNameWithoutExtension.lowercased()) {
                            let fullPath = "\(searchPath)/\(item)"
                            print("Found potential match: \(fullPath)")
                            
                            let url = URL(fileURLWithPath: fullPath)
                            let config = NSWorkspace.OpenConfiguration()
                            config.activates = true
                            
                            try await NSWorkspace.shared.openApplication(
                                at: url,
                                configuration: config
                            )
                            print("Successfully launched app using fuzzy matching: \(appName)")
                            return
                        }
                    }
                }
            }
        }
        
        print("Could not find or launch app: \(appName)")
        throw NSError(domain: "PresetHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not launch app: \(appName)"])
    }
    
    /// Close an application by name
    private func closeApp(named appName: String) async throws {
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            if app.localizedName == appName {
                app.terminate()
                break
            }
        }
    }
    
    // MARK: - File Operations
    
    /// Load presets from JSON file
    private func loadPresetsFromFile() -> [Preset]? {
        guard let documentsPath = getDocumentsDirectory() else { 
            print("❌ ERROR: Could not get documents directory for loading presets")
            return nil 
        }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        print("📂 Looking for presets file at: \(fileURL)")
        
        // Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("📂 Presets file does not exist, will create with defaults")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("📂 Successfully read presets file, size: \(data.count) bytes")
            
            // Try to decode as new format first
            do {
                let presets = try JSONDecoder().decode([Preset].self, from: data)
                print("✅ Successfully decoded as new format, loaded \(presets.count) presets")
                return presets
            } catch {
                print("⚠️  Failed to decode as new format: \(error)")
                // If new format fails, try to migrate from old format
                print("🔄 Attempting to migrate from old preset format...")
                if let migratedPresets = migrateFromOldFormat(data: data) {
                    // Save the migrated presets in new format
                    print("✅ Migration successful, saving migrated presets")
                    savePresetsToFile(migratedPresets)
                    return migratedPresets
                }
                print("❌ Migration failed")
                throw error
            }
        } catch {
            print("❌ ERROR loading presets: \(error)")
            print("❌ File path: \(fileURL)")
            print("❌ Documents path: \(documentsPath)")
            return nil
        }
    }
    
    /// Migrate from old preset format to new format
    private func migrateFromOldFormat(data: Data) -> [Preset]? {
        print("Attempting to migrate from old preset format...")
        do {
            // Try to decode as old format (dictionary with string keys)
            let oldFormat = try JSONDecoder().decode([String: OldPresetFormat].self, from: data)
            print("Successfully decoded old format with \(oldFormat.count) presets")
            
            var newPresets: [Preset] = []
            
            for (name, oldPreset) in oldFormat {
                print("Migrating preset: \(name) with \(oldPreset.apps.count) apps")
                let apps = oldPreset.apps.map { AppWithPosition(name: $0) }
                let newPreset = Preset(
                    name: name,
                    description: oldPreset.description,
                    apps: apps,
                    closePrevious: oldPreset.close_previous,
                    icon: getIconForPreset(name: name)
                )
                newPresets.append(newPreset)
            }
            
            print("Successfully migrated \(newPresets.count) presets from old format")
            return newPresets
            
        } catch {
            print("Failed to migrate from old format: \(error)")
            return nil
        }
    }
    
    /// Get appropriate icon for preset based on name
    private func getIconForPreset(name: String) -> String {
        let lowercasedName = name.lowercased()
        
        if lowercasedName.contains("work") || lowercasedName.contains("productivity") {
            return "briefcase"
        } else if lowercasedName.contains("school") || lowercasedName.contains("education") {
            return "book"
        } else if lowercasedName.contains("game") || lowercasedName.contains("entertainment") {
            return "gamecontroller"
        } else if lowercasedName.contains("relax") || lowercasedName.contains("social") {
            return "heart"
        } else {
            return "folder"
        }
    }
    
    /// Save presets to JSON file
    private func savePresetsToFile(_ presets: [Preset]) {
        guard let documentsPath = getDocumentsDirectory() else { 
            print("❌ ERROR: Could not get documents directory for saving presets")
            return 
        }
        
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        print("💾 Saving presets to: \(fileURL)")
        
        do {
            let data = try JSONEncoder().encode(presets)
            print("📊 Encoded \(presets.count) presets, data size: \(data.count) bytes")
            
            // Create directory if it doesn't exist
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                print("📁 Created directory: \(directory)")
            }
            
            try data.write(to: fileURL)
            print("✅ Successfully saved presets to file")
            
            // Verify the file was written
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📁 File saved successfully, size: \(fileSize) bytes")
            } else {
                print("⚠️  Warning: File doesn't exist after save operation")
            }
            
        } catch {
            print("❌ ERROR saving presets: \(error)")
            print("❌ File path: \(fileURL)")
            print("❌ Documents path: \(documentsPath)")
        }
    }
    
    /// Get the documents directory for storing presets
    private func getDocumentsDirectory() -> URL? {
        // First try to get the user's documents directory
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            print("Using user documents directory: \(documentsPath)")
            return documentsPath
        }
        
        // Fallback to the user's application support directory
        if let appSupportPath = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appFolder = appSupportPath.appendingPathComponent("Workspace-Buddy")
            
            // Create the app folder if it doesn't exist
            if !fileManager.fileExists(atPath: appFolder.path) {
                do {
                    try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
                    print("Created app support directory: \(appFolder)")
                } catch {
                    print("Failed to create app support directory: \(error)")
                    return nil
                }
            }
            
            print("Using application support directory: \(appFolder)")
            return appFolder
        }
        
        // Last resort: try the user's home directory
        let homePath = fileManager.homeDirectoryForCurrentUser
        let appFolder = homePath.appendingPathComponent(".Workspace-Buddy")
        
        if !fileManager.fileExists(atPath: appFolder.path) {
            do {
                try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
                print("Created home directory app folder: \(appFolder)")
            } catch {
                print("Failed to create home directory app folder: \(error)")
                return nil
            }
        }
        
        print("Using home directory app folder: \(appFolder)")
        return appFolder
    }
    
    // MARK: - Bindings
    
    /// Setup automatic saving when presets change
    private func setupBindings() {
        // Save presets whenever they change
        $presets
            .sink { [weak self] newPresets in
                print("🔄 Presets changed, saving \(newPresets.count) presets...")
                self?.savePresets()
            }
            .store(in: &cancellables)
        
        // Also save when current preset changes
        $currentPreset
            .sink { [weak self] _ in
                print("🔄 Current preset changed, saving presets...")
                self?.savePresets()
            }
            .store(in: &cancellables)
    }
    
    /// Get other running apps that are not in the current preset
    private func getOtherRunningApps(notIn preset: Preset) -> [NSRunningApplication] {
        let runningApps = NSWorkspace.shared.runningApplications
        let presetAppNames = Set(preset.apps.map { $0.name.lowercased() })
        
        return runningApps.filter { app in
            guard let appName = app.localizedName else { return false }
            return !presetAppNames.contains(appName.lowercased()) && 
                   app.activationPolicy == .regular // Only include regular apps, not system services
        }
    }
    
    /// Ask user whether to terminate other running apps
    private func askUserAboutOtherApps(_ otherApps: [NSRunningApplication]) async -> Bool {
        return await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Other Applications Running"
            alert.informativeText = "The following applications are currently running but not in your preset:\n\n\(otherApps.compactMap { $0.localizedName }.joined(separator: "\n"))\n\nWould you like to terminate these applications to clean up your workspace?"
            alert.addButton(withTitle: "Terminate Others")
            alert.addButton(withTitle: "Keep Them Active")
            
            let response = alert.runModal()
            return response == .alertFirstButtonReturn
        }
    }
    
    /// Terminate a list of applications
    private func terminateApps(_ apps: [NSRunningApplication]) async throws {
        for app in apps {
            app.terminate()
        }
        
        // Wait a bit for apps to terminate
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    /// Manually trigger save and refresh cycle
    func saveAndRefresh() {
        print("💾 Manual save and refresh triggered...")
        savePresets()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.forceRefreshPresets()
        }
    }
}
