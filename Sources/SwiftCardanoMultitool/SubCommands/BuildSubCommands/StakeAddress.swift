import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension BuildMainCommand {
    struct StakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build a Cardano stake address from the address key files.",
            usage: """
            scm build stake-address ---address-name test
            """,
            discussion: """
            Build a Cardano stake address from the address verification key 
            file. You can provide either the address name (preferred) or the 
            paths to the stake verification key files. If using the address 
            name, the corresponding key files must exist in the current working 
            directory in the format 'name.stake.vkey'.
            """,
            aliases: ["stake"]
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. Address stake verification key file must exist in the current working directory and are in the format 'name.stake.vkey'.")
        var addressName: String? = nil
        
        @Option(name: .shortAndLong, help: "The path to the staking verification key file.")
        var stakeVkey: FilePath? = nil
        
        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to build the payment addresses.")
        var tool: Tool? = nil
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let getAddressBy: GetAddressBy = try await getAddressBy()
            
            switch getAddressBy {
                case .name:
                    addressName = noora.textPrompt(
                        title: "Address Name",
                        prompt: "Enter the name of the address (without .stake.addr):",
                        description: "The corresponding key files must exist in the current working directory.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    stakeVkey = try filePathPrompt(
                        title: "Stake Verification Key",
                        question: "Select the stake verification key file:",
                        fileMatches: { $0.hasSuffix(".vkey") || $0.hasSuffix(".json") }
                    )
            }
            
            if tool == nil { tool = try await getToolToUse() }
        }
        
        mutating func run() async throws {
            if addressName == nil && stakeVkey == nil {
                try await self.wizard()
            }
            
            
            let stakeAddress: FilePath
            if addressName != nil {
                if stakeVkey == nil {
                    // Check if stakeVkey file exists
                    stakeVkey = FileUtils.absolutePath("\(addressName!).stake.vkey")
                    if !FileManager.default.fileExists(atPath: stakeVkey!.string) {
                        noora.error(
                            .alert(
                                "Stake verification key file not found: \(stakeVkey!.string)",
                                takeaways: [
                                    "Make sure the file exists in the current working directory.",
                                    "Or provide the path to the stake verification key file using --stake-vkey."
                                ]
                            )
                        )
                        throw ExitCode.failure
                    }
                }
            } else if stakeVkey != nil {
                if let filename = stakeVkey!.lastComponent?.string {
                    // Remove ".stake.vkey"
                    addressName = filename.replacingOccurrences(of: ".stake.vkey", with: "")
                } else {
                    noora.error(
                        .alert(
                            "Could not determine address name from stake verification key file path.",
                            takeaways: [
                                "Make sure the \(stakeVkey!) uses the naming convention 'name.stake.vkey'.",
                                "Or provide the address name using the --address-name option."
                            ]
                        )
                    )
                    throw ExitCode.failure
                }
            } else {
                noora.error(
                    .alert(
                        "Insufficient parameters provided.",
                        takeaways: [
                            "Either provide the address name using --address-name (preferred), or the  stake verification key file paths using --stake-vkey.",
                            "If using --address-name, make sure the corresponding key files exist in the current working directory."
                        ]
                    )
                )
                throw ExitCode.failure
            }
            
            stakeAddress = FileUtils.absolutePath("\(addressName!).stake.addr")
            
            print(noora.format(
                "Building stake address: \(.primary(addressName!))")
            )
            
            let config = try await MultitoolConfig.load()
            
            if tool == nil {
                tool = try await getToolToUse()
            }

            try await printToolInfo(config: config, tool: tool!)
            
            let address: Address
            switch tool {

                case .cardanoCLI:
                    print(noora.format(
                        "Using \(.primary("cardano-cli")) to build the address")
                    )
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    // Use the stake-address builder, not the payment-address builder
                    // (`address build` requires payment key/script inputs and errors
                    // "Missing --payment-script-file" when given only a stake vkey).
                    _ = try await cli
                        .stakeAddress
                        .build(
                            arguments: [
                                // Absolutize — cardano-cli runs in its own working dir.
                                "--stake-verification-key-file", FileUtils.absolutePath(stakeVkey!).string,
                                "--out-file", FileUtils.absolutePath(stakeAddress).string
                            ]
                        )
                    address = try Address.load(from: stakeAddress.string)

                default:
                    print(noora.format(
                        "Using \(.primary("SwiftCardano")) to build the address")
                    )
                    
                    let stakeVerificationKey = try StakeVerificationKey.load(
                        from: stakeVkey!.string
                    )
                    
                    let cardanoConfig = try getCardanoConfig(config: config)
                    
                    address = try Address(
                        paymentPart: nil,
                        stakingPart: .verificationKeyHash(try stakeVerificationKey.hash()),
                        network: cardanoConfig.network.networkId
                    )

                    // cardano-cli already wrote the address file via its --out-file;
                    // only the in-memory (SwiftCardano) path needs to persist it.
                    try address.save(to: stakeAddress.string)
            }

            print(
                noora.format("Stake Address File: \(.primary(stakeAddress.string))"),
                terminator: "\n\n"
            )

            print(
                noora.format("Stake Address: \(.primary(try address.toBech32()))"),
                terminator: "\n\n"
            )
            
            noora.success(
                .alert("Stake address built successfully.")
            )
        }
    }
}
