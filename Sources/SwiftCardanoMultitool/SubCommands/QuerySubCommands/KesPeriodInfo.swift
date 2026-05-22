import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct KesPeriodInfo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query KES period.")
        
        @Option(name: .shortAndLong, help: "The name of the pool. Searches for the latest <poolName>.node-XXX.opcert.")
        var poolName: String? = nil
        
        @Option(name: [.customShort("j"), .long], help: "The path to the pool.json file.")
        var poolJSON: FilePath? = nil
        
        @Option(name: [.customShort("o"), .long], help: "The pool operator (PoolOperator) to delegate to. Supports: bech32 (pool1...), hex hash, .node.vkey file.")
        var poolOperator: PoolOperator? = nil
        
        @Option(name: .long, help: "The path to the OpCert file.")
        var opCert: FilePath? = nil
        
        @Option(name: [.short, .long], help: "Which KES period to query. If not specified, queries the current KES period.")
        var whichPeriod: WhichPeriod? = nil
        
        enum SelectOption: String, CaseIterable, AlignedChoiceDescribable {
            case poolName
            case poolJSON
            case poolOperator
            case opCert

            var name: String {
                switch self {
                    case .poolName: return "Pool Name"
                    case .poolJSON: return "Pool JSON"
                    case .poolOperator: return "Pool Operator"
                    case .opCert: return "Op Cert"
                }
            }

            var details: String {
                switch self {
                    case .poolName: return "Use the pool name to find the latest opcert file in the current directory."
                    case .poolJSON: return "Use the pool.json file to find the latest opcert file in the current directory."
                    case .poolOperator: return "Use any available pool operator like pool id bech32 or hex hash, or node.vkey file in the current directory."
                    case .opCert: return "Provide the path to the opcert file directly."
                }
            }
        }
        
        mutating func validate() throws {
            if whichPeriod == nil {
                whichPeriod = .current
            }
        }
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let selectedOption: SelectOption = noora.singleChoicePrompt(
                    title: "Select Input Method",
                    question: "How would you like to identify the stake pool for querying KES period information?",
                    description: """
                    Please select one of the following options:
                    1. Pool Name: Provide the name of the pool to search for the latest opcert file in the current directory.
                    2. Pool JSON: Provide the path to the pool.json file to find the latest opcert file.
                    3. Pool Operator: Use any available pool operator like pool id bech32 or hex hash, or node.vkey file in the current directory.
                    4. OpCert File: Provide the path to the opcert file directly.
                    """
                )
            
            switch selectedOption {
                case .poolName:
                    poolName = noora.textPrompt(
                        title: "Pool Name",
                        prompt: "Enter the name of the pool:",
                        description: "Searches for the latest <poolName>.node-XXX.opcert.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                case .poolJSON:
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                        .filter { $0.hasSuffix(".json") }
                    
                    poolJSON = FilePath(
                        noora.singleChoicePrompt(
                            title: "Pool JSON Files",
                            question: "Select the pool.json file:",
                            options: files,
                            filterMode: .enabled
                        )
                    )
                    
                case .poolOperator:
                    poolOperator = try await getPoolOperator()
                    
                case .opCert:
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    
                    opCert = FilePath(
                        noora.singleChoicePrompt(
                            title: "OpCert Files",
                            question: "Select the OpCert file:",
                            options: files,
                            description: "Select the OpCert file from the files in the current working directory.",
                            filterMode: .enabled
                        )
                    )
                    
            }
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil && opCert == nil && poolOperator == nil {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            let context = try await getContext(config: config)
            
            try await printContextInfo(config: config, context: context)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            var opCertFile: FilePath?
            
            if poolName != nil {
                do {
                    opCertFile = cwd.appending("\(poolName!).node.opcert")
                    try FileUtils.checkFileExists(opCertFile!)
                } catch SwiftCardanoMultitoolError.fileNotFound {
                    do {
                        opCertFile = try FileUtils.searchLatestFile(
                            startswith: poolName!,
                            contains: "node",
                            endswith: "opcert"
                        )
                        
                    } catch SwiftCardanoMultitoolError.fileNotFound {
                        noora.error(.alert(
                            "No opcert file found for pool name \(poolName!).",
                            takeaways: [
                                "Make sure there is an opcert file in the current directory that starts with the pool name and contains 'node' and ends with 'opcert'.",
                                "Create one via \(.command("scm generate node-operational-certificate"))"
                            ]
                        ))
                        throw ExitCode.validationFailure
                    }
                }
                let _ = try await OpCertUtils.checkLocalOpCert(
                    config: config,
                    opCertFile: opCertFile!,
                    which: whichPeriod!
                )
            } else if poolJSON != nil {
                let pool = try Pool.load(from: poolJSON!)
                let _ = try await OpCertUtils.checkLocalOpCert(
                    config: config,
                    opCertFile: pool.opCert!,
                    which: whichPeriod!
                )
            } else if opCert != nil {
                let _ = try await OpCertUtils.checkLocalOpCert(
                    config: config,
                    opCertFile: opCert!,
                    which: whichPeriod!
                )
            } else if poolOperator != nil {
                let _ = try await OpCertUtils.checkPoolID(
                    config: config,
                    poolOperator: poolOperator!,
                )
            } else {
                noora.error(.alert(
                    "No valid input method provided.",
                    takeaways: ["Please provide a pool name or a pool id or an operational certificate file."]
                ))
                throw ExitCode.failure
            }
        }
    }
}
