// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-jmap-client",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "JMAPClient",
            targets: ["JMAPClient"]
        ),
        .executable(
            name: "swift-jmap-client",
            targets: ["swift-jmap-client"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "JMAPClient",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "swift-jmap-client",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "JMAPClient"
            ]
        ),
        .testTarget(
            name: "JMAPClientTests",
            dependencies: ["JMAPClient"]
        ),
    ]
)
