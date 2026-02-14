import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils
import SwiftCardanoCore
import SwiftMnemonic

extension GenerateMainCommand {
    
    struct PaymentAndStakeAddress: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate a payment and stake address."
        )
        
        @Option(name: .shortAndLong, help: "The name of the address. The keys and addresses will be saved as <name>.payment.vkey, <name>.payment.skey, <name>.stake.vkey, <name>.stake.skey, <name>.payment.addr and <name>.stake.addr.")
        var addressName: String? = nil
        
        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw, hw_multi.")
        var keyGenMethod: KeyGenMethod? = nil
        
        @Option(name: .shortAndLong, help: "Generates Payment keys using Ledger/Trezor HW-Keys with Index at this number. To be used together with --sub-account.")
        var index: Int? = nil
        
        @Option(name: .shortAndLong, help: "Generates Payment keys using Ledger/Trezor HW-Keys with SubAccount at this number.")
        var subAccount: Int? = nil
        
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
                case .hw, .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                    if  subAccount == nil{
                        subAccount = 0
                    }
                    if index == nil {
                        index = 0
                    }
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
                prompt: "Enter the name of the address (without .payment.addr or .stake.addr):",
                description: "The corresponding key files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method to use.",
                description: "The method to use for key generation.",
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
                }
                else {
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
                case .hw, .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc, .mnemonics:
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
            
            tool = try await getToolToUse()
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if addressName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let paymentAddress = cwd.appending("\(addressName!).payment.addr")
            let paymentVKey = cwd.appending("\(addressName!).payment.vkey")
            let paymentSKey = keyGenMethod!.isHardwareType ? cwd.appending("\(addressName!).payment.hwsfile") : cwd.appending("\(addressName!).payment.skey")
            
            let stakeAddress = cwd.appending("\(addressName!).stake.addr")
            let stakeVKey = cwd.appending("\(addressName!).stake.vkey")
            let stakeSKey = keyGenMethod!.isHardwareType ?
            cwd.appending("\(addressName!).stake.hwsfile") :
            cwd.appending("\(addressName!).stake.skey")
            
            try await FileUtils.checkFile(paymentAddress)
            try await FileUtils.checkFile(paymentVKey)
            try await FileUtils.checkFile(paymentSKey)
            
            try await FileUtils.checkFile(stakeAddress)
            try await FileUtils.checkFile(stakeVKey)
            try await FileUtils.checkFile(stakeSKey)
            
            var hwRootPath: String
            var multiSigPrefix: String
            if keyGenMethod!.isMultisigType {
                hwRootPath = "1854"
                multiSigPrefix = "MultiSig-"
            } else {
                hwRootPath = "1852"
                multiSigPrefix = ""
            }
            
            func lockAndPrintPaymentKeys(extraDescription: String = "") async throws {
                try await FileUtils.fileLock(paymentVKey)
                try await FileUtils.fileLock(paymentSKey)
                
                print(noora.format(
                    "\nPayment(Base)-Verification-Key\(extraDescription): \(.path(try .init(validating: paymentVKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentVKey)
                
                print(noora.format(
                    "\nPayment(Base)-Signing-Key\(extraDescription): \(.path(try .init(validating: paymentSKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentSKey)
                
                print("\n")
            }
            
            func lockAndPrintStakeKeys(prefix: String = "", extraDescription: String = "") async throws {
                try await FileUtils.fileLock(stakeVKey)
                try await FileUtils.fileLock(stakeSKey)
                
                print(noora.format(
                    "\n\(prefix)Stake(Rewards)-Verification-Key\(extraDescription): \(.path(try .init(validating: paymentVKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentVKey)
                
                print(noora.format(
                    "\n\(prefix)Stake(Rewards)-Signing-Key\(extraDescription): \(.path(try .init(validating: paymentSKey.string)))\n"
                ))
                try await FileUtils.displayFile(paymentSKey)
                
                print("\n")
            }
            
            func saveMnemonics(_ mnemonics: String, to path: FilePath) throws {
                // save memnonics
                do {
                    try mnemonics.toData.write(
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
            
            // Generate Payment Address Keys
            if keyGenMethod == .cli {

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate payment address keys")
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
                            "Using \(.primary("SwiftCardano")) to generate payment address keys")
                        )
                        let paymentKeyPair = try PaymentKeyPair.generate()
                        try paymentKeyPair.verificationKey.save(to: paymentVKey.string)
                        try paymentKeyPair.signingKey.save(to: paymentSKey.string)
                }
                
                try await lockAndPrintPaymentKeys()
                
            }
            else if keyGenMethod == .mnemonics {
                let paymentMnemonics = cwd.appending("\(addressName!).payment.mnemonics")
                
                try await FileUtils.checkFile(paymentMnemonics)
                print(noora.format(
                    "Generating CLI Payment-Keys via Derivation-Path: \(.primary("\(hwRootPath)H/1815H/\(subAccount!)H/0/\(index!)"))")
                )

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-signer")) to generate address keys from mnemonics."
                        ))
                        let signer = try await CardanoSigner(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let signerResponse: [String: Any]
                        
                        if let mnemonics = mnemonics, mnemonics.isEmpty == false {
                            
                            print(noora.format(
                                "Using Mnemonics: \(.primary(mnemonics))"
                            ))
                            
                            let responseJSON = try await signer.keygen(
                                path: "\(hwRootPath)H/1815H/\(subAccount!)H/0/\(index!)",
                                mnemonics: .words(mnemonics),
                                withChainCode: true,
                                outputFormat: .jsonExtended,
                                outSkey: paymentSKey
                            )
                            signerResponse = try JSONSerialization.jsonObject(
                                with: responseJSON.toData,
                                options: []
                            ) as! [String: Any]
                            
                            print(noora.format(
                                "Keys generated successfully from provided mnemonics."
                            ))
                        }
                        else {
                            print(noora.format(
                                "Using \(.primary("cardano-signer")) to generate new mnemonics."
                            ))
                            // Generate new mnemonics
                            let responseJSON = try await signer.keygen(
                                path: "\(hwRootPath)H/1815H/\(subAccount!)H/0/\(index!)",
                                withChainCode: true,
                                outputFormat: .jsonExtended,
                                outSkey: paymentSKey,
                            )
                            
                            do {
                                signerResponse = try (JSONSerialization.jsonObject(
                                    with: responseJSON.toData,
                                    options: []
                                ) as? [String: Any])!
                                
                                if let mnemonicsFromSigner = signerResponse["mnemonic"] as? String {
                                    mnemonics = mnemonicsFromSigner
                                    
                                    print(noora.format(
                                        "Created Mnemonics: \(.primary(mnemonicsFromSigner))"
                                    ))
                                    
                                }
                                else {
                                    noora.error(.alert(
                                        "Failed to generate mnemonics from the response from the signer",
                                        takeaways: [
                                            "Make sure the response from the signer is in the correct format",
                                            "\(responseJSON)"
                                        ]
                                    ))
                                    throw ExitCode.failure
                                }
                            }
                            catch let error as NSError {
                                noora.error(
                                    .alert(
                                        "Failed to load: \(error.localizedDescription)",
                                        takeaways: [
                                            "Make sure the response from the signer is in the correct format",
                                            "\(responseJSON)"
                                        ]
                                    )
                                )
                                throw ExitCode.failure
                            }
                        }
                        
                        // save memnonics
                        try saveMnemonics(mnemonics!, to: paymentMnemonics)
                        
                        let extendedVKeyJSON = (signerResponse["output"] as! [String: Any])["vkey"] as! [String: String]
                        let extendedVKeyData = try JSONEncoder().encode(extendedVKeyJSON)
                        
                        // Save Extended VKEY to tmp directory
                        let tmpDir = FilePath(FileManager.default.temporaryDirectory.path)
                        let tmpVKey = tmpDir.appending("temp.extended.vkey")
                        try extendedVKeyData.write(
                            to: URL(fileURLWithPath: tmpVKey.string),
                            options: .atomic
                        )
                        
                        let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
                        let vkeyJSON = try await cli.key.nonExtendedKey(
                            arguments: [
                                "--extended-verification-key-file", tmpVKey.string,
                                "--verification-key-file", "/dev/stdout"
                            ]
                        )
                        
                        var vkey = try JSONSerialization.jsonObject(
                            with: vkeyJSON.toData,
                            options: []
                        ) as! [String: String]
                        vkey["description"] = "Payment Verification Key"
                        let vkeyData = try JSONEncoder().encode(vkey)
                        
                        do {
                            try vkeyData.write(
                                to: URL(fileURLWithPath: paymentVKey.string),
                                options: .atomic
                            )
                        }
                        catch {
                            noora.error(
                                .alert(
                                    "Could not write file: \(paymentVKey.string). \(error)",
                                    takeaways: [
                                        "Make sure you have write permissions to the file path"
                                    ]
                                )
                            )
                            throw ExitCode.failure
                        }

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate address keys from mnemonics.")
                        )
                        
                        if let mnemonics = mnemonics, mnemonics.isEmpty == false {
                            print(noora.format(
                            "Using Mnemonics: \(.primary(mnemonics))"
                            ))
                            
                            let hdWallet = try HDWallet.fromMnemonic(
                                mnemonic: mnemonics
                            )
                            
                            let hdWalletPayment = try hdWallet.derive(
                                fromPath: "m/\(hwRootPath)'/1815'/\(subAccount!)'/0/\(index!)"
                            )
                            
                            let paymentExtendedSkey = try ExtendedSigningKey.fromHDWallet(
                                hdWalletPayment
                            )
                            let paymentExtendedVKey: PaymentExtendedVerificationKey = try paymentExtendedSkey.toVerificationKey()
                            let _paymentVKey: PaymentVerificationKey = try paymentExtendedVKey.toNonExtended()
                            
                            try paymentExtendedSkey.save(to: paymentSKey.string)
                            try _paymentVKey.save(to: paymentVKey.string)
                            
                            print(noora.format(
                                "Keys generated successfully from provided mnemonics."
                            ))
                        }
                        else {
                            print(noora.format(
                                "Using \(.primary("cardano-signer")) to generate new mnemonics."
                            ))
                            
                            mnemonics = try HDWallet.generateMnemonic(
                                language: language,
                                wordCount: wordCount
                            ).joined(separator: " ")
                            
                            
                            print(noora.format(
                                "Created Mnemonics: \(.primary(mnemonics!))"
                            ))
                            let hdWallet = try HDWallet.fromMnemonic(
                                mnemonic: mnemonics!
                            )
                            
                            let hdWalletPayment = try hdWallet.derive(
                                fromPath: "m/\(hwRootPath)'/1815'/\(subAccount!)'/0/\(index!)"
                            )
                            
                            let paymentExtendedSkey = try ExtendedSigningKey.fromHDWallet(
                                hdWalletPayment
                            )
                            let paymentExtendedVKey: PaymentExtendedVerificationKey = try paymentExtendedSkey.toVerificationKey()
                            let _paymentVKey: PaymentVerificationKey = try paymentExtendedVKey.toNonExtended()
                            
                            try paymentExtendedSkey.save(to: paymentSKey.string)
                            try _paymentVKey.save(to: paymentVKey.string)
                        }
                    
                        // save memnonics
                        try saveMnemonics(mnemonics!, to: paymentMnemonics)
                    
                    try await FileUtils.fileLock(paymentMnemonics)
                    try await lockAndPrintPaymentKeys()
                }
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope

                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "\nUsing \(.primary("cardano-cli")) to generate address keys...\n")
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
                            "\nUsing \(.primary("SwiftCardano")) to generate address keys...\n")
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
                
                try await lockAndPrintPaymentKeys()
                
            }
            else if keyGenMethod == .hw {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                let hwType = try await hwcli.startHardwareWallet()
                
                noora.info(.alert("Generating payment keys using \(hwType.rawValue)"))
                
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
                .alert("\nPayment address keys generated successfully.\n")
            )
            
            // Generate Stake Address Keys
            if keyGenMethod == .cli || keyGenMethod == .hybrid || keyGenMethod == .hybridMulti {
                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "\nUsing \(.primary("cardano-cli")) to generate stake address keys...\n")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await cli.stakeAddress.keyGen(
                            arguments: [
                                "--verification-key-file", stakeVKey.string,
                                "--signing-key-file", stakeSKey.string
                            ]
                        )
                    
                    default:
                        print(noora.format(
                            "\nUsing \(.primary("SwiftCardano")) to generate stake address keys...\n")
                        )
                        let stakeKeyPair = try StakeKeyPair.generate()
                        try stakeKeyPair.verificationKey.save(to: stakeVKey.string)
                        try stakeKeyPair.signingKey.save(to: stakeSKey.string)

                }
                
                try await lockAndPrintStakeKeys()
            }
            else if keyGenMethod == .mnemonics {
                print(noora.format(
                    "\nGenerating CLI Stake-Keys via Derivation-Path: \(.primary("\(hwRootPath)H/1815H/\(subAccount!)H/2/\(index!)"))\n")
                )

                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "\nUsing \(.primary("cardano-signer")) to generate stake address keys from mnemonics...\n"
                        ))
                        let signer = try await CardanoSigner(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let responseJSON = try await signer.keygen(
                            path: "\(hwRootPath)H/1815H/\(subAccount!)H/2/\(index!)",
                            mnemonics: .words(mnemonics!),
                            withChainCode: true,
                            outputFormat: .jsonExtended,
                            outSkey: stakeSKey
                        )
                        let signerResponse = try JSONSerialization.jsonObject(
                            with: responseJSON.toData,
                            options: []
                        ) as! [String: Any]
                        
                        let extendedVKeyJSON = (signerResponse["output"] as! [String: Any])["vkey"] as! [String: String]
                        let extendedVKeyData = try JSONEncoder().encode(extendedVKeyJSON)
                        
                        // Save Extended VKEY to tmp directory
                        let tmpDir = FilePath(FileManager.default.temporaryDirectory.path)
                        let tmpVKey = tmpDir.appending("temp.extended.vkey")
                        try extendedVKeyData.write(
                            to: URL(fileURLWithPath: tmpVKey.string),
                            options: .atomic
                        )
                        
                        let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
                        let vkeyJSON = try await cli.key.nonExtendedKey(
                            arguments: [
                                "--extended-verification-key-file", tmpVKey.string,
                                "--verification-key-file", "/dev/stdout"
                            ]
                        )
                        
                        var vkey = try JSONSerialization.jsonObject(
                            with: vkeyJSON.toData,
                            options: []
                        ) as! [String: String]
                        vkey["description"] = "Stake Verification Key"
                        let vkeyData = try JSONEncoder().encode(vkey)
                        
                        do {
                            try vkeyData.write(
                                to: URL(fileURLWithPath: stakeVKey.string),
                                options: .atomic
                            )
                        }
                        catch {
                            noora.error(
                                .alert(
                                    "Could not write file: \(stakeVKey.string). \(error)",
                                    takeaways: [
                                        "Make sure you have write permissions to the file path"
                                    ]
                                )
                            )
                            throw ExitCode.failure
                        }

                    default:
                        print(noora.format(
                            "\nUsing \(.primary("SwiftCardano")) to generate stake address keys from mnemonics...\n")
                        )
                        
                        let hdWallet = try HDWallet.fromMnemonic(
                            mnemonic: mnemonics!
                        )
                        
                        let hdWalletStake = try hdWallet.derive(
                            fromPath: "m/\(hwRootPath)'/1815'/\(subAccount!)'/2/\(index!)"
                        )
                        
                        let stakeExtendedSkey = try StakeExtendedSigningKey.fromHDWallet(hdWalletStake)
                        let stakeExtendedVKey: StakeExtendedVerificationKey = try stakeExtendedSkey.toVerificationKey()
                        let _stakeVKey: StakeVerificationKey = try stakeExtendedVKey.toNonExtended()
                        
                        try stakeExtendedSkey.save(to: stakeSKey.string)
                        try _stakeVKey.save(to: stakeVKey.string)
                        
                        print(noora.format(
                            "\nKeys generated successfully from provided mnemonics.\n"
                        ))
                }
                
                try await lockAndPrintStakeKeys()
            }
            else if keyGenMethod == .enc || keyGenMethod == .hybridEnc || keyGenMethod == .hybridMultiEnc {
                var skey: TextEnvelope


                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "\nUsing \(.primary("cardano-cli")) to generate stake address keys...\n")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let skeyJSON = try await cli.stakeAddress.keyGen(
                            arguments: [
                                "--verification-key-file", stakeVKey.string,
                                "--signing-key-file", "/dev/stdout"
                            ]
                        )
                        
                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )
                    
                    default:
                        print(noora.format(
                            "\nUsing \(.primary("SwiftCardano")) to generate stake address keys...\n")
                        )
                        let stakeKeyPair = try StakeKeyPair.generate()
                        try stakeKeyPair.verificationKey.save(to: stakeVKey.string)
                        try stakeKeyPair.signingKey.save(to: stakeSKey.string)
                        
                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: stakeKeyPair.signingKey.toJSON()!.toData
                        )
                }
                
                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the Stake-SKEY (empty to abort)"))",
                    cleanup: [stakeVKey, stakeSKey]
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
                
                try skey.save(to: stakeSKey.string)
                
                try await lockAndPrintPaymentKeys()
            }
            else if keyGenMethod == .hw || keyGenMethod == .hwMulti {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                let hwType = try await hwcli.startHardwareWallet()
                
                noora.info(.alert("\nGenerating stake keys using \(hwType.rawValue)"))
                
                try await hwcli.address.keyGen(
                    path: "\(hwRootPath)H/1815H/\(subAccount!)H/2/0",
                    hwFile: stakeSKey,
                    vkeyFile: stakeVKey
                )
                
                var vkey = try TextEnvelope.load(from: paymentVKey.string)
                vkey.description = "Stake Hardware Verification Key"
                
                let extraDescription = " (Account# \(subAccount!), Index# \(index!))"
                
                try await lockAndPrintStakeKeys(
                    prefix: multiSigPrefix, extraDescription: extraDescription
                )
            }
            else {
                // Should never happen due to validation
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli, enc, hw, hw_multi, hybrid, hybrid_enc, hybrid_multi, hybrid_multi_enc.",
                            "Re-run the command with the --help flag for more information."
                        ]
                    )
                )
                throw ExitCode.failure
            }
            
            noora.success(
                .alert("\nStake address keys generated successfully...\n")
            )

            switch tool {
                case .cardanoCLI:
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    let _ = try await cli.address.build(
                        arguments: [
                            "--payment-verification-key-file", paymentVKey.string,
                            "--stake-verification-key-file", stakeVKey.string,
                            "--out-file", paymentAddress.string,
                        ]
                    )
                    
                    let _ = try await cli.stakeAddress.build(
                        arguments: [
                            "--payment-verification-key-file", paymentVKey.string,
                            "--stake-verification-key-file", stakeVKey.string,
                            "--out-file", stakeAddress.string,
                        ]
                    )
                
                default:
                    let _paymentVKey = try PaymentVerificationKey.load(from: paymentVKey.string)
                    let _stakeVKey = try StakeVerificationKey.load(from: stakeVKey.string)
                    
                    let paymentAddr = try Address(
                        paymentPart: .verificationKeyHash(_paymentVKey.hash()),
                        stakingPart: .verificationKeyHash(_stakeVKey.hash()),
                        network: config.cardano.network.networkId
                    )
                    try paymentAddr.save(to: paymentAddress.string)
                    
                    let stakeAddr = try Address(
                        stakingPart: .verificationKeyHash(_stakeVKey.hash()),
                        network: config.cardano.network.networkId
                    )
                    try stakeAddr.save(to: stakeAddress.string)
            }
            
            try await FileUtils.fileLock(paymentAddress)
            try await FileUtils.fileLock(stakeAddress)
            
            spacedPrint("\nPayment(Base)-Address built: \(.path(try .init(validating: paymentAddress.string)))")
            try await FileUtils.displayFile(paymentAddress)
            
            spacedPrint("\nStaking(Rewards)-Address built: \(.path(try .init(validating: stakeAddress.string)))")
            try await FileUtils.displayFile(stakeAddress)
        }
    }
}
