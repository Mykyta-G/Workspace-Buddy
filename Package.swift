// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacPresetHandler",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacPresetHandler",
            targets: ["MacPresetHandler"]
        ),
    ],
    dependencies: [
        // No external dependencies needed
    ],
    targets: [
        .executableTarget(
            name: "MacPresetHandler",
            dependencies: [],
            path: "MacPresetHandler",
            sources: ["Preset.swift", "PresetHandler.swift", "ContentView.swift", "MacPresetHandlerApp.swift"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ]
)
