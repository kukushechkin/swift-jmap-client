// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-jmap-client",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
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
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "JMAPClient",
            dependencies: [
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ],
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
