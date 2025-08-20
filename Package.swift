// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Workspace-Buddy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Workspace-Buddy",
            targets: ["Workspace-Buddy"]
        ),
    ],
    dependencies: [
        // No external dependencies needed
    ],
    targets: [
        .executableTarget(
            name: "Workspace-Buddy",
            dependencies: [],
            path: "Workspace-Buddy-Source",
            sources: ["Preset.swift", "PresetHandler.swift", "ContentView.swift", "Workspace-BuddyApp.swift"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ]
)
