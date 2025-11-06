import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension BuildMainCommand {
    
    struct PaymentAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Build a Cardano payment address from the address key files."
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. Address key files must exist in the current working directory and are in the format 'address_name.stake.vkey' and 'address_name.payment.vkey'.")
        var addressName: String? = nil
        
        @Option(name: .shortAndLong, help: "The path to the staking verification key file.")
        var stakeVkey: FilePath? = nil
        
        @Option(name: .shortAndLong, help: "The path to the payment verification key file.")
        var paymentVkey: FilePath? = nil
        
        @Flag(help: "Whether to use the cardano-cli to generate the address.")
        var useCardanoCLI = false
        
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
                    
                    paymentVkey = FilePath(
                        noora.singleChoicePrompt(
                            title: "Payment Verification Key",
                            question: "Select the payment verification key file:",
                            options: files,
                            description: "Select the payment verification key file from the files in the current working directory.",
                            filterMode: .enabled
                        )
                    )
                    
                    let isStakeNeeded = noora.yesOrNoChoicePrompt(
                        title: "Stake Verification Key Confirm",
                        question: "Is Stake Verification Key Needed?",
                        defaultAnswer: true,
                        description: "Build a payment address with a stake and payment verification key or a payment-only address?",
                    )
                    
                    if isStakeNeeded {
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
            }

            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Which Tools",
                question: "Use cardano-cli to build the address?",
                defaultAnswer: false,
                description: "Choose whether to use cardano-cli or SwiftCardano to build the address.",
            )
        }
        
        /// Main execution function
        mutating func run() async throws {
            if addressName == nil && paymentVkey == nil {
                try await self.wizard()
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let paymentAddress: FilePath
            if addressName != nil {
                if stakeVkey == nil {
                    // Check if stakeVkey file exists
                    stakeVkey = cwd.appending("\(addressName!).stake.vkey")
                    if !FileManager.default.fileExists(atPath: stakeVkey!.string) {
                        stakeVkey = nil
                    }
                }
                
                if paymentVkey == nil {
                    paymentVkey = cwd.appending("\(addressName!).payment.vkey")
                    if !FileManager.default.fileExists(atPath: paymentVkey!.string) {
                        noora.error(
                            .alert(
                                "Payment verification key file not found: \(paymentVkey!.string)",
                                takeaways: [
                                    "Make sure the file exists in the current working directory.",
                                    "Or provide the path to the staking verification key file using --payment-vkey."
                                ]
                            )
                        )
                        throw ExitCode.failure
                    }
                }
            } else if paymentVkey != nil {
                if let filename = paymentVkey!.lastComponent?.string {
                    // Remove ".payment.vkey"
                    addressName = filename.replacingOccurrences(of: ".payment.vkey", with: "")
                } else {
                    noora.error(
                        .alert(
                            "Could not determine address name from payment verification key file path.",
                            takeaways: [
                                "Make sure the \(paymentVkey!) uses the naming convention 'address_name.payment.vkey'.",
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
                            "Either provide the address name using --address-name (preferred), or the payment (and stake verification if needed) key file paths using --payment-vkey (and --stake-vkey if needed).",
                            "If using --address-name, make sure the corresponding key files exist in the current working directory."
                        ]
                    )
                )
                throw ExitCode.failure
            }
            
            paymentAddress = cwd.appending("\(addressName!).payment.addr")
            
            print(noora.format(
                "Building payment address: \(.primary(addressName!))")
            )
            
            let config = try await MultitoolConfig.load()
            
            let address: Address
            if useCardanoCLI {
                print(noora.format(
                    "Using \(.primary("cardano-cli")) to build the address")
                )
                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                var arguments: [String]
                if stakeVkey != nil {
                    arguments = [
                        "--payment-verification-key-file", paymentVkey!.string,
                        "--stake-verification-key-file", stakeVkey!.string,
                    ]
                } else {
                    arguments = [
                        "--payment-verification-key-file", paymentVkey!.string
                    ]
                }
                
                arguments.append(contentsOf: ["--out-file", paymentAddress.string])

                _ = try await cli
                    .address
                    .build(
                        arguments: arguments
                    )
                address = try Address.load(from: paymentAddress.string)
            } else {
                print(noora.format(
                    "Using \(.primary("SwiftCardano")) to build the address")
                )
                
                let paymentVerificationKey = try PaymentVerificationKey.load(
                    from: paymentVkey!.string
                )

                let stakingPart: StakingPart?
                if let stakeVkeyPath = stakeVkey {
                    let stakeVerificationKey = try StakeVerificationKey.load(
                        from: stakeVkeyPath.string
                    )
                    stakingPart = .verificationKeyHash(try stakeVerificationKey.hash())
                } else {
                    stakingPart = nil
                }

                address = try Address(
                    paymentPart: .verificationKeyHash(try paymentVerificationKey.hash()),
                    stakingPart: stakingPart,
                    network: config.cardano.network.networkId
                )
            }
            
            print(
                noora.format("Payment Address File: \(.path(try .init(validating: paymentAddress.string)))"),
                terminator: "\n\n"
            )
            
            try address.save(to: paymentAddress.string)
            
            print(
                noora.format("Payment Address: \(.primary(try address.toBech32()))"),
                terminator: "\n\n"
            )
            
            noora.success(
                .alert("Payment address built successfully.")
            )
        }
    }
}
