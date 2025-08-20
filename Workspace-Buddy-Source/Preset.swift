import Foundation
import AppKit

/// Old preset format for backward compatibility
struct OldPresetFormat: Codable {
    var description: String
    var apps: [String]
    var close_previous: Bool
}

/// Represents a website to open in a browser
struct BrowserWebsite: Codable, Equatable, Identifiable {
    var id: UUID
    var url: String
    var title: String
    
    init(url: String, title: String = "") {
        self.id = UUID()
        self.url = url
        self.title = title.isEmpty ? url : title
    }
    
    /// Validate if the URL is properly formatted
    var isValidURL: Bool {
        guard let urlObj = URL(string: self.url) else { return false }
        return urlObj.scheme != nil && (urlObj.scheme == "http" || urlObj.scheme == "https")
    }
    
    /// Get a display-friendly title
    var displayTitle: String {
        if title.isEmpty || title == self.url {
            // Extract domain from URL for display
            if let urlObj = URL(string: self.url), let host = urlObj.host {
                return host.replacingOccurrences(of: "www.", with: "")
            }
            return self.url
        }
        return title
    }
}

/// Represents the position and size of a window
struct WindowPosition: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var screenIndex: Int // Which screen the window is on
    
    init(x: Double, y: Double, width: Double, height: Double, screenIndex: Int = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.screenIndex = screenIndex
    }
    
    /// Create from NSWindow frame
    init(from window: NSWindow) {
        let frame = window.frame
        self.x = frame.origin.x
        self.y = frame.origin.y
        self.width = frame.width
        self.height = frame.height
        
        // Determine which screen the window is on
        if let screen = window.screen {
            self.screenIndex = NSScreen.screens.firstIndex(of: screen) ?? 0
        } else {
            self.screenIndex = 0
        }
    }
}

/// Represents an app with its window positioning information
struct AppWithPosition: Codable, Equatable {
    var name: String
    var windowPositions: [WindowPosition]
    var websites: [BrowserWebsite] // Websites to open for browser apps
    
    init(name: String, windowPositions: [WindowPosition] = [], websites: [BrowserWebsite] = []) {
        self.name = name
        self.windowPositions = windowPositions
        self.websites = websites
    }
    
    /// Check if this app is a browser
    var isBrowser: Bool {
        let browserNames = ["Safari", "Google Chrome", "Firefox", "Microsoft Edge", "Opera", "Brave"]
        return browserNames.contains(name)
    }
    
    /// Add a website to this app
    mutating func addWebsite(_ website: BrowserWebsite) {
        if !websites.contains(where: { $0.url == website.url }) {
            websites.append(website)
        }
    }
    
    /// Remove a website from this app
    mutating func removeWebsite(_ website: BrowserWebsite) {
        websites.removeAll { $0.id == website.id }
    }
}

/// Represents a workspace preset with associated applications and settings
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var apps: [AppWithPosition] // Changed from [String] to [AppWithPosition]
    var closePrevious: Bool
    var icon: String? // Optional icon identifier
    
    init(name: String, description: String, apps: [String], closePrevious: Bool = true, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.apps = apps.map { AppWithPosition(name: $0) }
        self.closePrevious = closePrevious
        self.icon = icon
    }
    
    /// Initialize with positioned apps
    init(name: String, description: String, apps: [AppWithPosition], closePrevious: Bool = true, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.apps = apps
        self.closePrevious = closePrevious
        self.icon = icon
    }
    
    /// Initialize with string apps (for backward compatibility)
    init(name: String, description: String, stringApps: [String], closePrevious: Bool = true, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.apps = stringApps.map { AppWithPosition(name: $0) }
        self.closePrevious = closePrevious
        self.icon = icon
    }
    
    /// Default presets for common use cases
    static let defaults: [Preset] = [
        Preset(
            name: "Work",
            description: "Productivity and development workspace",
            apps: [
                AppWithPosition(name: "Safari"),
                AppWithPosition(name: "Xcode"),
                AppWithPosition(name: "Terminal"),
                AppWithPosition(name: "Slack"),
                AppWithPosition(name: "Notes")
            ],
            closePrevious: true,
            icon: "briefcase"
        ),
        Preset(
            name: "School",
            description: "Educational and learning workspace",
            apps: [
                AppWithPosition(name: "Safari"),
                AppWithPosition(name: "Pages"),
                AppWithPosition(name: "Keynote"),
                AppWithPosition(name: "Numbers"),
                AppWithPosition(name: "Mail")
            ],
            closePrevious: true,
            icon: "book"
        ),
        Preset(
            name: "Gaming",
            description: "Gaming and entertainment workspace",
            apps: [
                AppWithPosition(name: "Steam"),
                AppWithPosition(name: "Discord"),
                AppWithPosition(name: "Spotify"),
                AppWithPosition(name: "Safari")
            ],
            closePrevious: false,
            icon: "gamecontroller"
        ),
        Preset(
            name: "Relax",
            description: "Relaxation and social media workspace",
            apps: [
                AppWithPosition(name: "Safari"),
                AppWithPosition(name: "Messages"),
                AppWithPosition(name: "Photos"),
                AppWithPosition(name: "Music"),
                AppWithPosition(name: "TV")
            ],
            closePrevious: false,
            icon: "heart"
        )
    ]
}

// MARK: - Preset Management Extensions
extension Preset {
    /// Check if the preset has valid app names
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apps.isEmpty &&
        apps.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    /// Get a display-friendly app list
    var appListText: String {
        apps.map { $0.name }.joined(separator: ", ")
    }
    
    /// Get the number of apps in this preset
    var appCount: Int {
        apps.count
    }
    
    /// Get app names as strings (for backward compatibility)
    var appNames: [String] {
        apps.map { $0.name }
    }
    
    /// Update window positions for an app
    mutating func updateWindowPositions(for appName: String, positions: [WindowPosition]) {
        if let index = apps.firstIndex(where: { $0.name == appName }) {
            apps[index].windowPositions = positions
        }
    }
    
    /// Get window positions for an app
    func getWindowPositions(for appName: String) -> [WindowPosition] {
        return apps.first { $0.name == appName }?.windowPositions ?? []
    }
    
    /// Add a website to a browser app in this preset
    mutating func addWebsite(_ website: BrowserWebsite, to appName: String) {
        if let index = apps.firstIndex(where: { $0.name == appName }) {
            apps[index].addWebsite(website)
        }
    }
    
    /// Remove a website from a browser app in this preset
    mutating func removeWebsite(_ website: BrowserWebsite, from appName: String) {
        if let index = apps.firstIndex(where: { $0.name == appName }) {
            apps[index].removeWebsite(website)
        }
    }
    
    /// Get websites for a specific app
    func getWebsites(for appName: String) -> [BrowserWebsite] {
        return apps.first { $0.name == appName }?.websites ?? []
    }
    
    /// Check if an app has websites configured
    func hasWebsites(for appName: String) -> Bool {
        return !getWebsites(for: appName).isEmpty
    }
}
