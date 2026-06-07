// swift-tools-version: 6.0
import PackageDescription

// Standalone executable package for the Unified Multimodal AI Framework.
// This is intentionally separate from the macOS app's Xcode project — the
// framework is a self-contained demonstration that runs from the command line.
//
//   Build:  swift build
//   Run:    swift run AIFrameworkDemo
//
let package = Package(
    name: "AIFramework",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "AIFrameworkDemo",
            path: ".",
            exclude: [
                "Package.swift",
                "README.md",
                "INTEGRATION_GUIDE.md"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
