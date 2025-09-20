// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImageToPDFCore",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Library that exposes all core modules for the iOS app.
        .library(name: "ImageToPDFCore", targets: ["ImageToPDFCore"])
    ],
    targets: [
        // Use the existing folder layout under ios/Core as the target's sources.
        .target(
            name: "ImageToPDFCore",
            path: "Core"
        ),
        .testTarget(
            name: "ImageToPDFCoreTests",
            dependencies: ["ImageToPDFCore"],
            path: "Tests",
            exclude: []
        )
    ]
)

