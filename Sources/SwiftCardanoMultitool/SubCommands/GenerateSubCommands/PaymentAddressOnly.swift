import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension GenerateMainCommand {
    
    struct PaymentAddressOnly: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a payment address only."
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. The payment verification key and address will be saved as <name>.payment.vkey and <name>.payment.addr respectively.")
        var addressName: String? = nil
        
        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw, hw_multi.")
        var keyGenMethod: KeyGenMethod? = nil
        
        @Option(name: .shortAndLong, help: "Generates Payment keys using Ledger/Trezor HW-Keys with SubAccount at this number.")
        var subAccount: Int? = nil
        
        @Option(name: .shortAndLong, help: "Generates Payment keys using Ledger/Trezor HW-Keys with Index at this number. To be used together with --sub-account.")
        var index: Int? = nil
        
        @Flag(help: "Whether to use the cardano-cli to generate the address.")
        var useCardanoCLI = false
        
        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .hwMulti:
                    if  subAccount == nil{
                        subAccount = 0
                    }
                    if index == nil {
                        index = 0
                    }
                case .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                    throw ValidationError("Unsupported key generation method. Please choose from: cli, enc, hw, hw_multi.")
                default:
                    break
            }
            
            if subAccount != nil {
                guard subAccount! >= 0 else {
                    throw ValidationError("The sub-account must be a non-negative integer.")
                }
                guard subAccount! <= 2147483647 else {
                    throw ValidationError("The sub-account must be less than or equal to 2147483647.")
                }
            }
            
            if index != nil {
                guard index! >= 0 else {
                    throw ValidationError("The index must be a non-negative integer.")
                }
                guard index! <= 2147483647 else {
                    throw ValidationError("The index must be less than or equal to 2147483647.")
                }
            }
                
        }
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let noora = try await Terminal.shared.noora()
            
            addressName = noora.textPrompt(
                title: "Address Name",
                prompt: "Enter the name of the address (without .payment.addr):",
                description: "The corresponding key files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method to use.",
                options: KeyGenMethod.allCases
                    .filter {
                        [.cli, .enc, .hw, .hwMulti].contains($0)
                    },
                description: "Options are:\n- cli: Use cardano-cli to generate keys.\n- enc: Generate keys and encrypt the signing key with a password.\n- hw: Use a hardware wallet (Ledger/Trezor) to generate keys.\n- hw_multi: Use a hardware wallet (Ledger/Trezor) to generate multisig keys."
            )
            
            switch keyGenMethod {
                case .hw, .hwMulti:
                    subAccount = Int(noora.textPrompt(
                        title: "Sub-Account",
                        prompt: "Enter the sub-account number (default 0):",
                        description: "The sub-account number for the hardware wallet.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Sub-Account name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                    index = Int(noora.textPrompt(
                        title: "Index",
                        prompt: "Enter the index number (default 0):",
                        description: "TThe index number for the hardware wallet.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Index name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                default:
                    break
            }
            
            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Which Tools",
                question: "Use cardano-cli to build the address?",
                defaultAnswer: false,
                description: "Choose whether to use cardano-cli or SwiftCardano to build the address.",
            )
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if addressName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let noora = try await Terminal.shared.noora()
            
            let config = try await MultitoolConfig.load()
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let paymentAddress = cwd.appending("\(addressName!).payment.addr")
            let paymentVKey = cwd.appending("\(addressName!).payment.vkey")
            let paymentSKey = keyGenMethod!.isHardwareType ? cwd.appending("\(addressName!).payment.hwsfile") : cwd.appending(
                "\(addressName!).payment.skey"
            )
            
            try await FileUtils.checkFile(paymentAddress)
            try await FileUtils.checkFile(paymentVKey)
            try await FileUtils.checkFile(paymentSKey)
            
            func lockAndPrintPaymentKeys(extraDescription: String = "") async throws {
                try await FileUtils.fileLock(paymentVKey)
                try await FileUtils.fileLock(paymentSKey)
                
                print(noora.format(
                    "\nPaymentOnly(Enterprise)-Verification-Key\(extraDescription): \(.path(try .init(validating: paymentVKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentVKey)
                
                print(noora.format(
                    "\nPaymentOnly(Enterprise)-Signing-Key\(extraDescription): \(.path(try .init(validating: paymentSKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentSKey)
                
                print("\n")
            }
            
            if keyGenMethod == .cli {
                if useCardanoCLI{
                    print(noora.format(
                        "Using \(.primary("cardano-cli")) to generate address keys")
                    )
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    _ = try await cli.address.keyGen(
                        arguments: [
                            "--verification-key-file", paymentVKey.string,
                            "--signing-key-file", paymentSKey.string
                        ]
                    )
                } else {
                    print(noora.format(
                        "Using \(.primary("SwiftCardano")) to generate address keys")
                    )
                    let paymentKeyPair = try PaymentKeyPair.generate()
                    try paymentKeyPair.verificationKey.save(to: paymentVKey.string)
                    try paymentKeyPair.signingKey.save(to: paymentSKey.string)
                }
                
                try await lockAndPrintPaymentKeys()
                
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope
                
                if useCardanoCLI{
                    print(noora.format(
                        "Using \(.primary("cardano-cli")) to generate address keys")
                    )
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    let skeyJSON = try await cli.address.keyGen(
                        arguments: [
                            "--verification-key-file", paymentVKey.string,
                            "--signing-key-file", "/dev/stdout"
                        ]
                    )
                    
                    skey = try JSONDecoder().decode(
                        TextEnvelope.self,
                        from: skeyJSON.toData
                    )
                } else {
                    print(noora.format(
                        "Using \(.primary("SwiftCardano")) to generate address keys")
                    )
                    let paymentKeyPair = try PaymentKeyPair.generate()
                    try paymentKeyPair.verificationKey.save(to: paymentVKey.string)
                    try paymentKeyPair.signingKey.save(to: paymentSKey.string)
                    
                    skey = try JSONDecoder().decode(
                        TextEnvelope.self,
                        from: paymentKeyPair.signingKey.toJSON()!.toData
                    )
                }
                
                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the Payment-SKEY (empty to abort)"))",
                    cleanup: [paymentVKey, paymentSKey]
                )
                
                _ = try await noora.progressStep(
                    message: "Encrypting the cborHex...",
                    successMessage: "Key encrypted successfully.",
                    errorMessage: "Failed to encrypt key.",
                    showSpinner: true
                ) { updateMessage in
                    try await skey.encrypt(with: password)
                    return
                }
                
                try skey.save(to: paymentSKey.string)
                
                try await lockAndPrintPaymentKeys()
                
            }
            else if keyGenMethod == .hw {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                let hwType = try await hwcli.startHardwareWallet()
                
                noora.info(.alert("Generating keys using \(hwType.rawValue)"))
                
                try await hwcli.address.keyGen(
                    path: "1852H/1815H/\(subAccount!)H/0/\(index!)",
                    hwFile: paymentSKey,
                    vkeyFile: paymentVKey
                )
                
                var vkey = try TextEnvelope.load(from: paymentVKey.string)
                vkey.description = "Payment Hardware Verification Key"
                
                let extraDescription = " (Account# \(subAccount!), Index# \(index!))"
                
                try await lockAndPrintPaymentKeys(extraDescription: extraDescription)
            }
            else if keyGenMethod == .hwMulti {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                let hwType = try await hwcli.startHardwareWallet()
                
                noora.info(.alert("Generating keys using \(hwType.rawValue)"))
                
                try await hwcli.address.keyGen(
                    path: "1854H/1815H/\(subAccount!)H/0/\(index!)",
                    hwFile: paymentSKey,
                    vkeyFile: paymentVKey
                )
                
                var vkey = try TextEnvelope.load(from: paymentVKey.string)
                vkey.description = "Payment Hardware Verification Key"
                
                let extraDescription = " (MultisSig Account# \(subAccount!), Index# \(index!))"
                
                try await lockAndPrintPaymentKeys(extraDescription: extraDescription)
                
            }
            else {
                // Should never happen due to validation
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli, enc, hw, hw_multi.",
                            "Re-run the command with the --help flag for more information."
                        ]
                    )
                )
                throw ExitCode.failure
            }
            
            noora.success(
                .alert("Payment address generated successfully.")
            )            
        }
    }
}
    
