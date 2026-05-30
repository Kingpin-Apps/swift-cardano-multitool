import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoWallet
import SwiftMnemonic

extension GenerateMainCommand {
    
    struct PaymentAddressOnly: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a payment address only."
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. The payment verification key and address will be saved as <name>.payment.vkey and <name>.payment.addr respectively.")
        var addressName: String? = nil
        
        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw, hw_multi, mnemonics.")
        var keyGenMethod: KeyGenMethod? = nil

        @Option(name: .shortAndLong, help: "Sub-account for HW or mnemonic key derivation (CIP-1852 account index).")
        var subAccount: Int? = nil

        @Option(name: .shortAndLong, help: "Leaf index for HW or mnemonic key derivation. To be used together with --sub-account.")
        var index: Int? = nil

        @Option(name: .shortAndLong, help: "The mnemonic phrase to use for generating the keys. If not provided, a new mnemonic will be generated.")
        var mnemonics: String? = nil

        @Option(name: .shortAndLong, help: "The language for the mnemonic phrase. Options are: \(Language.allCases.map { $0.rawValue }.joined(separator: ", ")).")
        var language: Language = .english

        @Option(
            name: .shortAndLong,
            help: "The word count for the mnemonic phrase. Options are: \(WordCount.allCases.map { $0.defaultValueDescription }.joined(separator: ", "))."
        )
        var wordCount: WordCount = .twentyFour

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the address.")
        var tool: Tool? = nil
        
        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .hwMulti, .mnemonics:
                    if subAccount == nil {
                        subAccount = 0
                    }
                    if index == nil {
                        index = 0
                    }
                case .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                    throw ValidationError("Hybrid methods generate both payment and stake keys; use `scm generate payment-and-stake-address` instead.")
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
                        [.cli, .enc, .hw, .hwMulti, .mnemonics].contains($0)
                    },
                description: "Options are:\n- cli: Use cardano-cli to generate keys.\n- enc: Generate keys and encrypt the signing key with a password.\n- hw: Use a hardware wallet (Ledger/Trezor) to generate keys.\n- hw_multi: Use a hardware wallet (Ledger/Trezor) to generate multisig keys.\n- mnemonics: Derive a payment key from a BIP-39 mnemonic (CIP-1852)."
            )

            if keyGenMethod == .mnemonics {
                let shouldGenerateMnemonics = noora.yesOrNoChoicePrompt(
                    title: "Mnemonics",
                    question: "Do you want to generate a new mnemonic phrase?",
                    defaultAnswer: false,
                    description: "If no, you will be prompted to enter an existing mnemonic phrase.",
                )

                if !shouldGenerateMnemonics {
                    mnemonics = noora.textPrompt(
                        title: "Mnemonic Phrase",
                        prompt: "Enter your existing mnemonic phrase:",
                        description: "The mnemonic phrase to use for generating the keys.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Mnemonic phrase cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    language = noora.singleChoicePrompt(
                        title: "Mnemonic Language",
                        question: "Select the language for the mnemonic phrase.",
                        description: "The language to use for the mnemonic phrase.",
                        filterMode: .enabled
                    )

                    wordCount = noora.singleChoicePrompt(
                        title: "Mnemonic Word Count",
                        question: "Select the word count for the mnemonic phrase.",
                        description: "The word count to use for the mnemonic phrase.",
                        filterMode: .enabled
                    )
                }
            }

            switch keyGenMethod {
                case .hw, .hwMulti, .mnemonics:
                    subAccount = Int(noora.textPrompt(
                        title: "Sub-Account",
                        prompt: "Enter the sub-account number (default 0):",
                        description: "The sub-account number for key derivation.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Sub-Account cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                    index = Int(noora.textPrompt(
                        title: "Index",
                        prompt: "Enter the index number (default 0):",
                        description: "The leaf index for key derivation.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Index cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                default:
                    break
            }
            
            tool = try await getToolToUse()
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if addressName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            try await printToolInfo(config: config, tool: tool!)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let paymentAddress = cwd.appending("\(addressName!).payment.addr")
            let paymentVKey = cwd.appending("\(addressName!).payment.vkey")
            let paymentSKey = keyGenMethod!.isHardwareType ? cwd.appending("\(addressName!).payment.hwsfile") : cwd.appending(
                "\(addressName!).payment.skey"
            )
            
            try await FileUtils.checkFile(paymentAddress)
            try await FileUtils.checkFile(paymentVKey)
            try await FileUtils.checkFile(paymentSKey)
            
            func lockAndPrintKeys(extraDescription: String = "") async throws {
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

            func saveMnemonics(_ phrase: String, to path: FilePath) throws {
                do {
                    try phrase.toData.write(
                        to: URL(fileURLWithPath: path.string),
                        options: .atomic
                    )
                    print(noora.format(
                        "Mnemonics written to file: \(.path(try .init(validating: path.string)))"
                    ))
                } catch {
                    noora.error(
                        .alert(
                            "Could not write file: \(path.string). \(error)",
                            takeaways: [
                                "Make sure you have write permissions to the file path"
                            ]
                        )
                    )
                    throw ExitCode.failure
                }
            }

            if keyGenMethod == .cli {
                switch tool {
                    case .cardanoCLI:
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
                        
                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate address keys")
                        )
                        let paymentKeyPair = try PaymentKeyPair.generate()
                        try paymentKeyPair.verificationKey.save(to: paymentVKey.string)
                        try paymentKeyPair.signingKey.save(to: paymentSKey.string)
                }
                
                try await lockAndPrintKeys()

            }
            else if keyGenMethod == .mnemonics {
                let paymentMnemonics = cwd.appending("\(addressName!).payment.mnemonics")
                try await FileUtils.checkFile(paymentMnemonics)

                print(noora.format(
                    "Generating Payment-Key via Derivation-Path: \(.primary("1852H/1815H/\(subAccount!)H/0/\(index!)"))"
                ))

                if tool == .cardanoCLI {
                    print(noora.format(
                        "Note: \(.primary("--tool cardano-cli")) is not wired up for mnemonics in payment-only mode; using \(.primary("SwiftCardano")) instead."
                    ))
                }
                print(noora.format(
                    "Using \(.primary("SwiftCardano")) to generate payment key from mnemonics."
                ))

                if let existing = mnemonics, !existing.isEmpty {
                    print(noora.format("Using Mnemonics: \(.primary(existing))"))
                } else {
                    mnemonics = try HDWallet.generateMnemonic(
                        language: language,
                        wordCount: wordCount
                    ).joined(separator: " ")
                    print(noora.format("Created Mnemonics: \(.primary(mnemonics!))"))
                }

                let km = try MnemonicKeyManager(mnemonic: mnemonics!)
                let paymentPath = DerivationPath(
                    purpose: DerivationPath.standardPurpose,
                    account: UInt32(subAccount!),
                    role: .external,
                    index: UInt32(index!)
                )

                let paymentSkeyType = try await km.paymentSigningKeyType(at: paymentPath)
                try paymentSkeyType.save(to: paymentSKey.string)

                let _paymentVKey = try await km.paymentVerificationKey(at: paymentPath)
                try _paymentVKey.save(to: paymentVKey.string)

                try saveMnemonics(mnemonics!, to: paymentMnemonics)
                try await FileUtils.fileLock(paymentMnemonics)
                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope
                
                switch tool {
                    case .cardanoCLI:
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
                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate address keys")
                        )
                        
                        let paymentKeyPair = try PaymentKeyPair.generate()
                        try paymentKeyPair.verificationKey.save(to: paymentVKey.string)
                        
                        skey = try TextEnvelope.load(
                            from: try paymentKeyPair.signingKey.toTextEnvelope()!
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
                
                try await lockAndPrintKeys()
                
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
                
                try await lockAndPrintKeys(extraDescription: extraDescription)
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
                
                try await lockAndPrintKeys(extraDescription: extraDescription)
                
            }
            else {
                // Should never happen due to validation
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli, enc, hw, hw_multi, mnemonics.",
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
    
