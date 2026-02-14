import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension BuildMainCommand {
    struct StakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build a Cardano stake address from the address key files."
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. Address stake verification key file must exist in the current working directory and are in the format 'address_name.stake.vkey'.")
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
                        prompt: "Enter the name of the address (without .payment.addr):",
                        description: "The corresponding key files must exist in the current working directory.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    
                    stakeVkey = FilePath(
                        noora.singleChoicePrompt(
                            title: "Stake Verification Key",
                            question: "Select the stake verification key file:",
                            options: files,
                            description: "Select the stake verification key file from the files in the current working directory.",
                            filterMode: .enabled
                        )
                    )
            }
            
            tool = try await getToolToUse()
        }
        
        mutating func run() async throws {
            if addressName == nil && stakeVkey == nil {
                try await self.wizard()
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let stakeAddress: FilePath
            if addressName != nil {
                if stakeVkey == nil {
                    // Check if stakeVkey file exists
                    stakeVkey = cwd.appending("\(addressName!).stake.vkey")
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
                                "Make sure the \(stakeVkey!) uses the naming convention 'address_name.stake.vkey'.",
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
            
            stakeAddress = cwd.appending("\(addressName!).stake.addr")
            
            print(noora.format(
                "Building stake address: \(.primary(addressName!))")
            )
            
            let config = try await MultitoolConfig.load()
            
            let address: Address
            switch tool {

                case .cardanoCLI:
                    print(noora.format(
                        "Using \(.primary("cardano-cli")) to build the address")
                    )
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    _ = try await cli
                        .address
                        .build(
                            arguments: [
                                "--stake-verification-key-file", stakeVkey!.string,
                                "--out-file", stakeAddress.string
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
                    
                    address = try Address(
                        paymentPart: nil,
                        stakingPart: .verificationKeyHash(try stakeVerificationKey.hash()),
                        network: config.cardano.network.networkId
                    )

            }
            
            print(
                noora.format("Stake Address File: \(.primary(stakeAddress.string))"),
                terminator: "\n\n"
            )
            
            try address.save(to: stakeAddress.string)
            
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
