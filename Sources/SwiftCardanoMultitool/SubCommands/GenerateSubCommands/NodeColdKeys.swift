import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension GenerateMainCommand {
    
    struct NodeColdKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node cold keys."
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The node cold keys will be saved as <name>.cold.vkey, <name>.cold.skey and <name>.cold.counter.")
        var poolName: String? = nil
        
        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli, enc, hw.")
        var keyGenMethod: KeyGenMethod? = nil
        
        @Option(name: .shortAndLong, help: "Generates node cold keys using Ledger/Trezor HW-Keys with Index at this number. Default is 0.")
        var coldKeyIndex: Int? = nil
        
        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the address.")
        var tool: Tool? = nil
        
        mutating func validate() throws {
            switch keyGenMethod {
                case .hw:
                    if  coldKeyIndex == nil{
                        coldKeyIndex = 0
                    }
                case .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc, .hwMulti:
                    throw ValidationError("Unsupported key generation method. Please choose from: cli, enc, hw, hw_multi.")
                default:
                    break
            }
            
            if coldKeyIndex != nil {
                guard coldKeyIndex! >= 0 else {
                    throw ValidationError("The index must be a non-negative integer.")
                }
                guard coldKeyIndex! <= 2147483647 else {
                    throw ValidationError("The index must be less than or equal to 2147483647.")
                }
            }
            
        }
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            poolName = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the name of the pool:",
                description: "The corresponding key files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            keyGenMethod = noora.singleChoicePrompt(
                title: "Key Generation Method",
                question: "Select the key generation method to use.",
                options: KeyGenMethod.allCases
                    .filter {
                        [.cli, .enc, .hw].contains($0)
                    },
                description: "Choose the method to generate the node cold keys. Options are:\n- cli: Use cardano-cli to generate the keys.\n- enc: Generate unencrypted keys and encrypt the signing key with a password.\n- hw: Use a connected hardware wallet (Ledger/Trezor) to generate the keys."
            )
            
            switch keyGenMethod {
                case .hw, .hwMulti:
                    coldKeyIndex = Int(noora.textPrompt(
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
            if poolName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let poolCounter = cwd.appending("\(poolName!).cold.counter")
            let poolVKey = cwd.appending("\(poolName!).cold.vkey")
            let poolSKey = keyGenMethod!.isHardwareType ? cwd.appending("\(poolName!).cold.hwsfile") : cwd.appending(
                "\(poolName!).cold.skey"
            )
            
            try await FileUtils.checkFile(poolCounter)
            try await FileUtils.checkFile(poolVKey)
            try await FileUtils.checkFile(poolSKey)
            
            func lockAndPrintKeys() async throws {
                try await FileUtils.fileLock(poolCounter)
                try await FileUtils.fileLock(poolVKey)
                try await FileUtils.fileLock(poolSKey)
                
                print(noora.format(
                    "\nNode Cold Verification-Key: \(.path(try .init(validating: poolVKey.string)))\n"
                ))
                try await FileUtils.displayFile(poolVKey)
                
                print(noora.format(
                    "\nNode Cold Signing-Key: \(.path(try .init(validating: poolSKey.string)))\n"
                ))
                try await FileUtils.displayFile(poolSKey)
                
                print(noora.format(
                    "\nNode Operational-Certificate-Issue-Counter: \(.path(try .init(validating: poolCounter.string)))\n"
                ))
                try await FileUtils.displayFile(poolCounter)
                
                print("\n")
            }
            
            if keyGenMethod == .cli {

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate cold keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await cli.node.keyGen(
                            verificationKeyFile: poolVKey.string,
                            signingKeyFile: poolSKey.string,
                            operationalCertificateIssueCounterFile: poolCounter.string
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate cold keys")
                        )
                        let poolKeyPair = try StakePoolKeyPair.generate()
                        try poolKeyPair.verificationKey.save(to: poolVKey.string)
                        try poolKeyPair.signingKey.save(to: poolSKey.string)
                        
                        let counter = try OperationalCertificateIssueCounter
                            .createNewCounter(coldVerificationKey: poolKeyPair.verificationKey)
                        try counter.save(to: poolCounter.string)
                }
                
                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate cold keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let skeyJSON = try await cli.node.keyGen(
                            verificationKeyFile: poolVKey.string,
                            signingKeyFile: "/dev/stdout",
                            operationalCertificateIssueCounterFile: poolCounter.string
                        )
                        
                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate cold keys")
                        )
                        
                        let poolKeyPair = try StakePoolKeyPair.generate()
                        try poolKeyPair.verificationKey.save(to: poolVKey.string)
                        
                        let counter = try OperationalCertificateIssueCounter
                            .createNewCounter(coldVerificationKey: poolKeyPair.verificationKey)
                        try counter.save(to: poolCounter.string)
                        
                        skey = try TextEnvelope.load(
                            from: try poolKeyPair.signingKey.toTextEnvelope()!
                        )
                }
                
                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the Cold-SKEY (empty to abort)"))",
                    cleanup: [poolVKey, poolSKey, poolCounter]
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
                
                try skey.save(to: poolSKey.string)
                
                try await lockAndPrintKeys()
                
            }
            else if keyGenMethod == .hw  {
                let hwcli = try await CardanoHWCLI(
                    configuration: config.toSwiftCardanoUtilsConfig()
                )
                
                let hwType = try await hwcli.startHardwareWallet()
                
                
                let skipPrompt = Environment.getBool(Environment.skipPrompt)
                
                if !skipPrompt && coldKeyIndex != 0 {
                    
                    let response = noora.yesOrNoChoicePrompt(
                        title: "Confirm ColdKeyIndex",
                        question: "ColdKeyIndex is not default(0), continue?",
                        defaultAnswer: false,
                        description: "Default is 0, confirm to continue with \(String(describing: coldKeyIndex))."
                    )
                    if !response {
                        noora.warning(.alert(
                            "Aborting",
                            takeaway: "User chose to abort due to non-default ColdKeyIndex."
                        ))
                        throw ExitCode.validationFailure
                    }
                }
                
                let path = "1853H/1815H/0H/\(coldKeyIndex!)H"
                
                noora.info(.alert(
                    "Generating keys using \(hwType.rawValue)",
                    takeaways: [
                        "Please keep your hardware wallet connected.",
                        "Using ColdKeyIndex: \(String(describing: coldKeyIndex!))",
                        "Derivation-Path: \(path)",
                    ]
                ))
                
                let _ = try await hwcli.node.keyGen(
                    path: path,
                    hwSigningFile: poolSKey,
                    coldVerificationKeyFile: poolVKey,
                    operationalCertificateIssueCounterFile: poolCounter
                )
                
                try await lockAndPrintKeys()
            }
            else {
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli, enc, hw.",
                            "Re-run the command with the --help flag for more information."
                        ]
                    )
                )
                throw ExitCode.failure
            }
                
        }
    }
}
