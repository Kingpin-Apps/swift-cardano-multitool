// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cardano-spo-tools",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.1.1")),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.3"),
        .package(url: "https://github.com/Kingpin-Apps/cardano-cli-tools.git", from: "0.1.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "0.1.34"),
        .package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.15.0")),
        .package(url: "https://github.com/wrkstrm/SwiftFigletKit.git", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "cardano-spo-tools",
            dependencies: [
                "Noora",
                "SwiftFigletKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "CardanoCLITools", package: "cardano-cli-tools"),
                .product(name: "SwiftCardanoCore", package: "swift-cardano-core"),
            ]
        ),
    ]
)
