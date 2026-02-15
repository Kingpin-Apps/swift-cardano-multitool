import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftKES


extension GenerateMainCommand {
    
    struct NodeKESKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node KES keys."
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The node KES keys will be saved as <name>.kes-XXX.vkey and <name>.kes-XXX.skey.")
        var poolName: String? = nil
        
        @Option(name: .shortAndLong, help: "The method to use for key generation. Options are: cli or enc")
        var keyGenMethod: KeyGenMethod? = nil
        
        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the node cold keys.")
        var tool: Tool? = nil
        
        mutating func validate() throws {
            switch keyGenMethod {
                case .hw, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc, .hwMulti:
                    throw ValidationError("Unsupported key generation method. Please choose from: cli or enc.")
                default:
                    break
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
                        [.cli, .enc].contains($0)
                    },
                description: "Choose the method to generate the node KES keys. Options are:\n- cli: Use cardano-cli or SwiftCardano to generate the keys.\n- enc: Generate unencrypted keys and encrypt the signing key with a password."
            )
            
            tool = try await getToolToUse()
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let kesCounterFile = cwd.appending("\(poolName!).kes.counter")
            let kesCounterNextFile = cwd.appending("\(poolName!).kes.counter-next")
            
            let currentKESnumber: String
            var nextKESnumber: String
            
            // Read the current kes.counter file if it exists
            do {
                try FileUtils.checkFileExists(kesCounterFile)
                let kesCounterValue = try FileUtils.loadFile(FilePath(kesCounterFile.string))
                if let number = Int(kesCounterValue) {
                    currentKESnumber = String(format: "%03d", number)  // "001"
                } else {
                    noora.error(
                        .alert(
                            "Invalid counter value in \(kesCounterFile.string). Expected an integer.",
                            takeaways: [
                                "Check the file manually or regenerate the keys.",
                                "Use the 'generate-node-vrf-keys' command to regenerate them."
                            ]
                        )
                    )
                    throw ExitCode.validationFailure
                }
            } catch SwiftCardanoMultitoolError.fileNotFound {
                currentKESnumber = ""
            }
            
            // Get the next issue number from the kes.counter-next file
            // if it does not exist yet,
            // check if there is an existing kes.counter file (upgrade path) and use that as a base for the new one
            do {
                try FileUtils.checkFileNotExists(kesCounterNextFile)
                
                if currentKESnumber != "" {
                    nextKESnumber = String(format: "%03d", Int(currentKESnumber)! + 1)
                } else {
                    nextKESnumber = "000"
                }
                
                spacedPrint("KES Counter Next file not found. Creating new counter file at: \(.path(try .init(validating: kesCounterNextFile.string))) with : \(nextKESnumber)")
                
                try FileUtils
                    .dumpFile(kesCounterNextFile, data: nextKESnumber)
                try await FileUtils.fileLock(kesCounterNextFile)
            } catch SwiftCardanoMultitoolError.fileAlreadyExists {
                nextKESnumber = try! FileUtils.loadFile(FilePath(kesCounterNextFile.string))
                
                spacedPrint("KES Counter Next loaded from file at: \(.path(try .init(validating: kesCounterNextFile.string)))")
            }
            
            spacedPrint("Current KES number: \(currentKESnumber)")
            spacedPrint("Next KES number: \(nextKESnumber)")
            
            // check if the current one is already at the same counter as the next-counter,
            // if so, don't generate new kes keys. will need an opcert generation in between to increment further
            if Int(nextKESnumber) == Int(currentKESnumber){
                spacedPrint("Current KES number is the same as the next KES number. No new keys will be generated. Please generate an opcert to increment the counter before generating new keys.")
                noora.warning(
                    .alert(
                        "Current KES number is the same as the next KES number. No new keys will be generated.",
                        takeaway: "Please generate a new opcert to increment the counter before generating new keys."
                    )
                )
                throw ExitCode.validationFailure
            }
            
            let kesVKey = cwd.appending("\(poolName!).kes-\(nextKESnumber).vkey")
            let kesSKey =  cwd.appending("\(poolName!).kes-\(nextKESnumber).skey")
            
            try await FileUtils.checkFile(kesVKey)
            try await FileUtils.checkFile(kesSKey)
            
            func lockAndPrintKeys() async throws {
                try await FileUtils.fileLock(kesVKey)
                try await FileUtils.fileLock(kesSKey)
                
                spacedPrint(
                    "Node operational KES-Verification-Key: \(.path(try .init(validating: kesVKey.string)))"
                )
                try await FileUtils.displayFile(kesVKey)
                
                spacedPrint(
                    "Node operational KES-Verification-Key: \(.path(try .init(validating: kesSKey.string)))"
                )
                try await FileUtils.displayFile(kesSKey)
            }
            
            if keyGenMethod == .cli {
                
                switch tool {
                        
                    case .cardanoCLI:
                        spacedPrint(
                            "Using \(.primary("cardano-cli")) to generate KES keys"
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await cli.node.keyGenKES(
                            verificationKeyFile: kesVKey.string,
                            signingKeyFile: kesSKey.string
                        )
                        
                    default:
                        spacedPrint(
                            "Using \(.primary("SwiftCardano")) to generate KES keys"
                        )
                        let kesKeyPair = try KESKeyPair.generate()
                        try kesKeyPair.verificationKey.save(to: kesVKey.string)
                        try kesKeyPair.signingKey.save(to: kesSKey.string)
                        
                }
                
                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope
                
                switch tool {
                        
                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate KES keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let skeyJSON = try await cli.node.keyGenKES(
                            verificationKeyFile: kesVKey.string,
                            signingKeyFile: "/dev/stdout"
                        )
                        
                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )
                        
                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate KES keys")
                        )
                        
                        let kesKeyPair = try KESKeyPair.generate()
                        try kesKeyPair.verificationKey.save(to: kesVKey.string)
                        
                        skey = try TextEnvelope.load(
                            from: try kesKeyPair.signingKey.toTextEnvelope()!
                        )
                }
                
                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the KES-SKEY (empty to abort)"))",
                    cleanup: [kesVKey, kesSKey]
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
                
                try skey.save(to: kesSKey.string)
                
                try await lockAndPrintKeys()
            }
            else {
                noora.error(
                    .alert(
                        "Unsupported key generation method.",
                        takeaways: [
                            "Please choose from: cli or enc.",
                            "Re-run the command with the --help flag for more information."
                        ]
                    )
                )
                throw ExitCode.failure
            }
            
            try await FileUtils.dumpLockedFile(kesCounterFile, data: nextKESnumber)
            
            spacedPrint(
                "Updated KES-Counter: \(.path(try .init(validating: kesCounterFile.string)))"
            )
            try await FileUtils.displayFile(kesCounterFile)
        }
        
    }
}
