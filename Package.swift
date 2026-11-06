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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.5.0"),
        .package(
            url: "https://github.com/apple/swift-configuration",
            from: "1.2.2",
            traits: [.defaults, "YAML"]
        ),
        .package(url: "https://github.com/apple/swift-crypto.git", "4.5.2"..<"6.0.0"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.8.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-core.git", from: "0.10.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cbor-codable.git", .upToNextMinor(from: "0.5.0")),
        .package(
            url: "https://github.com/Kingpin-Apps/swift-cardano-chain.git",
            from: "0.16.2",
            // cardano-cli & node-socket backends are trait-gated as of 0.7.0
            traits: [.defaults, "CLIBackends"]
        ),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-cips.git", from: "0.4.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-explorers.git", from: "0.1.4"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-network.git", from: "1.3.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-token-registry.git", from: "0.2.3"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txbuilder.git", from: "2.0.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-txvalidator.git", from: "0.6.2"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-signer.git", from: "0.1.4"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-utils.git", from: "0.5.11"),
        .package(url: "https://github.com/Kingpin-Apps/swift-koios.git", from: "0.3.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-utxorpc.git", from: "0.1.0"),
        // Test-only: a loopback gRPC server standing in for a UTxO RPC server.
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.4"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.12.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cardano-wallet.git", from: "2.0.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-handles-api.git", from: "0.1.1"),
        .package(url: "https://github.com/Kingpin-Apps/swift-gnupg.git", from: "0.1.6"),
        .package(url: "https://github.com/Kingpin-Apps/swift-nacl.git", .upToNextMinor(from: "1.1.0")),
        .package(url: "https://github.com/mattt/swift-configuration-toml.git", from: "2.0.0"),
        .package(url: "https://github.com/mattt/swift-toml.git", from: "2.0.0"),
        .package(url: "https://github.com/mgacy/swift-version-file-plugin", from: "0.3.0"),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.2.1"),
        .package(url: "https://github.com/thoven87/icalendar-kit.git", from: "2.1.3"),
        .package(url: "https://github.com/tuist/Noora", .upToNextMajor(from: "0.57.3")),
        .package(url: "https://github.com/attaswift/BigInt.git", "5.7.0"..<"7.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftCardanoMultitool",
            dependencies: [
                "Noora",
                "BigInt",
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
                .product(name: "CBORCodable", package: "swift-cbor-codable"),
                .product(name: "SwiftCardanoCIPs", package: "swift-cardano-cips"),
                .product(name: "SwiftCardanoExplorers", package: "swift-cardano-explorers"),
                .product(name: "SwiftCardanoNetwork", package: "swift-cardano-network"),
                .product(name: "SwiftCardanoSigner", package: "swift-cardano-signer"),
                .product(name: "SwiftCardanoTokenRegistry", package: "swift-cardano-token-registry"),
                .product(name: "SwiftCardanoTxBuilder", package: "swift-cardano-txbuilder"),
                .product(name: "SwiftCardanoTxValidator", package: "swift-cardano-txvalidator"),
                .product(name: "SwiftCardanoWallet", package: "swift-cardano-wallet"),
                .product(name: "SwiftKoios", package: "swift-koios"),
                .product(name: "UTxORPCClient", package: "swift-utxorpc"),
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
            dependencies: [
                "SwiftCardanoMultitool",
                .product(name: "UTxORPC", package: "swift-utxorpc"),
                .product(name: "UTxORPCClient", package: "swift-utxorpc"),
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
            ],
            resources: [
                .copy("Support/Fixtures"),
            ]
        ),
    ]
)
