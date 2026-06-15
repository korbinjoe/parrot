// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Parrot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Core abstraction layer — buildable & testable without Xcode GUI toolchain.
        .library(name: "ParrotCore", targets: ["ParrotCore"]),
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
        )
    ]
)
