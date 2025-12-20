// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "homekit-organizer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "homekit-organizer",
            dependencies: [
                "Yams",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/homekit-organizer",
            linkerSettings: [
                .linkedFramework("HomeKit")
            ]
        ),
    ]
)
