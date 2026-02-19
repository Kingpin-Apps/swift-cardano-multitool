import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils

extension GenerateMainCommand {
    
    struct NodeVRFKeys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node VRF keys."
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The node VRF keys will be saved as <name>.vrf.vkey and <name>.vrf.skey.")
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
                description: "Choose the method to generate the node VRF keys. Options are:\n- cli: Use cardano-cli or SwiftCardano to generate the keys.\n- enc: Generate unencrypted keys and encrypt the signing key with a password."
            )
            
            tool = try await getToolToUse()
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil && keyGenMethod == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            try await printToolInfo(config: config, tool: tool!)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let vrfVKey = cwd.appending("\(poolName!).vrf.vkey")
            let vrfSKey =  cwd.appending("\(poolName!).vrf.skey")
            
            try await FileUtils.checkFile(vrfVKey)
            try await FileUtils.checkFile(vrfSKey)
            
            func lockAndPrintKeys() async throws {
                try await FileUtils.fileLock(vrfVKey)
                try await FileUtils.fileLock(vrfSKey)
                
                print(noora.format(
                    "\nNode operational VRF-Verification-Key: \(.path(try .init(validating: vrfVKey.string)))\n"
                ))
                try await FileUtils.displayFile(vrfVKey)
                
                print(noora.format(
                    "\nNode operational VRF-Signing-Key: \(.path(try .init(validating: vrfSKey.string)))\n"
                ))
                try await FileUtils.displayFile(vrfSKey)
                
                print("\n")
            }
            
            if keyGenMethod == .cli {

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate VRF keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await cli.node.keyGenVRF(
                            verificationKeyFile: vrfVKey.string,
                            signingKeyFile: vrfSKey.string
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate VRF keys")
                        )
                        let vrfKeyPair = try VRFKeyPair.generate()
                        try vrfKeyPair.verificationKey.save(to: vrfVKey.string)
                        try vrfKeyPair.signingKey.save(to: vrfSKey.string)

                }
                
                try await lockAndPrintKeys()
            }
            else if keyGenMethod == .enc {
                var skey: TextEnvelope

                switch tool {

                    case .cardanoCLI:
                        print(noora.format(
                            "Using \(.primary("cardano-cli")) to generate VRF keys")
                        )
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        let skeyJSON = try await cli.node.keyGenVRF(
                            verificationKeyFile: vrfVKey.string,
                            signingKeyFile: "/dev/stdout"
                        )
                        
                        skey = try JSONDecoder().decode(
                            TextEnvelope.self,
                            from: skeyJSON.toData
                        )

                    default:
                        print(noora.format(
                            "Using \(.primary("SwiftCardano")) to generate VRF keys")
                        )
                        
                        let vrfKeyPair = try VRFKeyPair.generate()
                        try vrfKeyPair.verificationKey.save(to: vrfVKey.string)
                        
                        skey = try TextEnvelope.load(
                            from: try vrfKeyPair.signingKey.toTextEnvelope()!
                        )
                }
                
                let password = try await PasswordUtils.getConfirmedPassword(
                    prompt: "\(.secondary("Enter a strong Password for the VRF-SKEY (empty to abort)"))",
                    cleanup: [vrfVKey, vrfSKey]
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
                
                try skey.save(to: vrfSKey.string)
                
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
        }
    }
}
