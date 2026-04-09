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
        .executable(name: "scm", targets: ["SwiftCardanoMultitool"]),
        .library(name: "SwiftCardanoMultitoolLib", targets: ["SwiftCardanoMultitoolLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/apple/swift-configuration", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "0.3.8"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-chain.git", from: "0.2.16"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txbuilder.git", from: "0.2.6"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txvalidator.git", from: "0.1.8"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-utils.git", from: "0.3.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-handles-api.git", from: "0.1.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-gnupg.git", from: "0.1.1"),
        .package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.56.0")),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.2.0"),
        .package(url: "https://github.com/thoven87/icalendar-kit.git", from: "2.1.0"),
        // Provides Crypto compatible APIs on Linux
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.15.1"),
    ],
    targets: [
        // Library target containing all application logic — importable by both the executable and test target.
        .target(
            name: "SwiftCardanoMultitoolLib",
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
                .product(name: "SwiftCardanoTxValidator", package: "swift-cardano-txvalidator"),
                .product(name: "SwiftHandlesAPI", package: "swift-handles-api"),
                .product(name: "Version", package: "version"),
                .product(name: "ICalendar", package: "icalendar-kit"),
                // Only link Crypto on Linux; on Apple platforms CryptoKit is available.
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ],
            path: "Sources/SwiftCardanoMultitool",
            resources: [
                .copy("Resources")
            ]
        ),
        // Thin executable that just calls into the library.
        .executableTarget(
            name: "SwiftCardanoMultitool",
            dependencies: ["SwiftCardanoMultitoolLib"],
            path: "Sources/SwiftCardanoMultitoolApp"
        ),
        .testTarget(
            name: "SwiftCardanoMultitoolTests",
            dependencies: ["SwiftCardanoMultitoolLib"]
        ),
    ]
)
