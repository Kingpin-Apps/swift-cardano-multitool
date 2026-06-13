import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner
import SwiftCardanoUtils
import SwiftCardanoWallet
import SwiftMnemonic

extension GenerateMainCommand {

    struct Policy: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "policy",
            abstract: "Generate a Cardano native-script minting policy."
        )

        @Option(name: .shortAndLong, help: "The name of the policy. Files will be saved as <name>.policy.vkey, <name>.policy.skey (or <name>.policy.hwsfile), <name>.policy.script and <name>.policy.id.")
        var policyName: String? = nil

        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw, mnemonics.")
        var keyGenMethod: KeyGenMethod? = nil

        @Option(name: .shortAndLong, help: "Policy index for HW or mnemonic derivation (CIP-1855 policy index).")
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

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the policy keys and script hash.")
        var tool: Tool? = nil

        @Option(name: .long, help: "Optional slot count (seconds) from the current chain tip after which the policy becomes invalid. Omit for an unlimited (sig-only) policy. Requires online or lite mode.")
        var slotLimit: UInt64? = nil

        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .mnemonics:
                    if subAccount == nil {
                        subAccount = 0
                    }
                case .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                    throw ValidationError("Unsupported key generation method. Use: cli, enc, hw, mnemonics.")
                default:
                    break
            }

            if let subAccount {
                guard subAccount >= 0 else {
                    throw ValidationError("The policy index must be a non-negative integer.")
                }
                guard subAccount <= 2147483647 else {
                    throw ValidationError("The policy index must be less than or equal to 2147483647.")
                }
            }

            if let slotLimit, slotLimit == 0 {
                throw ValidationError("--slot-limit must be greater than zero.")
            }
        }

        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            policyName = noora.textPrompt(
                title: "Policy Name",
                prompt: "Enter the name of the policy (without .policy.*):",
                description: "The corresponding files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Policy name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method to use.",
                options: KeyGenMethod.allCases
                    .filter {
                        [.cli, .enc, .hw, .mnemonics].contains($0)
                    },
                description: "Options are:\n- cli: Use cardano-cli or SwiftCardano to generate keys.\n- enc: Generate keys and encrypt the signing key with a password.\n- hw: Use a hardware wallet (Ledger/Trezor) to generate keys at CIP-1855 path.\n- mnemonics: Derive a policy key from a BIP-39 mnemonic (CIP-1855)."
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
                        title: "Policy Index",
                        prompt: "Enter the policy index (default 0):",
                        description: "The CIP-1855 policy index for key derivation.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Policy index cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                default:
                    break
            }

            tool = try await getToolToUse()

            let shouldTimeLock = noora.yesOrNoChoicePrompt(
                title: "Time-locked Policy",
                question: "Should this policy expire after a number of slots?",
                defaultAnswer: false,
                description: "Time-locked policies become invalid after a chosen slot. Requires an online node to query the current tip."
            )

            if shouldTimeLock {
                slotLimit = UInt64(noora.textPrompt(
                    title: "Slot Limit",
                    prompt: "Enter the number of slots (seconds) until the policy expires:",
                    description: "The policy will be valid before currentSlot + slotLimit.",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Slot limit cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            try self.validate()
        }

        mutating func run() async throws {
            if policyName == nil && keyGenMethod == nil {
                try await self.wizard()
            }

            let config = try await MultitoolConfig.load()

            try await printToolInfo(config: config, tool: tool!)

            if slotLimit != nil, config.mode == .offline {
                noora.error(.alert(
                    "Cannot build a time-locked policy in offline mode.",
                    takeaways: [
                        "Switch to online, auto, or lite mode to query the current chain tip.",
                        "Use 'config select' to change the mode, or omit --slot-limit for an unlimited policy."
                    ]
                ))
                throw ExitCode.failure
            }

            let cwd = FilePath(FileManager.default.currentDirectoryPath)

            let policyVKey = cwd.appending("\(policyName!).policy.vkey")
            let policySKey = keyGenMethod!.isHardwareType
                ? cwd.appending("\(policyName!).policy.hwsfile")
                : cwd.appending("\(policyName!).policy.skey")
            let policyScript = cwd.appending("\(policyName!).policy.script")
            let policyId = cwd.appending("\(policyName!).policy.id")

            try await FileUtils.checkFile(policyVKey)
            try await FileUtils.checkFile(policySKey)
            try await FileUtils.checkFile(policyScript)
            try await FileUtils.checkFile(policyId)

            func lockAndPrintFiles(extraDescription: String = "") async throws {
                try await FileUtils.fileLock(policyVKey)
                try await FileUtils.fileLock(policySKey)
                try await FileUtils.fileLock(policyScript)
                try await FileUtils.fileLock(policyId)

                print(noora.format(
                    "\nPolicy-Verification-Key\(extraDescription): \(.path(try .init(validating: policyVKey.string)))\n"
                ))
                try await FileUtils.displayFile(policyVKey)

                print(noora.format(
                    "\nPolicy-Signing-Key\(extraDescription): \(.path(try .init(validating: policySKey.string)))\n"
                ))
                try await FileUtils.displayFile(policySKey)

                print(noora.format(
                    "\nPolicy-Script\(extraDescription): \(.path(try .init(validating: policyScript.string)))\n"
                ))
                try await FileUtils.displayFile(policyScript)

                print(noora.format(
                    "\nPolicy-ID\(extraDescription): \(.path(try .init(validating: policyId.string)))\n"
                ))
                try await FileUtils.displayFile(policyId)

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

            // MARK: - Generate key material

            if keyGenMethod == .cli {
                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate policy keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )

                        _ = try await cli.address.keyGen(
                            arguments: [
                                "--verification-key-file", policyVKey.string,
                                "--signing-key-file", policySKey.string
                            ]
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate policy keys")
                        )
                        let keyPair = try PaymentKeyPair.generate()
                        try keyPair.verificationKey.save(to: policyVKey.string)
                        try keyPair.signingKey.save(to: policySKey.string)
                }
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope

                switch tool {
                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate policy keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )

                        let skeyJSON = try await cli.address.keyGen(
                            arguments: [
                                "--verification-key-file", policyVKey.string,
                                "--signing-key-file", "/dev/stdout"
                            ]
                        )

                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )
                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate policy keys")
                        )

                        let keyPair = try PaymentKeyPair.generate()
                        try keyPair.verificationKey.save(to: policyVKey.string)

                        skey = try TextEnvelope.load(
                            from: try keyPair.signingKey.toTextEnvelope()!
                        )
                }

                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the Policy-SKEY (empty to abort)"))",
                    cleanup: [policyVKey, policySKey]
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

                try skey.save(to: policySKey.string)
            }
            else if keyGenMethod == .hw {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )

                let hwType = try await hwcli.startHardwareWallet()

                let derivationPath = "1855H/1815H/\(subAccount!)H"

                noora.info(.alert(
                    "Generating keys using \(hwType.rawValue)",
                    takeaways: [
                        "Please keep your hardware wallet connected.",
                        "Policy index: \(subAccount!)",
                        "Derivation-Path: \(derivationPath)"
                    ]
                ))

                try await hwcli.address.keyGen(
                    path: derivationPath,
                    hwFile: policySKey,
                    vkeyFile: policyVKey
                )
            }
            else if keyGenMethod == .mnemonics {
                let policyMnemonics = cwd.appending("\(policyName!).policy.mnemonics")
                try await FileUtils.checkFile(policyMnemonics)

                let derivationPath = "1855H/1815H/\(subAccount!)H"

                print(noora.format(
                    "Generating Policy-Key via Derivation-Path: \(.primary(derivationPath))"
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

                switch tool {
                    case .swiftCardano:
                        print(noora.format(
                            "Using \(.primary("SwiftCardanoSigner")) to derive the policy key")
                        )

                        // CIP-1855 minting-policy key derivation, native via the
                        // swift-cardano-signer library (path m/1855'/1815'/<ix>').
                        let bundle = try Signer.Keygen.policy(
                            mnemonic: mnemonics!.split(separator: " ").map(String.init),
                            policyIndex: UInt32(subAccount!)
                        )

                        // Extended signing key (with chain code) + non-extended
                        // payment verification key, matching the cardano-signer flow.
                        try bundle.signingKey.save(to: policySKey.string)

                        let policyVerificationKey: PaymentVerificationKey =
                            try bundle.verificationKey.toNonExtended()
                        try policyVerificationKey.save(to: policyVKey.string)

                    default:
                        print(noora.format(
                            "Using \(.primary("cardano-signer")) to derive the policy key")
                        )

                        let signer = try await CardanoSigner(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )

                        let responseJSON = try await signer.keygen(
                            path: derivationPath,
                            mnemonics: .words(mnemonics!),
                            withChainCode: true,
                            outputFormat: .jsonExtended,
                            outSkey: policySKey
                        )

                        let signerResponse = try JSONSerialization.jsonObject(
                            with: responseJSON.toData,
                            options: []
                        ) as! [String: Any]

                        let extendedVKeyJSON = (signerResponse["output"] as! [String: Any])["vkey"] as! [String: String]
                        let extendedVKeyData = try JSONEncoder().encode(extendedVKeyJSON)

                        let tmpDir = FilePath(FileManager.default.temporaryDirectory.path)
                        let tmpVKey = tmpDir.appending("temp.policy.extended.vkey")
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
                                to: URL(fileURLWithPath: policyVKey.string),
                                options: .atomic
                            )
                        } catch {
                            noora.error(
                                .alert(
                                    "Could not write file: \(policyVKey.string). \(error)",
                                    takeaways: [
                                        "Make sure you have write permissions to the file path"
                                    ]
                                )
                            )
                            throw ExitCode.failure
                        }
                }

                try saveMnemonics(mnemonics!, to: policyMnemonics)
                try await FileUtils.fileLock(policyMnemonics)
            }
            else {
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

            // MARK: - Compute key hash

            let keyHashHex: String
            if tool == .swiftCardano,
               keyGenMethod == .cli || keyGenMethod == .enc || keyGenMethod == .mnemonics {
                let vk: PaymentVerificationKey = try PaymentVerificationKey.load(
                    from: policyVKey.string
                )
                keyHashHex = try vk.hash().payload.toHex
            } else {
                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                let raw = try await cli.address.keyHash(
                    arguments: ["--payment-verification-key-file", policyVKey.string]
                )
                keyHashHex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // MARK: - Resolve time-lock slot

            var validBefore: UInt64? = nil
            if let slotLimit {
                let context = try await getContext(config: config)
                try await printContextInfo(config: config, context: context)
                
                let (chainTip, _) = try await queryChainState(
                    context: context,
                    config: config
                )

                validBefore = UInt64(chainTip) + slotLimit
                print(noora.format(
                    "Policy expires at slot \(.primary(String(validBefore!))) (current tip: \(chainTip), slot-limit: \(slotLimit))"
                ))
            }

            // MARK: - Write policy script JSON

            let scriptDict: [String: Any]
            if let validBefore {
                scriptDict = [
                    "type": "all",
                    "scripts": [
                        ["slot": validBefore, "type": "before"],
                        ["keyHash": keyHashHex, "type": "sig"]
                    ]
                ]
            } else {
                scriptDict = [
                    "keyHash": keyHashHex,
                    "type": "sig"
                ]
            }

            try FileUtils.dumpJSONFile(policyScript, data: scriptDict)

            // MARK: - Compute policy ID

            let policyIdHex: String
            if keyGenMethod == .hw {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                let raw = try await hwcli.transaction.policyId(
                    scriptFile: policyScript,
                    hwSigningFile: policySKey
                )
                policyIdHex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if tool == .swiftCardano {
                let keyHashData = Data(hexString: keyHashHex)!
                let sig: NativeScript = .scriptPubkey(
                    ScriptPubkey(keyHash: VerificationKeyHash(payload: keyHashData))
                )
                let native: NativeScript
                if let validBefore {
                    native = .scriptAll(ScriptAll(scripts: [
                        .invalidBefore(BeforeScript(slot: validBefore)),
                        sig
                    ]))
                } else {
                    native = sig
                }
                policyIdHex = try native.scriptHash().payload.toHex
            } else {
                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                let raw = try await cli.transaction.policyId(
                    arguments: ["--script-file", policyScript.string]
                )
                policyIdHex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            try FileUtils.dumpFile(policyId, data: policyIdHex)

            let extraDescription: String
            switch keyGenMethod {
                case .hw:
                    extraDescription = " (Policy Index# \(subAccount!))"
                case .mnemonics:
                    extraDescription = " (Policy Index# \(subAccount!))"
                default:
                    extraDescription = ""
            }

            try await lockAndPrintFiles(extraDescription: extraDescription)

            noora.success(
                .alert("Policy generated successfully.")
            )
        }
    }
}
