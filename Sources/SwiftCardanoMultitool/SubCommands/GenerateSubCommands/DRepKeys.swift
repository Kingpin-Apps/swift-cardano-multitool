import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoWallet
import SwiftMnemonic

extension GenerateMainCommand {

    struct DRepKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "drep",
            abstract: "Generate Cardano governance DRep (Delegated Representative) keys."
        )

        @Option(name: .shortAndLong, help: "The name of the DRep. The key files will be saved as <name>.drep.vkey, <name>.drep.skey (or <name>.drep.hwsfile) and <name>.drep.id.")
        var drepName: String? = nil

        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw, mnemonics.")
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

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the DRep keys.")
        var tool: Tool? = nil

        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .mnemonics:
                    if subAccount == nil {
                        subAccount = 0
                    }
                    if index == nil {
                        index = 0
                    }
                case .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                    throw ValidationError("Unsupported key generation method. Use: cli, enc, hw, mnemonics.")
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
            drepName = noora.textPrompt(
                title: "DRep Name",
                prompt: "Enter the name of the DRep (without .drep.*):",
                description: "The corresponding key files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "DRep name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method to use.",
                options: KeyGenMethod.allCases
                    .filter {
                        [.cli, .enc, .hw, .mnemonics].contains($0)
                    },
                description: "Options are:\n- cli: Use cardano-cli to generate keys.\n- enc: Generate keys and encrypt the signing key with a password.\n- hw: Use a hardware wallet (Ledger/Trezor) to generate keys.\n- mnemonics: Derive a DRep key from a BIP-39 mnemonic (CIP-1852 role 3)."
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
                case .hw, .mnemonics:
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
            if drepName == nil && keyGenMethod == nil {
                try await self.wizard()
            }

            let config = try await MultitoolConfig.load()

            try await printToolInfo(config: config, tool: tool!)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)

            let drepVKey = cwd.appending("\(drepName!).drep.vkey")
            let drepSKey = keyGenMethod!.isHardwareType
                ? cwd.appending("\(drepName!).drep.hwsfile")
                : cwd.appending("\(drepName!).drep.skey")
            let drepId = cwd.appending("\(drepName!).drep.id")

            try await FileUtils.checkFile(drepVKey)
            try await FileUtils.checkFile(drepSKey)
            try await FileUtils.checkFile(drepId)

            func lockAndPrintKeys(extraDescription: String = "") async throws {
                try await FileUtils.fileLock(drepVKey)
                try await FileUtils.fileLock(drepSKey)
                try await FileUtils.fileLock(drepId)

                print(noora.format(
                    "\nDRep-Verification-Key\(extraDescription): \(.path(try .init(validating: drepVKey.string)))\n"
                ))
                try await FileUtils.displayFile(drepVKey)

                print(noora.format(
                    "\nDRep-Signing-Key\(extraDescription): \(.path(try .init(validating: drepSKey.string)))\n"
                ))
                try await FileUtils.displayFile(drepSKey)

                print(noora.format(
                    "\nDRep-ID\(extraDescription): \(.path(try .init(validating: drepId.string)))\n"
                ))
                try await FileUtils.displayFile(drepId)

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
                            "Using \(.primary("cardano-cli")) to generate DRep keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )

                        _ = try await cli.governance.drepKeyGen(
                            arguments: [
                                "--verification-key-file", drepVKey.string,
                                "--signing-key-file", drepSKey.string
                            ]
                        )

                        _ = try await cli.governance.drepId(
                            arguments: [
                                "--drep-verification-key-file", drepVKey.string,
                                "--out-file", drepId.string
                            ]
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate DRep keys")
                        )
                        let drepKeyPair = try DRepKeyPair.generate()
                        try drepKeyPair.verificationKey.save(to: drepVKey.string)
                        try drepKeyPair.signingKey.save(to: drepSKey.string)

                        let drep = DRep(
                            credential: .verificationKeyHash(
                                try drepKeyPair.verificationKey.hash()
                            )
                        )
                        try drep.save(to: drepId.string)
                }

                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .mnemonics {
                let drepMnemonics = cwd.appending("\(drepName!).drep.mnemonics")
                try await FileUtils.checkFile(drepMnemonics)

                let derivationPath = "1852H/1815H/\(subAccount!)H/3/\(index!)"

                print(noora.format(
                    "Generating DRep-Key via Derivation-Path: \(.primary(derivationPath))"
                ))

                if tool == .swiftCardano {
                    print(noora.format(
                        "Note: \(.primary("--tool swift-cardano")) is not supported for DRep mnemonic derivation; using \(.primary("cardano-signer")) instead."
                    ))
                }

                if let existing = mnemonics, !existing.isEmpty {
                    print(noora.format("Using Mnemonics: \(.primary(existing))"))
                } else {
                    mnemonics = try HDWallet.generateMnemonic(
                        language: language,
                        wordCount: wordCount
                    ).joined(separator: " ")
                    print(noora.format("Created Mnemonics: \(.primary(mnemonics!))"))
                }

                let signer = try await CardanoSigner(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )

                let responseJSON = try await signer.keygen(
                    path: derivationPath,
                    mnemonics: .words(mnemonics!),
                    withChainCode: true,
                    outputFormat: .jsonExtended,
                    outSkey: drepSKey
                )

                let signerResponse = try JSONSerialization.jsonObject(
                    with: responseJSON.toData,
                    options: []
                ) as! [String: Any]

                let extendedVKeyJSON = (signerResponse["output"] as! [String: Any])["vkey"] as! [String: String]
                let extendedVKeyData = try JSONEncoder().encode(extendedVKeyJSON)

                // Save extended VKEY to tmp directory, then convert to non-extended
                let tmpDir = FilePath(FileManager.default.temporaryDirectory.path)
                let tmpVKey = tmpDir.appending("temp.drep.extended.vkey")
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
                vkey["description"] = "Delegated Representative Verification Key"
                let vkeyData = try JSONEncoder().encode(vkey)

                do {
                    try vkeyData.write(
                        to: URL(fileURLWithPath: drepVKey.string),
                        options: .atomic
                    )
                } catch {
                    noora.error(
                        .alert(
                            "Could not write file: \(drepVKey.string). \(error)",
                            takeaways: [
                                "Make sure you have write permissions to the file path"
                            ]
                        )
                    )
                    throw ExitCode.failure
                }

                _ = try await cli.governance.drepId(
                    arguments: [
                        "--drep-verification-key-file", drepVKey.string,
                        "--out-file", drepId.string
                    ]
                )

                try saveMnemonics(mnemonics!, to: drepMnemonics)
                try await FileUtils.fileLock(drepMnemonics)
                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope

                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate DRep keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )

                        let skeyJSON = try await cli.governance.drepKeyGen(
                            arguments: [
                                "--verification-key-file", drepVKey.string,
                                "--signing-key-file", "/dev/stdout"
                            ]
                        )

                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )
                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate DRep keys")
                        )

                        let drepKeyPair = try DRepKeyPair.generate()
                        try drepKeyPair.verificationKey.save(to: drepVKey.string)

                        skey = try TextEnvelope.load(
                            from: try drepKeyPair.signingKey.toTextEnvelope()!
                        )
                }

                // Derive the DRep ID from the (still plaintext) vkey before
                // encrypting the skey, so an aborted password prompt does not
                // leave a stray .drep.id behind (cleanup list includes it).
                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                _ = try await cli.governance.drepId(
                    arguments: [
                        "--drep-verification-key-file", drepVKey.string,
                        "--out-file", drepId.string
                    ]
                )

                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the DRep-SKEY (empty to abort)"))",
                    cleanup: [drepVKey, drepSKey, drepId]
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

                try skey.save(to: drepSKey.string)

                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .hw {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )

                let hwType = try await hwcli.startHardwareWallet()

                let derivationPath = "1852H/1815H/\(subAccount!)H/3/\(index!)"

                noora.info(.alert(
                    "Generating keys using \(hwType.rawValue)",
                    takeaways: [
                        "Please keep your hardware wallet connected.",
                        "Sub-Account: \(subAccount!), Index: \(index!)",
                        "Derivation-Path: \(derivationPath)"
                    ]
                ))

                try await hwcli.address.keyGen(
                    path: derivationPath,
                    hwFile: drepSKey,
                    vkeyFile: drepVKey
                )

                var vkey = try TextEnvelope.load(from: drepVKey.string)
                vkey.description = "Delegated Representative Verification Key"
                try vkey.save(to: drepVKey.string)

                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                _ = try await cli.governance.drepId(
                    arguments: [
                        "--drep-verification-key-file", drepVKey.string,
                        "--out-file", drepId.string
                    ]
                )

                let extraDescription = " (Account# \(subAccount!), Index# \(index!))"

                try await lockAndPrintKeys(extraDescription: extraDescription)
            }
            else {
                // Should never happen due to validation
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli, enc, hw, mnemonics.",
                            "Re-run the command with the --help flag for more information."
                        ]
                    )
                )
                throw ExitCode.failure
            }

            noora.success(
                .alert("DRep keys generated successfully.")
            )
        }
    }
}
