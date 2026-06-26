// swift-tools-version: 6.0
// Build KapselKit and KapselApp using Swift 6.0

import PackageDescription

let package = Package(
    name: "Kapsel",
    defaultLocalization: "en", // Enable localization support for resources
    platforms: [
        .macOS(.v14) // Required for apple/container virtualization support
    ],
    products: [
        .library(name: "KapselKit", targets: ["KapselKit"]),
    ],
    dependencies: [
        // Add third-party dependencies here if needed
    ],
    targets: [
        // Core business logic target
        .target(
            name: "KapselKit",
            dependencies: [],
            path: "Sources/KapselKit"
        ),
        // SwiftUI GUI Application target
        .executableTarget(
            name: "KapselApp",
            dependencies: ["KapselKit"],
            path: "Sources/KapselApp"
        ),
        // Unit tests target
        .testTarget(
            name: "KapselKitTests",
            dependencies: ["KapselKit"],
            path: "Tests/KapselKitTests"
        )
    ]
)
