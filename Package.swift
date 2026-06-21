// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Parrot",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        // Core abstraction layer — buildable & testable without Xcode GUI toolchain.
        .library(name: "ParrotCore", targets: ["ParrotCore"]),
        // Social reading/writing session layer used by iOS and future shared surfaces.
        .library(name: "ParrotSocial", targets: ["ParrotSocial"]),
        // Platform-neutral protocols and JSON stores.
        .library(name: "ParrotPlatform", targets: ["ParrotPlatform"]),
        // iOS platform adapters for Keychain, App Groups, clipboard, and image/OCR handoff.
        .library(name: "ParrotPlatformiOS", targets: ["ParrotPlatformiOS"]),
        // Built-in translation engines.
        .library(name: "ParrotEngines", targets: ["ParrotEngines"]),
        // Plugin runtime (JavaScriptCore) for community LLM/translation plugins.
        .library(name: "ParrotPlugins", targets: ["ParrotPlugins"]),
        // App executable (SwiftUI/AppKit) — requires full Xcode to build the .app bundle.
        .executable(name: "Parrot", targets: ["ParrotApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ParrotCore",
            path: "Sources/ParrotCore"
        ),
        .target(
            name: "ParrotSocial",
            dependencies: ["ParrotCore"],
            path: "Sources/ParrotSocial"
        ),
        .target(
            name: "ParrotPlatform",
            dependencies: ["ParrotCore", "ParrotSocial"],
            path: "Sources/ParrotPlatform"
        ),
        .target(
            name: "ParrotPlatformiOS",
            dependencies: ["ParrotCore", "ParrotSocial", "ParrotPlatform"],
            path: "Sources/ParrotPlatformiOS"
        ),
        .target(
            name: "ParrotEngines",
            dependencies: ["ParrotCore"],
            path: "Sources/ParrotEngines"
        ),
        .target(
            name: "ParrotPlugins",
            dependencies: ["ParrotCore"],
            path: "Sources/ParrotPlugins"
        ),
        .executableTarget(
            name: "ParrotApp",
            dependencies: ["ParrotCore", "ParrotEngines", "ParrotPlugins"],
            path: "Sources/ParrotApp"
        ),
        .testTarget(
            name: "ParrotCoreTests",
            dependencies: ["ParrotCore", "ParrotEngines", "ParrotPlugins"],
            path: "Tests/ParrotCoreTests"
        ),
        .testTarget(
            name: "ParrotSocialTests",
            dependencies: ["ParrotCore", "ParrotSocial", "ParrotPlatform", "ParrotPlatformiOS"],
            path: "Tests/ParrotSocialTests"
        )
    ]
)
