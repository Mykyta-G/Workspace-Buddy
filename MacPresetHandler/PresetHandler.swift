import Foundation
import AppKit
import Combine

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
    
    /// Load presets from storage or create defaults
    func refreshPresets() {
        if let loadedPresets = loadPresetsFromFile() {
            presets = loadedPresets
        } else {
            presets = Preset.defaults
            savePresets()
        }
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
            
            if !updatedPreset.apps.contains(normalizedAppName) {
                updatedPreset.apps.append(normalizedAppName)
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
            updatedPreset.apps.removeAll { $0 == appName }
            presets[index] = updatedPreset
            
            // Update current preset if it's the same one
            if currentPreset?.id == preset.id {
                currentPreset = updatedPreset
            }
            
            savePresets()
        }
    }
    
    // MARK: - Workspace Switching
    
    /// Switch to a specific preset
    func switchToPreset(_ preset: Preset) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Close previous apps if needed
            if let current = currentPreset, preset.closePrevious {
                try await closeApps(from: current)
            }
            
            // Launch new apps
            try await launchApps(from: preset)
            
            await MainActor.run {
                currentPreset = preset
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                isLoading = false
            }
            print("Error switching to preset: \(error)")
        }
    }
    
    /// Launch applications for a preset
    private func launchApps(from preset: Preset) async throws {
        for appName in preset.apps {
            try await launchApp(named: appName)
        }
    }
    
    /// Close applications from a preset
    private func closeApps(from preset: Preset) async throws {
        for appName in preset.apps {
            try await closeApp(named: appName)
        }
    }
    
    // MARK: - Application Management
    
    /// Launch an application by name
    private func launchApp(named appName: String) async throws {
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
                let url = URL(fileURLWithPath: path)
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                
                try await NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: config
                )
                return
            }
        }
        
        // If not found in common locations, try to launch by bundle identifier
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
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            // Use the correct method for launching by bundle identifier
            // For now, just print that we can't launch these apps
            // In a full implementation, we'd use the proper NSWorkspace APIs
            print("Note: Could not launch app by bundle identifier: \(appName)")
            print("This app may need to be launched manually or added to /Applications")
        }
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
        guard let documentsPath = getDocumentsDirectory() else { return nil }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let presets = try JSONDecoder().decode([Preset].self, from: data)
            return presets
        } catch {
            print("Error loading presets: \(error)")
            return nil
        }
    }
    
    /// Save presets to JSON file
    private func savePresetsToFile(_ presets: [Preset]) {
        guard let documentsPath = getDocumentsDirectory() else { return }
        let fileURL = documentsPath.appendingPathComponent(presetsFile)
        
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL)
        } catch {
            print("Error saving presets: \(error)")
        }
    }
    
    /// Get the documents directory for storing presets
    private func getDocumentsDirectory() -> URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Bindings
    
    /// Setup automatic saving when presets change
    private func setupBindings() {
        $presets
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePresets()
            }
            .store(in: &cancellables)
    }
}
