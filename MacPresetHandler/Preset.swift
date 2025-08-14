import Foundation

/// Represents a workspace preset with associated applications and settings
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var description: String
    var apps: [String]
    var closePrevious: Bool
    var icon: String? // Optional icon identifier
    
    init(name: String, description: String, apps: [String], closePrevious: Bool = true, icon: String? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.apps = apps
        self.closePrevious = closePrevious
        self.icon = icon
    }
    
    /// Default presets for common use cases
    static let defaults: [Preset] = [
        Preset(
            name: "Work",
            description: "Productivity and development workspace",
            apps: ["Safari", "Xcode", "Terminal", "Slack", "Notes"],
            closePrevious: true,
            icon: "briefcase"
        ),
        Preset(
            name: "School",
            description: "Educational and learning workspace",
            apps: ["Safari", "Pages", "Keynote", "Numbers", "Mail"],
            closePrevious: true,
            icon: "book"
        ),
        Preset(
            name: "Gaming",
            description: "Gaming and entertainment workspace",
            apps: ["Steam", "Discord", "Spotify", "Safari"],
            closePrevious: false,
            icon: "gamecontroller"
        ),
        Preset(
            name: "Relax",
            description: "Relaxation and social media workspace",
            apps: ["Safari", "Messages", "Photos", "Music", "TV"],
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
        apps.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    /// Get a display-friendly app list
    var appListText: String {
        apps.joined(separator: ", ")
    }
    
    /// Get the number of apps in this preset
    var appCount: Int {
        apps.count
    }
}
