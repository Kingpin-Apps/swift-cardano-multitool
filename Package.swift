// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCardanoMultitool",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // The executable product name is what users will type in the terminal
        .executable(name: "scm", targets: ["SwiftCardanoMultitoolApp"]),
        .library(name: "SwiftCardanoMultitool", targets: ["SwiftCardanoMultitool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
        .package(
            url: "https://github.com/apple/swift-configuration",
            from: "1.2.0",
            traits: [.defaults, "YAML"]
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.6.3"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.4.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "0.4.6"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-chain.git", from: "0.6.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-cips.git", from: "0.3.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-token-registry.git", from: "0.2.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txbuilder.git", from: "1.0.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txvalidator.git", from: "0.2.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-signer.git", from: "0.1.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-utils.git", from: "0.5.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-koios.git", from: "0.2.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-wallet.git", from: "1.1.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-handles-api.git", from: "0.1.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-gnupg.git", from: "0.1.5"),
        .package(url: "https://github.com/Kingpin-Apps/swift-nacl.git", .upToNextMinor(from: "1.0.2")),
        .package(url: "https://github.com/mattt/swift-configuration-toml.git", from: "2.0.0"),
        .package(url: "https://github.com/mattt/swift-toml.git", from: "2.0.0"),
        .package(url: "https://github.com/mgacy/swift-version-file-plugin", from: "0.2.1"),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.2.0"),
        .package(url: "https://github.com/thoven87/icalendar-kit.git", from: "2.1.0"),
        .package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.56.0")),
    ],
    targets: [
        .target(
            name: "SwiftCardanoMultitool",
            dependencies: [
                "Noora",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Configuration", package: "swift-configuration"),
                .product(name: "ConfigurationTOML", package: "swift-configuration-toml"),
                .product(name: "TOML", package: "swift-toml"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "SwiftCardanoUtils", package: "swift-cardano-utils"),
                .product(name: "GnuPG", package: "swift-gnupg"),
                .product(name: "SwiftCardanoChain", package: "swift-cardano-chain"),
                .product(name: "SwiftCardanoCore", package: "swift-cardano-core"),
                .product(name: "SwiftCardanoCIPs", package: "swift-cardano-cips"),
                .product(name: "SwiftCardanoSigner", package: "swift-cardano-signer"),
                .product(name: "SwiftCardanoTokenRegistry", package: "swift-cardano-token-registry"),
                .product(name: "SwiftCardanoTxBuilder", package: "swift-cardano-txbuilder"),
                .product(name: "SwiftCardanoTxValidator", package: "swift-cardano-txvalidator"),
                .product(name: "SwiftCardanoWallet", package: "swift-cardano-wallet"),
                .product(name: "SwiftKoios", package: "swift-koios"),
                .product(name: "SwiftHandlesAPI", package: "swift-handles-api"),
                .product(name: "SwiftNaCl", package: "swift-nacl"),
                .product(name: "Version", package: "version"),
                .product(name: "ICalendar", package: "icalendar-kit"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .product(name: "_CryptoExtras", package: "swift-crypto", condition: .when(platforms: [.linux])),
            ]
        ),
        // Thin executable that just calls into the library.
        .executableTarget(
            name: "SwiftCardanoMultitoolApp",
            dependencies: ["SwiftCardanoMultitool"]
        ),
        .testTarget(
            name: "SwiftCardanoMultitoolTests",
            dependencies: ["SwiftCardanoMultitool"],
            resources: [
                .copy("Support/Fixtures"),
            ]
        ),
    ]
)
