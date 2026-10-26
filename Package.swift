// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sift", targets: ["Sift"]),
        .library(name: "SiftCore", targets: ["SiftCore"]),
    ],
    targets: [
        // Backend: scanning, sizing, safety, deletion. No SwiftUI.
        .target(name: "SiftCore"),
        // Screen state (AppState). No SwiftUI, so it can be unit-tested.
        .target(name: "SiftAppModel", dependencies: ["SiftCore"]),
        // Frontend: SwiftUI app. Talks to SiftCore only through `Engine`.
        .executableTarget(name: "Sift", dependencies: ["SiftCore", "SiftAppModel"]),
        // Read-only debugging tool: prints what a scan finds. Never cleans.
        .executableTarget(name: "sift-cli", dependencies: ["SiftCore"]),
        .testTarget(name: "SiftCoreTests", dependencies: ["SiftCore", "SiftAppModel"]),
    ]
)
