import Foundation
import AppKit
import Combine
import CoreGraphics
import ApplicationServices

/// Manages workspace presets and handles application launching/closing
class PresetHandler: ObservableObject {
    // CRITICAL FIX: Singleton pattern to prevent multiple instances
    static let shared = PresetHandler()
    
    @Published var presets: [Preset] = []
    @Published var currentPreset: Preset?
    @Published var isLoading = false
    
    private let presetsFile = "presets.json"
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    // CRITICAL FIX: Private init to enforce singleton
    private init() {
        print("🚀 BULLETPROOF INIT: Initializing PresetHandler (Singleton)...")
        
        // Load presets from storage
        loadPresets()
        
        // Setup automatic saving when presets change
        setupBindings()
        
        // Start periodic save mechanism for ultimate protection
        startPeriodicSave()
        
        print("✅ BULLETPROOF INIT: PresetHandler initialized with all protection layers")
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
            print("⚠️  Failed to load presets from file, checking if we have existing presets...")
            
            // Check if we have existing presets in memory that should be preserved
            if !presets.isEmpty && presets != Preset.defaults {
                print("✅ Preserving existing user-created presets (\(presets.count) presets)")
                // Don't overwrite with defaults - keep what the user has
                return
            }
            
            print("⚠️  No existing presets found, using defaults temporarily")
            DispatchQueue.main.async {
                self.presets = Preset.defaults
                print("✅ UI updated with \(self.presets.count) default presets")
            }
            // Don't automatically save defaults - only save if user explicitly requests it
            // This prevents overwriting user's saved presets with defaults
        }
    }
    
    /// Load presets from storage or create defaults - BULLETPROOF VERSION
    func refreshPresets() {
        print("🔄 BULLETPROOF REFRESH: Starting preset refresh...")
        
        // Layer 1: Try to load from file
        if let loadedPresets = loadPresetsFromFile() {
            print("✅ BULLETPROOF REFRESH: Successfully loaded \(loadedPresets.count) presets from file")
            presets = loadedPresets
        } else {
            print("⚠️  BULLETPROOF REFRESH: Failed to load from file, trying UserDefaults backup...")
            
            // Layer 2: Try to restore from UserDefaults backup
            if let recoveredPresets = recoverPresetsFromBackup() {
                print("✅ Recovered \(recoveredPresets.count) presets from backup")
                presets = recoveredPresets
                
                // Immediately save the recovered presets to file
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("💾 Saving recovered presets to file...")
                    self.savePresetsToFile(self.presets)
                }
            } else {
                print("⚠️ No backup available, checking memory...")
                
                // Layer 3: Check if we have existing presets in memory that should be preserved
                if !presets.isEmpty && presets != Preset.defaults {
                    print("✅ BULLETPROOF REFRESH: Preserving existing user-created presets (\(presets.count) presets)")
                    // Don't overwrite with defaults - keep what the user has
                    return
                }
                
                print("⚠️  BULLETPROOF REFRESH: No presets found, using defaults temporarily")
                presets = Preset.defaults
                // Don't automatically save defaults - only save if user explicitly requests it
                // This prevents overwriting user's saved presets with defaults
            }
        }
        print("📊 BULLETPROOF REFRESH: Total presets available: \(presets.count)")
    }
    
    private func loadPresets() {
        refreshPresets()
    }
    
    /// Save presets to storage - BULLETPROOF VERSION
    func savePresets() {
        print("💾 Starting save operation...")
        
        // Layer 1: Immediate save
        savePresetsToFile(presets)
        
        // Layer 2: Backup save after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("💾 Layer 2 - Backup save...")
            self.savePresetsToFile(self.presets)
        }
        
        // Layer 3: Verification save after longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("💾 BULLETPROOF SAVE: Layer 3 - Verification save...")
            if self.doPresetsNeedSaving() {
                print("⚠️  BULLETPROOF SAVE: Verification failed, retrying...")
                self.savePresetsToFile(self.presets)
            } else {
                print("✅ BULLETPROOF SAVE: All layers successful")
            }
        }
        
        // Layer 4: Force save to UserDefaults as backup
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: "presets_backup_data")
            defaults.set(Date(), forKey: "presets_backup_timestamp")
            print("💾 BULLETPROOF SAVE: Layer 4 - UserDefaults backup created")
        }
    }
    
    /// Explicitly save user presets (called when user makes changes)
    func saveUserPresets() {
        print("💾 User explicitly requested to save presets")
        savePresetsToFile(presets)
        
        // Mark that we have user-created presets
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasUserCreatedPresets")
        defaults.set(Date(), forKey: "lastPresetSaveDate")
        print("✅ Marked presets as user-created and saved timestamp")
    }
    
    /// Force save presets to ensure they persist (called during app lifecycle events)
    func forceSavePresets() {
        print("💾 Force saving presets to ensure persistence...")
        
        // Only save if we have non-default presets
        if presets != Preset.defaults {
            savePresetsToFile(presets)
            
            // Mark that we have user-created presets
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "hasUserCreatedPresets")
            defaults.set(Date(), forKey: "lastPresetSaveDate")
            print("✅ Force saved user presets and updated timestamp")
        } else {
            print("⚠️  Not force saving default presets")
        }
    }
    
    /// Check if we have user-created presets that should be preserved
    func hasUserCreatedPresets() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "hasUserCreatedPresets") || presets != Preset.defaults
    }
    
    /// Save presets only if they're not the default presets
    func savePresetsIfNotDefaults() {
        // Only save if presets are different from defaults
        if presets != Preset.defaults {
            print("💾 Auto-saving non-default presets")
            savePresetsToFile(presets)
        } else {
            print("⚠️  Not auto-saving default presets - user should save manually")
        }
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
        print("🗑️ Deleting preset: \(preset.name)")
        presets.removeAll { $0.id == preset.id }
        if currentPreset?.id == preset.id {
            currentPreset = nil
        }
        print("💾 Saving presets after deletion...")
        savePresets()
        
        // Force save to ensure deletion is persisted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🔄 Force saving after preset deletion...")
            self.forceSavePresets()
        }
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
    
    /// Restore window positions while respecting current app state and manual changes
    private func restoreWindowPositionsRespectingCurrentState(for preset: Preset) async {
        // Wait a bit for apps to fully launch and create their windows
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        for appWithPosition in preset.apps {
            let appName = appWithPosition.name
            let presetPositions = appWithPosition.windowPositions
            
            // Find the running app
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.localizedName == appName }) {
                
                // Check if this app is already running and has been manually positioned
                let currentPositions = captureCurrentWindowPositions()
                let hasManualPositions = currentPositions[appName] != nil && !currentPositions[appName]!.isEmpty
                
                if hasManualPositions {
                    print("⚠️ App \(appName) has manual positions - preserving them instead of using preset")
                    // Don't override manual positions - preserve what the user has done
                    continue
                }
                
                // Only restore preset positions if the app doesn't have manual positions
                if !presetPositions.isEmpty {
                    print("✅ Restoring preset positions for \(appName) (no manual positions detected)")
                    restoreWindowPositionsForApp(app, positions: presetPositions)
                } else {
                    print("ℹ️ No preset positions for \(appName) - leaving as is")
                }
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
            // Always preserve manual changes - capture current window positions before switching
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
            
            // Always restore window positions while respecting manual changes
            await restoreWindowPositionsRespectingCurrentState(for: preset)
            
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
            
            // Check if app is already running
            let runningApps = NSWorkspace.shared.runningApplications
            let isAlreadyRunning = runningApps.contains { app in
                app.localizedName == appWithPosition.name
            }
            
            if isAlreadyRunning {
                print("ℹ️ App \(appWithPosition.name) is already running - preserving current state")
                // Don't relaunch - preserve current window positions and state
                continue
            }
            
            // Only launch if not already running
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
                    // Save the migrated presets in new format IMMEDIATELY to prevent future overwrites
                    print("✅ Migration successful, saving migrated presets to new format")
                    savePresetsToFile(migratedPresets)
                    
                    // Also mark that we have user-created presets to prevent future overwrites
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    print("✅ Marked presets as user-created to prevent future overwrites")
                    
                    return migratedPresets
                }
                
                // CRITICAL FIX: If migration fails, DON'T return nil - try to preserve what we can
                print("⚠️  Migration failed, but attempting to preserve existing presets...")
                if let preservedPresets = preserveExistingPresetsFromOldFormat(data: data) {
                    print("✅ Successfully preserved existing presets despite migration failure")
                    return preservedPresets
                }
                
                print("❌ Migration and preservation both failed, will use default presets")
                // Don't throw error here, just return nil to use defaults
                return nil
            }
        } catch {
            print("❌ ERROR loading presets: \(error)")
            print("❌ File path: \(fileURL)")
            print("❌ Documents path: \(documentsPath)")
            return nil
        }
    }
    
    /// Preserve existing presets from old format even when migration fails
    private func preserveExistingPresetsFromOldFormat(data: Data) -> [Preset]? {
        print("🔄 Attempting to preserve existing presets from old format...")
        
        do {
            // Try to parse as raw JSON to extract what we can
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var preservedPresets: [Preset] = []
                
                for (name, presetData) in json {
                    if let presetDict = presetData as? [String: Any],
                       let description = presetDict["description"] as? String,
                       let appsArray = presetDict["apps"] as? [String],
                       let closePrevious = presetDict["close_previous"] as? Bool {
                        
                        print("Preserving preset: \(name) with \(appsArray.count) apps")
                        let apps = appsArray.map { AppWithPosition(name: $0) }
                        let newPreset = Preset(
                            name: name,
                            description: description,
                            apps: apps,
                            closePrevious: closePrevious,
                            icon: getIconForPreset(name: name)
                        )
                        preservedPresets.append(newPreset)
                    }
                }
                
                if !preservedPresets.isEmpty {
                    print("✅ Successfully preserved \(preservedPresets.count) presets")
                    
                    // Immediately save these preserved presets in new format
                    savePresetsToFile(preservedPresets)
                    
                    // Mark as user-created to prevent future overwrites
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    print("✅ Marked preserved presets as user-created to prevent future overwrites")
                    
                    return preservedPresets
                }
            }
        } catch {
            print("❌ Failed to preserve existing presets: \(error)")
        }
        
        return nil
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
            // Try alternative migration approach
            return migrateFromOldFormatAlternative(data: data)
        }
    }
    
    /// Alternative migration method for edge cases
    private func migrateFromOldFormatAlternative(data: Data) -> [Preset]? {
        print("Attempting alternative migration method...")
        do {
            // Try to parse as raw JSON first
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                var newPresets: [Preset] = []
                
                for (name, presetData) in json {
                    if let presetDict = presetData as? [String: Any],
                       let description = presetDict["description"] as? String,
                       let appsArray = presetDict["apps"] as? [String],
                       let closePrevious = presetDict["close_previous"] as? Bool {
                        
                        print("Alternative migration: \(name) with \(appsArray.count) apps")
                        let apps = appsArray.map { AppWithPosition(name: $0) }
                        let newPreset = Preset(
                            name: name,
                            description: description,
                            apps: apps,
                            closePrevious: closePrevious,
                            icon: getIconForPreset(name: name)
                        )
                        newPresets.append(newPreset)
                    }
                }
                
                if !newPresets.isEmpty {
                    print("Alternative migration successful: \(newPresets.count) presets")
                    return newPresets
                }
            }
        } catch {
            print("Alternative migration failed: \(error)")
        }
        
        return nil
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
            
            // CRITICAL FIX: Use unique temporary filename to prevent conflicts
            let uniqueTempName = "presets_\(UUID().uuidString).tmp"
            let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(uniqueTempName)
            
            // Write to unique temporary file first
            try data.write(to: tempURL)
            print("✅ Successfully wrote to temporary file: \(uniqueTempName)")
            
            // Remove existing file if it exists to prevent conflicts
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("🗑️ Removed existing presets file to prevent conflicts")
            }
            
            // Move the temporary file to the final location
            try fileManager.moveItem(at: tempURL, to: fileURL)
            print("✅ Successfully moved temporary file to final location")
            
            print("✅ Successfully saved presets to file")
            
            // Verify the file was written
            if fileManager.fileExists(atPath: fileURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📁 File saved successfully, size: \(fileSize) bytes")
                
                // Also verify the file can be read back
                let verifyData = try Data(contentsOf: fileURL)
                if verifyData.count == data.count {
                    print("✅ File verification successful - data integrity confirmed")
                } else {
                    print("⚠️  Warning: File verification failed - size mismatch")
                }
            } else {
                print("⚠️  Warning: File doesn't exist after save operation")
            }
            
        } catch {
            print("❌ ERROR saving presets: \(error)")
            print("❌ File path: \(fileURL)")
            print("❌ Documents path: \(documentsPath)")
            
            // Try to clean up any temporary files
            let tempURL = fileURL.appendingPathExtension("tmp")
            if fileManager.fileExists(atPath: tempURL.path) {
                try? fileManager.removeItem(at: tempURL)
                print("🧹 Cleaned up temporary file")
            }
            
            // CRITICAL FALLBACK: Try direct write if move fails
            print("🔄 Attempting direct write fallback...")
            do {
                let data = try JSONEncoder().encode(presets)
                try data.write(to: fileURL)
                print("✅ Fallback direct write successful")
            } catch {
                print("❌ Fallback direct write also failed: \(error)")
            }
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
    
    /// Setup automatic saving when presets change - BULLETPROOF VERSION
    private func setupBindings() {
        // Save presets whenever they change - be aggressive about saving user changes
        $presets
            .sink { [weak self] newPresets in
                print("🔄 BULLETPROOF BINDINGS: Presets changed, checking if should save...")
                print("📊 New presets count: \(newPresets.count)")
                print("📊 Current presets count: \(self?.presets.count ?? 0)")
                
                // Always save if presets are not defaults (user has made changes)
                if newPresets != Preset.defaults {
                    print("💾 BULLETPROOF BINDINGS: Auto-saving user-modified presets...")
                    self?.savePresets()
                    
                    // Mark that we have user-created presets
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    print("✅ BULLETPROOF BINDINGS: Marked presets as user-created and saved timestamp")
                    
                    // Multiple verification saves to ensure nothing is lost
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let self = self {
                            print("🔍 BULLETPROOF BINDINGS: Verification save 1...")
                            if self.doPresetsNeedSaving() {
                                print("⚠️  BULLETPROOF BINDINGS: Verification 1 failed, retrying...")
                                self.savePresets()
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let self = self {
                            print("🔍 BULLETPROOF BINDINGS: Verification save 2...")
                            if self.doPresetsNeedSaving() {
                                print("⚠️  BULLETPROOF BINDINGS: Verification 2 failed, retrying...")
                                self.savePresets()
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if let self = self {
                            print("🔍 BULLETPROOF BINDINGS: Final verification save...")
                            if self.doPresetsNeedSaving() {
                                print("⚠️  BULLETPROOF BINDINGS: Final verification failed, force saving...")
                                self.forceSavePresets()
                            } else {
                                print("✅ BULLETPROOF BINDINGS: All verification saves successful")
                            }
                        }
                    }
                } else {
                    print("⚠️  BULLETPROOF BINDINGS: Not auto-saving default presets - user should save manually")
                }
            }
            .store(in: &cancellables)
        
        // Also save when current preset changes
        $currentPreset
            .sink { [weak self] _ in
                print("🔄 BULLETPROOF BINDINGS: Current preset changed, checking if should save...")
                // Always save if current presets are not defaults
                if let currentPresets = self?.presets, currentPresets != Preset.defaults {
                    print("💾 BULLETPROOF BINDINGS: Auto-saving non-default presets...")
                    self?.savePresets()
                } else {
                    print("⚠️  BULLETPROOF BINDINGS: Not auto-saving default presets - user should save manually")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Get other running apps that are not in the current preset
    private func getOtherRunningApps(notIn preset: Preset) -> [NSRunningApplication] {
        let runningApps = NSWorkspace.shared.runningApplications
        let presetAppNames = Set(preset.apps.map { $0.name.lowercased() })
        
        return runningApps.filter { app in
            guard let appName = app.localizedName else { return false }
            
            // Don't include Workspace-Buddy itself
            if appName.lowercased() == "workspace-buddy" || appName.lowercased() == "workspace buddy" {
                return false
            }
            
            // Don't include the current app bundle
            if app.bundleIdentifier == Bundle.main.bundleIdentifier {
                return false
            }
            
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
    
    /// Force a complete reset and migration of presets
    func forceResetAndMigrate() {
        print("🔄 Force reset and migration triggered...")
        
        // Get the documents directory
        guard let documentsPath = getDocumentsDirectory() else {
            print("❌ Could not get documents directory for reset")
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        // Check if old format file exists
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                print("📂 Found existing presets file, attempting migration...")
                
                if let migratedPresets = migrateFromOldFormat(data: data) {
                    print("✅ Migration successful, updating presets")
                    DispatchQueue.main.async {
                        self.presets = migratedPresets
                        // Don't auto-save migrated presets - let user decide
                        print("✅ Migration complete - presets loaded but not auto-saved")
                    }
                } else {
                    print("❌ Migration failed, but preserving existing presets")
                    // Don't overwrite with defaults - preserve what user has
                    DispatchQueue.main.async {
                        // Keep current presets if they exist, otherwise use defaults without saving
                        if self.presets.isEmpty {
                            self.presets = Preset.defaults
                            print("⚠️  Using defaults temporarily - user should save manually")
                        } else {
                            print("✅ Keeping existing presets despite migration failure")
                        }
                    }
                }
            } catch {
                print("❌ Error reading existing file: \(error), preserving current presets")
                DispatchQueue.main.async {
                    // Keep current presets if they exist, otherwise use defaults without saving
                    if self.presets.isEmpty {
                        self.presets = Preset.defaults
                        print("⚠️  Using defaults temporarily - user should save manually")
                    } else {
                        print("✅ Keeping existing presets despite read error")
                    }
                }
            }
        } else {
            print("📂 No existing presets file, using defaults temporarily")
            DispatchQueue.main.async {
                self.presets = Preset.defaults
                // Don't auto-save defaults - let user decide when to save
                print("⚠️  Using defaults temporarily - user should save manually")
            }
        }
    }
    
    /// Safe initialization that doesn't overwrite existing presets
    func safeInitializePresets() {
        print("🔄 Safe initialization - checking for existing presets...")
        
        // Try to load existing presets first
        if let loadedPresets = loadPresetsFromFile() {
            print("✅ Found existing presets, using them")
            DispatchQueue.main.async {
                self.presets = loadedPresets
            }
            
            // Mark that we have user-created presets to prevent future overwrites
            let defaults = UserDefaults.standard
            defaults.set(true, forKey: "hasUserCreatedPresets")
            defaults.set(Date(), forKey: "lastPresetSaveDate")
            print("✅ Marked existing presets as user-created to prevent future overwrites")
            
        } else {
            print("📂 No existing presets file found, checking if we have presets in memory...")
            
            // Check if we already have user-created presets in memory
            if !presets.isEmpty && presets != Preset.defaults {
                print("✅ Preserving existing user-created presets in memory (\(presets.count) presets)")
                // Don't overwrite with defaults - keep what the user has
                return
            }
            
            // Check if we have user-created presets flag set
            let defaults = UserDefaults.standard
            let hasUserCreatedPresets = defaults.bool(forKey: "hasUserCreatedPresets")
            
            if hasUserCreatedPresets {
                print("✅ User has previously created presets - preserving them")
                // Don't overwrite with defaults - keep what the user has
                return
            }
            
            // CRITICAL FIX: Check if we have any existing presets file before using defaults
            if hasExistingPresetsFile() {
                print("⚠️  Found existing presets file - attempting to load instead of using defaults")
                // Try to force load existing presets
                if let existingPresets = forceLoadExistingPresets() {
                    print("✅ Successfully loaded existing presets instead of defaults")
                    DispatchQueue.main.async {
                        self.presets = existingPresets
                    }
                    
                    // Mark as user-created
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    return
                }
            }
            
            print("📂 No existing presets found, using defaults temporarily")
            DispatchQueue.main.async {
                self.presets = Preset.defaults
                // Don't auto-save defaults - let user decide when to save
                print("⚠️  Using defaults temporarily - user should save manually")
            }
        }
    }
    
    /// Force migrate current old-format presets to new format to prevent overwrites
    func forceMigrateCurrentPresets() {
        print("🔄 Force migrating current presets to prevent overwrites...")
        
        guard let documentsPath = getDocumentsDirectory() else {
            print("❌ Could not get documents directory for migration")
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        // Check if file exists and is in old format
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("📂 No presets file exists, nothing to migrate")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // Try to decode as new format first
            do {
                let _ = try JSONDecoder().decode([Preset].self, from: data)
                print("✅ File is already in new format, no migration needed")
                return
            } catch {
                print("🔄 File is in old format, migrating to new format...")
                
                if let migratedPresets = migrateFromOldFormat(data: data) {
                    // Save the migrated presets in new format
                    print("✅ Migration successful, saving \(migratedPresets.count) presets in new format")
                    savePresetsToFile(migratedPresets)
                    
                    // Update the current presets in memory
                    DispatchQueue.main.async {
                        self.presets = migratedPresets
                    }
                    
                    // Mark that we have user-created presets to prevent future overwrites
                    let defaults = UserDefaults.standard
                    defaults.set(true, forKey: "hasUserCreatedPresets")
                    defaults.set(Date(), forKey: "lastPresetSaveDate")
                    print("✅ Marked migrated presets as user-created to prevent future overwrites")
                    
                    print("✅ Force migration completed successfully")
                } else {
                    print("❌ Migration failed, but preserving existing presets")
                }
            }
        } catch {
            print("❌ Error reading presets file for migration: \(error)")
        }
    }

    /// Check if presets need to be migrated without overwriting
    func checkMigrationNeeded() -> Bool {
        print("🔍 Checking if migration is needed...")
        
        guard let documentsPath = getDocumentsDirectory() else {
            print("❌ Could not get documents directory for migration check")
            return false
        }
        
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        // If no file exists, no migration needed
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("📂 No presets file exists, no migration needed")
            return false
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // Try to decode as new format
            do {
                let _ = try JSONDecoder().decode([Preset].self, from: data)
                print("✅ File is already in new format, no migration needed")
                return false
            } catch {
                print("🔄 File appears to be in old format, migration needed")
                return true
            }
        } catch {
            print("❌ Error reading file for migration check: \(error)")
            return false
        }
    }
    
    /// Check if current presets are different from defaults (user-modified)
    func arePresetsUserModified() -> Bool {
        return presets != Preset.defaults
    }
    
    /// Check if presets need to be saved (are different from what's on disk)
    func doPresetsNeedSaving() -> Bool {
        guard let documentsPath = getDocumentsDirectory() else { return false }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        // If no file exists, presets need saving
        guard fileManager.fileExists(atPath: fileURL.path) else { return true }
        
        do {
            let data = try Data(contentsOf: fileURL)
            if let savedPresets = try? JSONDecoder().decode([Preset].self, from: data) {
                return presets != savedPresets
            }
            return true // If can't decode, assume they need saving
        } catch {
            return true // If can't read, assume they need saving
        }
    }
    

    
    /// Recover presets from UserDefaults backup if file is corrupted
    private func recoverPresetsFromBackup() -> [Preset]? {
        print("🔄 Attempting to recover presets from UserDefaults backup...")
        
        let defaults = UserDefaults.standard
        guard let backupData = defaults.data(forKey: "presets_backup_data") else {
            print("❌ No backup data found in UserDefaults")
            return nil
        }
        
        guard let backupTimestamp = defaults.object(forKey: "presets_backup_timestamp") as? Date else {
            print("❌ No backup timestamp found in UserDefaults")
            return nil
        }
        
        print("📅 Backup timestamp: \(backupTimestamp)")
        
        do {
            let recoveredPresets = try JSONDecoder().decode([Preset].self, from: backupData)
            print("✅ Successfully recovered \(recoveredPresets.count) presets from backup")
            
            // Check if backup is recent (within last 24 hours)
            let timeSinceBackup = Date().timeIntervalSince(backupTimestamp)
            let oneDay: TimeInterval = 24 * 60 * 60
            
            if timeSinceBackup < oneDay {
                print("✅ Backup is recent (\(Int(timeSinceBackup/3600)) hours old)")
                return recoveredPresets
            } else {
                print("⚠️  Backup is old (\(Int(timeSinceBackup/3600)) hours old) - may be outdated")
                // Still return it, but warn the user
                return recoveredPresets
            }
        } catch {
            print("❌ Failed to decode backup data: \(error)")
            return nil
        }
    }
    
    /// Start periodic save mechanism for ultimate protection
    private func startPeriodicSave() {
        print("🔄 BULLETPROOF PERIODIC: Starting periodic save mechanism...")
        
        // Save every 5 seconds if presets need saving
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.doPresetsNeedSaving() && self.presets != Preset.defaults {
                print("💾 BULLETPROOF PERIODIC: Periodic save triggered...")
                self.savePresets()
            }
        }
        
        // Also save every 30 seconds regardless (for ultimate protection)
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.presets != Preset.defaults {
                print("💾 BULLETPROOF PERIODIC: Ultimate protection save triggered...")
                self.savePresets()
            }
        }
        
        print("✅ BULLETPROOF PERIODIC: Periodic save mechanism started")
    }
    
    /// Get diagnostic information about the current presets state
    func getDiagnosticInfo() -> String {
        var info = "=== Workspace-Buddy Diagnostic Information ===\n\n"
        
        // Check documents directory
        guard let documentsPath = getDocumentsDirectory() else {
            info += "❌ Could not get documents directory\n"
            return info
        }
        
        info += "📁 Documents Directory: \(documentsPath)\n"
        
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        info += "📄 Presets File Path: \(fileURL)\n"
        
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
                let creationDate = attributes[FileAttributeKey.creationDate] as? Date ?? Date()
                let modificationDate = attributes[FileAttributeKey.modificationDate] as? Date ?? Date()
                
                info += "✅ File exists\n"
                info += "📊 File size: \(fileSize) bytes\n"
                info += "📅 Created: \(creationDate)\n"
                info += "📅 Modified: \(modificationDate)\n"
                
                // Try to read the file
                let data = try Data(contentsOf: fileURL)
                info += "📖 File can be read, size: \(data.count) bytes\n"
                
                // Try to decode
                do {
                    let presets = try JSONDecoder().decode([Preset].self, from: data)
                    info += "✅ File decodes successfully as new format\n"
                    info += "📱 Number of presets: \(presets.count)\n"
                    for preset in presets {
                        info += "  - \(preset.name): \(preset.apps.count) apps\n"
                    }
                } catch {
                    info += "❌ File does not decode as new format: \(error)\n"
                    
                    // Try old format
                    if let migratedPresets = migrateFromOldFormat(data: data) {
                        info += "✅ File can be migrated from old format\n"
                        info += "📱 Number of migrated presets: \(migratedPresets.count)\n"
                    } else {
                        info += "❌ File cannot be migrated from old format\n"
                    }
                }
            } catch {
                info += "❌ Error reading file: \(error)\n"
            }
        } else {
            info += "❌ File does not exist\n"
        }
        
        info += "\n📱 Current Presets in Memory: \(presets.count)\n"
        for preset in presets {
            info += "  - \(preset.name): \(preset.apps.count) apps\n"
        }
        
        info += "\n🎯 Current Active Preset: \(currentPreset?.name ?? "None")\n"
        
        return info
    }
    
    /// Check if we have an existing presets file
    private func hasExistingPresetsFile() -> Bool {
        guard let documentsPath = getDocumentsDirectory() else { return false }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Force load existing presets even if they're in old format
    private func forceLoadExistingPresets() -> [Preset]? {
        print("🔄 Force loading existing presets...")
        
        guard let documentsPath = getDocumentsDirectory() else { return nil }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // Try new format first
            if let presets = try? JSONDecoder().decode([Preset].self, from: data) {
                print("✅ Successfully loaded existing presets in new format")
                return presets
            }
            
            // Try migration
            if let migratedPresets = migrateFromOldFormat(data: data) {
                print("✅ Successfully migrated and loaded existing presets")
                return migratedPresets
            }
            
            // Try preservation
            if let preservedPresets = preserveExistingPresetsFromOldFormat(data: data) {
                print("✅ Successfully preserved and loaded existing presets")
                return preservedPresets
            }
            
            print("❌ All loading methods failed")
            return nil
            
        } catch {
            print("❌ Error force loading existing presets: \(error)")
            return nil
        }
    }
}
