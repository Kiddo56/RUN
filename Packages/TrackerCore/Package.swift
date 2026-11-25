// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrackerCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TrackerCore",
            targets: ["TrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "TrackerCore",
            path: "Sources/TrackerCore"
        ),
        .testTarget(
            name: "TrackerCoreTests",
            dependencies: ["TrackerCore"],
            path: "Tests/TrackerCoreTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
