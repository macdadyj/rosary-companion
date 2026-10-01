// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Rosary",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // xtool bundles exactly one library product as the iOS app (see xtool.yml).
        .library(
            name: "Rosary",
            targets: ["Rosary"]
        ),
    ],
    targets: [
        // Pure Swift: prayer model, schedule, anchor matching, session state machine,
        // family rotation, habits, persistence. Builds and tests on Linux.
        .target(
            name: "RosaryCore",
            resources: [.process("Resources")]
        ),
        // SwiftUI + Speech + AVFoundation. Every file is wrapped in `#if os(iOS)` so that
        // `swift build` / `swift test` on Linux compile it to an empty module.
        .target(
            name: "Rosary",
            dependencies: ["RosaryCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RosaryCoreTests",
            dependencies: ["RosaryCore"]
        ),
    ]
)
