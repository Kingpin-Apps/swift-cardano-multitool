import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftKES

extension GenerateMainCommand {
    
    struct NodeOperationalCertificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generate the node operational certificate."
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The node opcert will be saved as <poolName>.node-XXX.opcert.")
        var poolName: String? = nil
        
        @Option(name: .shortAndLong, help: "Use this counter to generate a different node opcert for the same pool. The node operational certificate counter will be saved as <poolName>.node-<counter>.opcert.")
        var useOpCertCounter: Int? = nil
        
        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to generate the node cold keys.")
        var tool: Tool? = nil
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            poolName = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the name of the pool:",
                description: "The corresponding opcert files will be generated in the current working directory.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let inputCounter = noora.yesOrNoChoicePrompt(
                title: "Input OpCert Counter",
                question: "Do you want to specify the node operational certificate counter? If not, the node.counter file will be used.",
                defaultAnswer: false,
            )
            
            if inputCounter {
                useOpCertCounter = Int(noora.textPrompt(
                    title: "Node Operational Certificate Counter",
                    prompt: "Enter the node operational certificate counter:",
                    description: "The node operational certificate counter is used to generate a different node operational certificate for the same pool. If not specified, the node.counter file will be used.",
                    collapseOnAnswer: true,
                    validationRules: [
                        NonEmptyValidationRule(error: "Counter value cannot be empty."),
                        IntegerValidationRule(error: "Counter must be a non-negative integer.")
                    ]
                ))
            }
            
            tool = try await getToolToUse()
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            try await printToolInfo(config: config, tool: tool!)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let poolVKey = cwd.appending("\(poolName!).cold.vkey")
            do {
                try FileUtils.checkFileExists(poolVKey)
            } catch SwiftCardanoMultitoolError.fileNotFound {
                noora.error(.alert(
                    "Pool verification key file not found at expected location: \(poolVKey.string)",
                    takeaways: [
                        "Generate the pool verification key file using the \(.command("scm generate node-cold-keys")) command.",
                        "Make sure the pool verification key file exists and is named correctly.",
                        "The pool verification key file should be named <poolName>.cold.vkey and located in the current working directory."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            var poolSKey: FilePath
            var nodeCounter: FilePath
            var kesExpireJson: FilePath
            var opcert: FilePath
            
            do {
                poolSKey = cwd.appending("\(poolName!).cold.skey")
                try FileUtils.checkFileExists(poolSKey)
            } catch SwiftCardanoMultitoolError.fileNotFound {
                poolSKey = cwd.appending("\(poolName!).cold.hwsfile")
                try FileUtils.checkFileExists(poolSKey)
            } catch {
                noora.error(.alert(
                    "Pool signing key file not found at expected locations: \(cwd.appending("\(poolName!).cold.skey").string) or \(cwd.appending("\(poolName!).cold.hwsfile").string)",
                    takeaways: [
                        "Generate the pool signing key file using the `generate node-keys` command.",
                        "Make sure the pool signing key file exists and is named correctly.",
                        "The pool signing key file should be named <poolName>.cold.skey or <poolName>.cold.hwsfile and located in the current working directory."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            let kesCounterFile = cwd.appending("\(poolName!).kes.counter")
            let kesCounterNextFile = cwd.appending("\(poolName!).kes.counter-next")
            
            let latestKESNumber: String
            var nextKESNumber: String
            
            do {
                try FileUtils.checkFileExists(kesCounterFile)
                try FileUtils.checkFileExists(kesCounterNextFile)
            } catch SwiftCardanoMultitoolError.fileNotFound {
                noora.error(.alert(
                    "KES Counter file not found at expected locations: \(cwd.appending("\(poolName!).kes.counter").string) or \(cwd.appending("\(poolName!).kes.counter-next").string)",
                    takeaways: [
                        "Generate the KES counter file using the `generate kes-keys` command.",
                        "Make sure the KES counter file exists and is named correctly.",
                        "The KES counter file should be named <poolName>.kes.counter or <poolName>.kes.counter-next and located in the current working directory."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            let latestCounterValue = try FileUtils.loadFile(FilePath(kesCounterFile.string))
            let nextCounterValue = try FileUtils.loadFile(FilePath(kesCounterNextFile.string))
            
            if let latestNumber = Int(latestCounterValue.trimmingCharacters(in: .whitespacesAndNewlines)),
               let nextNumber = Int(nextCounterValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                latestKESNumber = String(format: "%03d", latestNumber)
                nextKESNumber = String(format: "%03d", nextNumber)
            } else {
                noora.error(
                    .alert(
                        "Invalid counter value in \(kesCounterFile.string) or \(kesCounterFile.string). Expected an integer.",
                        takeaways: [
                            "Check the file manually or regenerate the keys.",
                            "Use the 'generate-node-vrf-keys' command to regenerate them."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
            
            guard nextKESNumber == latestKESNumber else {
                noora.error(
                    .alert(
                        "\(.primary("\(kesCounterFile.string)")) and \(.primary("\(kesCounterNextFile.string)")) are not identical.",
                        takeaways: [
                            "Please generate new KES Keys first using \(.command("scm generate node-kes-keys"))."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
            
            let kesVkeyFile = cwd.appending("\(poolName!).kes-\(latestKESNumber).vkey")
            
            do {
                try FileUtils.checkFileExists(kesVkeyFile)
            } catch SwiftCardanoMultitoolError.fileNotFound {
                noora.error(.alert(
                    "KES Verification Key file not found at expected locations: \(cwd.appending("\(poolName!).kes-\(latestKESNumber).vkey").string)",
                    takeaways: [
                        "Generate the KES counter file using the `generate kes-keys` command.",
                        "Make sure the KES counter file exists and is named correctly.",
                        "The KES vkey file should be named <poolName>.kes-\(latestKESNumber).vkey and located in the current working directory."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            nodeCounter = cwd.appending("\(poolName!).cold.counter")
            
            func createNewOpCertCounter(newCounter: Int) async throws {
                switch tool {
                    case .cardanoCLI:
                        let cli = try await CardanoCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await cli.node.newCounter(
                                coldVerificationKeyFile: poolVKey.string,
                                counterValue: newCounter,
                                operationalCertificateIssueCounterFile: nodeCounter.string
                            )
                        
                    default:
                        let counter = try OperationalCertificateIssueCounter(
                            counterValue: UInt(newCounter),
                            coldVerificationKey: StakePoolVerificationKey.load(from: poolVKey.string)
                        )
                        try counter.save(to: nodeCounter.string)
                }
                
                let newCounterValue = String(format: "%03d", newCounter)
                var newCounter = try await FileUtils.loadLockedJSONFile(nodeCounter)
                newCounter["description"] = "Next certificate issue number: \(newCounterValue)"
                try await FileUtils.dumpLockedJSONFile(nodeCounter, data: newCounter)
            }
            
            var loop = 0
            var question = "Do you want to use the given OpCertCounter"
            
            mainLoop: while true {
                if let useOpCertCounter = useOpCertCounter {
                    let confirm = noora.yesOrNoChoicePrompt(
                        title: "Confirm OpCert Counter",
                        question: "\(question) `\(String(describing: useOpCertCounter))` as the next one?",
                        defaultAnswer: true
                    )
                    
                    if confirm {
                        try await createNewOpCertCounter(newCounter: useOpCertCounter)
                        spacedPrint("The \(.primary("\(nodeCounter.string)")) file was updated with the index: \(.primary("\(useOpCertCounter)"))")
                    } else if loop == 1 {
                        noora.warning(
                            .alert("Opcert Generation aborted.")
                        )
                        throw ExitCode.validationFailure
                    }
                }
                
                do {
                    try  FileUtils.checkFileExists(nodeCounter)
                } catch SwiftCardanoMultitoolError.fileNotFound {
                    let confirm = noora.yesOrNoChoicePrompt(
                        title: "OpCert Counter Not Found",
                        question: "Do you want to create a new one?",
                        defaultAnswer: true
                    )
                    
                    if confirm {
                        try await createNewOpCertCounter(newCounter: 0)
                        noora.warning(
                            .alert("A new counter file was created at \(.path(try .init(validating: nodeCounter.string))) with index 0.",
                                   takeaway: "You can now rerun this script \(.command("scm generate node-operational-certificate")) again to generate the opcert."
                              )
                        )
                        throw ExitCode.failure
                    } else {
                        noora.warning(
                            .alert("Cannot create new OperationalCertificate (opcert) without a counter file.")
                        )
                        throw ExitCode.validationFailure
                    }
                }
                
                spacedPrint("Issue a new node operational certificate using KES-vKey \(.path(try .init(validating: kesVkeyFile.string))) and Cold-sKey \(.path(try .init(validating: poolSKey.string)))")
                
                let cardanoConfig = try getCardanoConfig(config: config)
                
                guard let cardanoConfig = cardanoConfig.config else {
                    noora.error(.alert(
                        "Cardano configuration file path not found in multitool config.",
                        takeaways: [
                            "Make sure the cardano configuration file path is set in the multitool config.",
                            "You can set it using the `config select` command."
                        ]
                    ))
                    throw ExitCode.validationFailure
                }
                
                let kesExpire = try KESUtils.getKESExpireInfo(
                    genesisParameters: GenesisParameters(
                        nodeConfigFilePath: cardanoConfig.string
                    ),
                    kesCounterFile: kesCounterFile,
                    byronToShelleyEpochTransition: Int(config.byronToShelleyEpoch)
                )
                
                spacedPrint("Issue a new node operational certificate using KES-vKey \(.path(try .init(validating: kesVkeyFile.string))) and Cold-sKey \(.path(try .init(validating: poolSKey.string)))")
                
                kesExpireJson = cwd.appending("\(poolName!).kes-expire.json")
                try await FileUtils
                    .dumpLockedJSONFile(
                        kesExpireJson,
                        data: kesExpire.toDictionary()
                    )
                
                opcert = cwd.appending("\(poolName!).node-\(latestKESNumber).opcert")
                
                let skey = try await TextEnvelope.load(from: poolSKey)
                
                try await FileUtils.fileUnlock(opcert)
                try await FileUtils.fileUnlock(nodeCounter)
                
                if skey.keyGenType == .cli || skey.keyGenType == .enc {
                    
                    spacedPrint("Generating a new opcert from a cli signing key \(.path(try .init(validating: poolSKey.string)))")
                    
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempFile = tempDirectory.appendingPathComponent(UUID().uuidString + ".skey")
                    
                    defer { try? FileManager.default.removeItem(at: tempFile) }
                    
                    try skey.save(to: tempFile.absoluteString)
                    
                    switch tool {
                        case .cardanoCLI:
                            let cli = try await CardanoCLI(
                                configuration: config.toSwiftCardanoUtilsConfig()
                            )
                            
                            let _ = try await cli.node.issueOpCert(
                                kesVerificationKeyFile: kesVkeyFile.string,
                                coldSigningKeyFile: tempFile.absoluteString,
                                operationalCertificateIssueCounterFile: nodeCounter.string,
                                kesPeriod: kesExpire.currentKESPeriod,
                                outFile: opcert.string
                            )
                            
                        default:
                            var issueCounter = try OperationalCertificateIssueCounter.load(from: nodeCounter.string)
                            let operationalCertificate = try OperationalCertificate.issue(
                                kesVerificationKey: KESVerificationKey.load(from: kesVkeyFile.string),
                                coldSigningKey: StakePoolSigningKey.load(from: tempFile.absoluteString),
                                operationalCertificateIssueCounter: &issueCounter,
                                kesPeriod: UInt64(kesExpire.currentKESPeriod)
                            )
                            
                            try operationalCertificate.save(to: opcert.string)
                    }
                    
                }
                else if skey.keyGenType == .hw {
                    let confirm = noora.yesOrNoChoicePrompt(
                        title: "Confirm Hardware Wallet Key",
                        question: "Generating the new opcert from a local Hardware-Wallet keyfile \(.path(try .init(validating: poolSKey.string))), continue?",
                        defaultAnswer: true,
                    )
                    
                    if confirm {
                        
                        let hwcli = try await CardanoHWCLI(
                            configuration: config.toSwiftCardanoUtilsConfig()
                        )
                        
                        _ = try await hwcli.startHardwareWallet()
                        
                        let _ = try await hwcli.node.issueOpCert(
                            kesVerificationKeyFile: kesVkeyFile,
                            kesPeriod: UInt64(kesExpire.currentKESPeriod),
                            operationalCertificateIssueCounterFile: nodeCounter,
                            hwSigningFile: poolSKey,
                            outFile: opcert
                        )
                        spacedPrint("\(.primary("DONE"))")
                    } else {
                        noora.warning(
                            .alert(
                                "ABORT - Opcert Generation aborted..."
                            )
                        )
                        throw ExitCode.failure
                        
                    }
                }
                else {
                    noora.error(
                        .alert(
                            "Unsupported key generation method."
                        )
                    )
                    throw ExitCode.failure
                }
                
                try await FileUtils.fileUnlock(opcert)
                try await FileUtils.fileUnlock(nodeCounter)
                
                spacedPrint("\(.primary("Ok"))")
                
                switch config.mode {
                    case .auto, .lite, .online:
                        // check the opcert file against the current chain status to use the right OpCertCounter value
                        
                        spacedPrint(
                            "Checking operational certificate \(.primary("\(opcert.string)")) for the right OpCertCounter ... "
                        )
                        
                        let result = try await OpCertUtils.checkLocalOpCert(
                            config: config,
                            opCertFile: opcert,
                            which: .next
                        )
                        
                        if result.isValid {
                            break mainLoop
                        } else {
                            try await FileUtils.fileLock(opcert)
                            unlink(opcert.string)
                            
                            loop = 1
                            useOpCertCounter = result.nextChainOpCertCount
                            question = "Do you want to use the correct OpCertCounter"
                        }
                    default:
                        break mainLoop
                }
            }
            
            formatPrint("Node operational certificate: \(.primary("\(opcert.string)"))")
            try await FileUtils.displayJSONFile(opcert)
            
            formatPrint("Updated Operational Certificate Issue Counter: \(.primary("\(nodeCounter.string)"))")
            try await FileUtils.displayFile(nodeCounter)
            
            formatPrint("Updated Expire date json: \(.primary("\(kesExpireJson.string)"))")
            try await FileUtils.displayFile(kesExpireJson)
            
            nextKESNumber = String(format: "%03d", Int(nextKESNumber)! + 1)
            try await FileUtils.dumpLockedFile(kesCounterNextFile, data: nextKESNumber)
            
            formatPrint("Updated KES-Next-Counter: \(.primary("\(kesCounterNextFile.string)"))")
            try await FileUtils.displayFile(kesCounterNextFile)
            
            let kesSKey = cwd.appending(
                "\(poolName!).kes-\(latestKESNumber).skey"
            )
            spacedPrint("New \(.primary("\(opcert.string)")) and \(.primary("\(kesSKey.string)")) files ready for upload to the server.")
            
            if config.mode == .offline {
                noora.warning(
                    .alert(
                        "This was generated in Offline-Mode, please verify the new OpCertCounter on an Online-Machine.",
                        takeaway: "Verify using \(.command("scm query kes-period-info \(opcert.string) -w next"))."
                    )
                )
            }
        }
    }
}
