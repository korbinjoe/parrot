// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenBob",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Core abstraction layer — buildable & testable without Xcode GUI toolchain.
        .library(name: "OpenBobCore", targets: ["OpenBobCore"]),
        // Built-in translation engines.
        .library(name: "OpenBobEngines", targets: ["OpenBobEngines"]),
        // Plugin runtime (JavaScriptCore) for community LLM/translation plugins.
        .library(name: "OpenBobPlugins", targets: ["OpenBobPlugins"]),
        // App executable (SwiftUI/AppKit) — requires full Xcode to build the .app bundle.
        .executable(name: "OpenBob", targets: ["OpenBobApp"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OpenBobCore",
            path: "Sources/OpenBobCore"
        ),
        .target(
            name: "OpenBobEngines",
            dependencies: ["OpenBobCore"],
            path: "Sources/OpenBobEngines"
        ),
        .target(
            name: "OpenBobPlugins",
            dependencies: ["OpenBobCore"],
            path: "Sources/OpenBobPlugins"
        ),
        .executableTarget(
            name: "OpenBobApp",
            dependencies: ["OpenBobCore", "OpenBobEngines", "OpenBobPlugins"],
            path: "Sources/OpenBobApp"
        ),
        .testTarget(
            name: "OpenBobCoreTests",
            dependencies: ["OpenBobCore", "OpenBobEngines", "OpenBobPlugins"],
            path: "Tests/OpenBobCoreTests"
        )
    ]
)
