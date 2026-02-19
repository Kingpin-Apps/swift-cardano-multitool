// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-cardano-multitool",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // The executable product name is what users will type in the terminal
        .executable(name: "scm", targets: ["SwiftCardanoMultitool"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "0.2.30"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-chain.git", from: "0.2.5"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txbuilder.git", from: "0.2.4"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-utils.git", from: "0.2.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-handles-api.git", from: "0.1.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-gnupg.git", from: "0.1.1"),
        .package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.51.0")),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.2.0"),
        // Provides Crypto compatible APIs on Linux
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.15.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "SwiftCardanoMultitool",
            dependencies: [
                "Noora",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "SwiftCardanoUtils", package: "swift-cardano-utils"),
                .product(name: "GnuPG", package: "swift-gnupg"),
                .product(name: "SwiftCardanoChain", package: "swift-cardano-chain"),
                .product(name: "SwiftCardanoCore", package: "swift-cardano-core"),
                .product(name: "SwiftCardanoTxBuilder", package: "swift-cardano-txbuilder"),
                .product(name: "SwiftHandlesAPI", package: "swift-handles-api"),
                .product(name: "Version", package: "version"),
                // Only link Crypto on Linux; on Apple platforms CryptoKit is available.
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
