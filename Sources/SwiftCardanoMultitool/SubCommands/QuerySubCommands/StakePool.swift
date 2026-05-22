import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct StakePool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "stake-pool",
            abstract: "Query stake pool information.",
            usage: """
            scm query pool <poolId>
            """,
            discussion: """
            This command allows you to query information about a specific stake 
            pool. You can specify the pool operator using various formats, 
            including bech32 (e.g., pool1...), hex hash, or a .node.vkey file. 
            The command will return details about the specified stake pool, such
            as its metadata, performance, and delegation status.
            """,
            aliases: ["pool"]
        )
        
        @Option(name: .shortAndLong, help: "The pool name. Searches for <poolName>.vrf.skey and <poolName>.pool.id-bech in the current directory.")
        var poolName: String?
        
        @Option(name: [.customShort("o"), .long], help: "The pool operator (PoolOperator) to delegate to. Supports: bech32 (pool1...), hex hash, .node.vkey file.")
        var poolOperator: PoolOperator?
        
        @Option(name: [.customShort("j"), .long], help: "The path to the pool.json file.")
        var poolJSON: FilePath?
        
        // MARK: - Input Method Selection
        
        enum SelectOption: String, CaseIterable, AlignedChoiceDescribable {
            case poolName
            case poolJSON
            case poolOperator

            var name: String {
                switch self {
                    case .poolName: return "Pool Name"
                    case .poolJSON: return "Pool JSON"
                    case .poolOperator: return "Pool Operator"
                }
            }

            var details: String {
                switch self {
                    case .poolName: return "Use the pool name to find pool details in the current directory."
                    case .poolJSON: return "Use a pool.json file to find pool ID."
                    case .poolOperator: return "Use any available pool operator (pool id bech32, hex hash, or node.vkey file)."
                }
            }
        }
        
        // MARK: - Wizard
        
        /// Interactive wizard to gather missing parameters
        mutating func wizard() async throws {
            let selectedOption: SelectOption = noora.singleChoicePrompt(
                title: "Select Input Method",
                question: "How would you like to identify the stake pool for querying KES period information?",
                description: """
                    Please select one of the following options:
                    1. Pool Name: Provide the name of the pool to search in the current directory.
                    2. Pool JSON: Provide the path to the pool.json file.
                    3. Pool Operator: Use any available pool operator like pool id bech32 or hex hash, or node.vkey file in the current directory.
                    """
            )
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            switch selectedOption {
                    
                case .poolName:
                    poolName = noora.textPrompt(
                        title: "Pool Name",
                        prompt: "Enter the name of the pool:",
                        description: "Searches for the latest <poolName>.node-XXX.opcert.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let pool = try Pool.load(from: cwd.appending("\(poolName!).pool.json"))
                    
                    poolOperator = pool.toPoolOperator()
                    
                case .poolJSON:
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
                    
                    let pool = try Pool.load(from: poolJSON!)
                    
                    poolOperator = pool.toPoolOperator()
                    
                case .poolOperator:
                    poolOperator = try await getPoolOperator()
                    
            }
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if required parameters are missing
            if poolOperator == nil {
                try await wizard()
            }
            
            guard let poolOperator = poolOperator else {
                noora.error(.alert(
                    "Pool Operator is required.",
                    takeaways: ["Provide a valid Pool Operator identifier."]
                ))
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            let cardanoConfig = try getCardanoConfig(config: config)
            let poolIdBech32 = try poolOperator.id(.bech32)
            
            spacedPrint("Querying stake pool information for \(.primary(poolIdBech32))...")
            
            let poolInfo = try await noora.progressStep(
                message: "Fetching stake pool information via \(context.name)...",
                successMessage: "Successfully retrieved stake pool information.",
                errorMessage: "Failed to retrieve stake pool information.",
                showSpinner: true
            ) { updateMessage in
                return try await withRetry() {
                    try await context.stakePoolInfo(poolId: poolIdBech32)
                }
            }

            // Calculate margin percentage
            let marginDouble = Double(poolInfo.poolParams.margin.numerator) / Double(poolInfo.poolParams.margin.denominator)
            let marginPct = String(format: "%.2f%%", marginDouble * 100.0)

            // Pool owners (always present but may be empty)
            let owners = poolInfo.poolParams.poolOwners.asArray

            // Display pool information
            spacedPrint("\nDetailed information about the stake pool:")
            
            // Display pool information as table
            let tableColumns = [
                TableColumn(title: "", width: .auto, alignment: .right),
                TableColumn(title: "", width: .auto, alignment: .left),
            ]

            var tableRows: [[TerminalText]] = []
            
            if let ticker = poolInfo.poolParams.poolMetadata?.ticker {
                tableRows.append(["Ticker", "\(ticker)"])
            }
            if let name = poolInfo.poolParams.poolMetadata?.name {
                tableRows.append(["Name", "\(name)"])
            }
            
            tableRows.append(["Pool Operator", "\(poolInfo.poolParams.poolOperator.payload.toHex)"])
            tableRows.append(["VRF Key Hash", "\(poolInfo.poolParams.vrfKeyHash.payload.toHex)"])
            tableRows.append(["Pledge", adaAndLovelaceFormat(UInt64(poolInfo.poolParams.pledge))])
            tableRows.append(["Fixed Cost", adaAndLovelaceFormat(UInt64(poolInfo.poolParams.cost))])
            tableRows.append(["Margin", "\("\(marginDouble) (\(marginPct))")"])
            tableRows.append(["Reward Account", "\(poolInfo.poolParams.rewardAccount.payload.toHex)"])

            if !owners.isEmpty {
                tableRows.append(["Pool Owners", "\(owners.map { $0.payload.toHex }.joined(separator: ", "))"])
            }
            
            if let livePledge = poolInfo.livePledge {
                tableRows.append(["Live Pledge", adaAndLovelaceFormat(UInt64(livePledge))])
            }
            if let liveStake = poolInfo.liveStake {
                tableRows.append(["Live Stake", adaAndLovelaceFormat(UInt64(liveStake))])
            }
            if let liveSize = poolInfo.liveSize {
                tableRows.append(["Live Size", "\(liveSize)"])
            }
            if let activeStake = poolInfo.activeStake {
                tableRows.append(["Active Stake", adaAndLovelaceFormat(UInt64(activeStake))])
            }
            if let activeSize = poolInfo.activeSize {
                tableRows.append(["Active Size", "\(activeSize)"])
            }
            if let opcertCounter = poolInfo.opcertCounter {
                tableRows.append(["OpCert Counter", "\(opcertCounter)"])
            }
            
            if let desc = poolInfo.poolParams.poolMetadata?.desc {
                tableRows.append(["Description", "\(desc)"])
            }
            if let homepage = poolInfo.poolParams.poolMetadata?.homepage?.absoluteString {
                tableRows.append(["Homepage", "\(.link(title: homepage, href: homepage))"])
            }
            if let metaUrl = poolInfo.poolParams.poolMetadata?.url?.absoluteString {
                tableRows.append(["Metadata URL", "\(.link(title: metaUrl, href: metaUrl))"])
            }
            if let metaHash = poolInfo.poolParams.poolMetadata?.poolMetadataHash?.payload.toHex {
                tableRows.append(["Metadata Hash", "\(metaHash)"])
            }

            // Optional relays
            if let relays = poolInfo.poolParams.relays {
                for (index, relay) in relays.enumerated() {
                    var parts: [String] = []
                    switch relay {
                    case .singleHostAddr(let addr):
                        if let ipv4 = addr.ipv4 { parts.append("IPv4: \(ipv4)") }
                        if let ipv6 = addr.ipv6 { parts.append("IPv6: \(ipv6)") }
                        if let port = addr.port { parts.append("Port: \(port)") }
                    case .singleHostName(let host):
                        if let dnsName = host.dnsName { parts.append("DNS: \(dnsName)") }
                        if let port = host.port { parts.append("Port: \(port)") }
                    case .multiHostName(let host):
                        if let dnsName = host.dnsName { parts.append("DNS (multi): \(dnsName)") }
                    }
                    if !parts.isEmpty {
                        tableRows.append(["Relay \(index + 1)", "\(parts.joined(separator: ", "))"])
                    }
                }
            }
            
            // Display pool status
            switch poolInfo.status {
                case .registered:
                    tableRows.append(["Status", "\(.success("REGISTERED"))"])
                case .retired:
                    tableRows.append(["Status", "\(.danger("RETIRED"))"])
                case .retiring(let epoch):
                    tableRows.append(["Status", "\(.accent("RETIRE in epoch \(epoch)"))"])
                case nil:
                    tableRows.append(["Status", "\(.muted("UNKNOWN"))"])
            }

            noora.table(TableData(columns: tableColumns, rows: tableRows))
            
            // Show blockchain explorer link
            let blockchainExplorer = config.blockchainExplorer.explorer(
                network: cardanoConfig.network
            )
            
            if let poolURL = try? blockchainExplorer.viewPool(pool: poolOperator) {
                spacedPrint("\n\(.link(title: poolURL.absoluteString, href: poolURL.absoluteString))")
            }
        }
    }
}
