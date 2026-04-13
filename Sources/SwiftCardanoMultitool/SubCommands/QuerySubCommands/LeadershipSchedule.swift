import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils
import ICalendar

extension QueryMainCommand {
    struct LeadershipSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query leadership schedule for a stake pool.",
            usage: """
            scm query leadership-schedule --pool-name mypool
            scm query leadership-schedule --pool-json mypool.pool.json --which-epoch next
            scm query leadership-schedule --pool-name mypool --export-ics
            scm query leadership-schedule --pool-name mypool --export-ics --maintenance-schedule
            """,
            discussion: """
            Get the leadership schedule for a specific stake pool. You can
            specify the pool using a pool name (searches for <name>.vrf.skey and
            <name>.pool.id-bech in the current directory), a pool.json file, or
            by providing the VRF signing key and pool operator directly.
            
            The command queries cardano-cli for the slots where your pool is
            scheduled to produce blocks. Optionally export results to an iCal
            (.ics) file and/or display the two largest maintenance windows.
            
            Note: This command requires an online cardano-cli context
            (running node) and may take several minutes to complete.
            """
        )
        
        // MARK: - Options
        
        @Option(name: .shortAndLong, help: "The pool name. Searches for <poolName>.vrf.skey and <poolName>.pool.id-bech in the current directory.")
        var poolName: String?
        
        @Option(name: [.customShort("j"), .long], help: "The path to the pool.json file.")
        var poolJSON: FilePath?
        
        @Option(name: [.customShort("o"), .long], help: "The pool operator (PoolOperator). Supports: bech32 (pool1...), hex hash, .node.vkey file.")
        var poolOperator: PoolOperator?
        
        @Option(name: [.customShort("v"), .long], help: "The path to the VRF signing key file (.vrf.skey).")
        var vrfSkey: FilePath?
        
        @Option(name: [.short, .long], help: "Which epoch to query: current or next. Defaults to current.")
        var whichEpoch: WhichPeriod?
        
        @Flag(name: [.short, .long], help: "Export the leadership schedule to an iCal (.ics) file.")
        var exportIcs: Bool = false
        
        @Flag(name: [.customShort("m"), .long], help: "Show the two largest maintenance windows (gaps between blocks).")
        var maintenanceSchedule: Bool = false
        
        @Option(name: .long, help: "Output file path for the .ics export. Defaults to 'leadership-schedule.ics'.")
        var outputFile: FilePath?
        
        // MARK: - Input Method Selection
        
        enum SelectOption: String, CaseIterable, CustomStringConvertible {
            case poolName
            case poolJSON
            case poolOperator
            case vrfSkeyAndPoolId
            
            var description: String {
                switch self {
                    case .poolName:
                        return "Use the pool name to find VRF skey and pool ID in the current directory"
                    case .poolJSON:
                        return "Use a pool.json file to find the VRF skey and pool ID"
                    case .poolOperator:
                        return "Use any available pool operator (pool id bech32, hex hash, or node.vkey file)"
                    case .vrfSkeyAndPoolId:
                        return "Provide the VRF signing key file and pool operator directly"
                }
            }
        }
        
        // MARK: - Validation
        
        mutating func validate() throws {
            if whichEpoch == nil {
                whichEpoch = .current
            }
        }
        
        // MARK: - Wizard
        
        /// Interactive wizard to gather missing parameters
        mutating func wizard() async throws {
            let selectedOption: SelectOption = noora.singleChoicePrompt(
                title: "Select Input Method",
                question: "How would you like to identify the stake pool?",
                description: """
                Please select one of the following options:
                1. Pool Name: Provide the name of the pool to search for VRF skey and pool ID files.
                2. Pool JSON: Provide the path to the pool.json file.
                3. Pool Operator: Use any available pool operator like pool id bech32 or hex hash.
                4. VRF Key + Pool ID: Provide VRF signing key file and pool operator separately.
                """
            )
            
            switch selectedOption {
                case .poolName:
                    poolName = noora.textPrompt(
                        title: "Pool Name",
                        prompt: "Enter the name of the pool:",
                        description: "Searches for <poolName>.vrf.skey and <poolName>.pool.id-bech in the current directory.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                case .poolJSON:
                    poolJSON = try await getPoolJSON()
                    
                case .poolOperator:
                    poolOperator = try await getPoolOperator()
                    
                case .vrfSkeyAndPoolId:
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    let vrfFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                        .filter { $0.hasSuffix(".vrf.skey") }
                    
                    if vrfFiles.isEmpty {
                        noora.error(.alert(
                            "No VRF signing key files found in current directory.",
                            takeaways: [
                                "Please generate VRF keys first using the 'generate vrf-keys' command.",
                                "Or provide a pool name or pool.json file instead."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    
                    let vrfFileName = noora.singleChoicePrompt(
                        title: "VRF Signing Key",
                        question: "Select the VRF signing key file:",
                        options: vrfFiles,
                        description: "Available .vrf.skey files in current directory"
                    )
                    vrfSkey = cwd.appending(vrfFileName)
                    
                    poolOperator = try await getPoolOperator()
            }
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if no input method was provided
            if poolName == nil && poolJSON == nil && poolOperator == nil && vrfSkey == nil {
                try await wizard()
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            // Ensure we have a CardanoCliChainContext
            guard let cliContext = context as? CardanoCliChainContext else {
                noora.error(.alert(
                    "Leadership schedule query requires an online cardano-cli context.",
                    takeaways: [
                        "Make sure cardano-node is running and fully synced.",
                        "Use 'config select' to set the mode to 'online' or 'auto'."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let cardanoConfig = try getCardanoConfig(config: config)
            
            // Resolve the shelley genesis file path
            guard let cardanoConfigPath = cardanoConfig.config else {
                noora.error(.alert(
                    "Cardano configuration file path not found in multitool config.",
                    takeaways: [
                        "Make sure the cardano configuration file path is set in the multitool config.",
                        "You can set it using the 'config select' command."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            let nodeConfig = try NodeConfig.load(from: cardanoConfigPath.string)
            let configDir = URL(fileURLWithPath: cardanoConfigPath.string)
                .deletingLastPathComponent().path
            let shelleyGenesisFilePath = "\(configDir)/\(nodeConfig.shelleyGenesisFile)"
            
            // Resolve VRF skey and pool ID based on input method
            let resolvedVrfSkey: FilePath
            let resolvedPoolId: String
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            if let poolName = poolName {
                // Use pool name to find files in CWD
                resolvedVrfSkey = cwd.appending("\(poolName).vrf.skey")
                
                try FileUtils.checkFileExists(resolvedVrfSkey)
                
                // Try to load pool ID from file
                let idBechFile = cwd.appending("\(poolName).pool.id-bech")
                if FileManager.default.fileExists(atPath: idBechFile.string) {
                    let content = try String(contentsOfFile: idBechFile.string, encoding: .utf8)
                    resolvedPoolId = content.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    // Fall back to loading from pool.json
                    let poolJsonFile = cwd.appending("\(poolName).pool.json")
                    let pool = try Pool.load(from: poolJsonFile)
                    
                    guard let idBech = pool.idBech else {
                        noora.error(.alert(
                            "Pool ID not found for pool name '\(poolName)'.",
                            takeaways: [
                                "Make sure the pool has a .pool.id-bech or .pool.json file in the current directory."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    resolvedPoolId = idBech
                }
                
            } else if let poolJSON = poolJSON {
                // Load from pool.json
                let pool = try Pool.load(from: poolJSON)
                
                guard let vrfSkeyPath = pool.vrfSkey else {
                    noora.error(.alert(
                        "VRF signing key path not found in pool.json.",
                        takeaways: [
                            "Make sure the pool.json file includes a 'vrf_skey' field."
                        ]
                    ))
                    throw ExitCode.failure
                }
                resolvedVrfSkey = vrfSkeyPath
                
                guard let idBech = pool.idBech else {
                    noora.error(.alert(
                        "Pool ID (bech32) not found in pool.json.",
                        takeaways: [
                            "Make sure the pool.json file includes an 'id_bech' field."
                        ]
                    ))
                    throw ExitCode.failure
                }
                resolvedPoolId = idBech
                
            } else if let vrfSkey = vrfSkey, let poolOperator = poolOperator {
                // Direct VRF skey + pool operator
                resolvedVrfSkey = vrfSkey
                resolvedPoolId = try poolOperator.id(.bech32)
                
            } else if let poolOperator = poolOperator {
                // Pool operator only — need to find VRF skey in CWD
                let vrfFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    .filter { $0.hasSuffix(".vrf.skey") }
                
                if vrfFiles.count == 1 {
                    resolvedVrfSkey = cwd.appending(vrfFiles[0])
                } else if vrfFiles.isEmpty {
                    noora.error(.alert(
                        "No VRF signing key files found in current directory.",
                        takeaways: [
                            "Provide the VRF signing key using --vrf-skey or use --pool-name / --pool-json instead."
                        ]
                    ))
                    throw ExitCode.failure
                } else {
                    let vrfFileName = noora.singleChoicePrompt(
                        title: "VRF Signing Key",
                        question: "Multiple VRF signing key files found. Select one:",
                        options: vrfFiles,
                        description: "Available .vrf.skey files in current directory"
                    )
                    resolvedVrfSkey = cwd.appending(vrfFileName)
                }
                
                resolvedPoolId = try poolOperator.id(.bech32)
                
            } else {
                noora.error(.alert(
                    "No valid input method provided.",
                    takeaways: [
                        "Please provide a pool name, pool.json file, or a VRF signing key with a pool operator."
                    ]
                ))
                throw ExitCode.failure
            }
            
            // Build CLI arguments
            let epochFlag = "--\(whichEpoch == .next ? "next" : "current")"
            let arguments: [String] = [
                "--genesis", shelleyGenesisFilePath,
                "--stake-pool-id", resolvedPoolId,
                "--vrf-signing-key-file", resolvedVrfSkey.string,
                epochFlag,
            ]
            
            spacedPrint(
                "Querying the \(.primary(whichEpoch == .next ? "next" : "current")) epoch leadership schedule for \(.primary(resolvedPoolId))..."
            )
            
            // Execute the query
            let result = try await noora.progressStep(
                message: "Querying leadership schedule via cardano-cli... This may take several minutes.",
                successMessage: "Successfully retrieved leadership schedule.",
                errorMessage: "Failed to retrieve leadership schedule.",
                showSpinner: true
            ) { _ in
                return try await cliContext.cli.query.leadershipSchedule(arguments: arguments)
            }
            
            // Parse the result
            let schedule = LeaderSlot.parse(from: result)
            
            if schedule.isEmpty {
                noora.warning(.alert(
                    "No leader slots found for this epoch.",
                    takeaway: "The pool may not be scheduled to produce any blocks in the \(whichEpoch == .next ? "next" : "current") epoch."
                ))
                return
            }
            
            // Display the leadership schedule table
            displayLeadershipSchedule(schedule)
            
            // Compute and display maintenance windows if requested
            var maintenanceWindows: [MaintenanceWindow] = []
            if maintenanceSchedule && schedule.count >= 2 {
                maintenanceWindows = computeMaintenanceWindows(from: schedule)
                displayMaintenanceWindows(maintenanceWindows)
            }
            
            // Export to iCal if requested
            if exportIcs {
                let outputPath = outputFile ?? cwd.appending("leadership-schedule.ics")
                try exportToICS(
                    schedule: schedule,
                    maintenanceWindows: maintenanceSchedule ? maintenanceWindows : [],
                    poolId: resolvedPoolId,
                    outputPath: outputPath
                )
            }
        }
        
        // MARK: - Display
        
        /// Display the leadership schedule as a table
        private func displayLeadershipSchedule(_ schedule: [LeaderSlot]) {
            spacedPrint("\n\(.primary("━━━ Leadership Schedule ━━━"))")
            spacedPrint("Total assigned slots: \(.success("\(schedule.count)"))")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let headers: [TableCellStyle] = [
                .plain("#"),
                .primary("Slot"),
                .primary("UTC Time"),
            ]
            
            var rows: [StyledTableRow] = []
            
            for (index, slot) in schedule.enumerated() {
                rows.append([
                    .plain("\(index + 1)"),
                    .primary("\(slot.slot)"),
                    .plain(dateFormatter.string(from: slot.time)),
                ])
            }
            
            noora.table(headers: headers, rows: rows)
        }
        
        // MARK: - Maintenance Windows
        
        /// A maintenance window representing a gap between two consecutive leader slots
        struct MaintenanceWindow {
            let startSlot: LeaderSlot
            let endSlot: LeaderSlot
            
            var duration: TimeInterval {
                endSlot.time.timeIntervalSince(startSlot.time)
            }
            
            /// Format duration as human-readable string
            var formattedDuration: String {
                let totalSeconds = Int(duration)
                let days = totalSeconds / 86400
                let hours = (totalSeconds % 86400) / 3600
                let minutes = (totalSeconds % 3600) / 60
                let seconds = totalSeconds % 60
                
                var parts: [String] = []
                if days > 0 { parts.append("\(days)d") }
                if hours > 0 { parts.append("\(hours)h") }
                if minutes > 0 { parts.append("\(minutes)m") }
                if seconds > 0 || parts.isEmpty { parts.append("\(seconds)s") }
                
                return parts.joined()
            }
        }
        
        /// Compute the two largest gaps between consecutive leader slots
        private func computeMaintenanceWindows(from schedule: [LeaderSlot]) -> [MaintenanceWindow] {
            guard schedule.count >= 2 else { return [] }
            
            var gaps: [MaintenanceWindow] = []
            for i in 0..<(schedule.count - 1) {
                gaps.append(MaintenanceWindow(
                    startSlot: schedule[i],
                    endSlot: schedule[i + 1]
                ))
            }
            
            // Sort by duration descending and take top 2
            let topGaps = gaps.sorted { $0.duration > $1.duration }.prefix(2)
            
            // Return sorted by start time for chronological display
            return Array(topGaps).sorted { $0.startSlot.time < $1.startSlot.time }
        }
        
        /// Display maintenance windows as a table
        private func displayMaintenanceWindows(_ windows: [MaintenanceWindow]) {
            guard !windows.isEmpty else {
                noora.warning(.alert(
                    "Not enough slots to compute maintenance windows."
                ))
                return
            }
            
            spacedPrint("\n\(.primary("━━━ Maintenance Windows (Top 2 Largest Gaps) ━━━"))")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            
            let headers: [TableCellStyle] = [
                .plain("#"),
                .primary("Start (after slot)"),
                .primary("End (before slot)"),
                .primary("Duration"),
            ]
            
            var rows: [StyledTableRow] = []
            
            for (index, window) in windows.enumerated() {
                rows.append([
                    .plain("\(index + 1)"),
                    .plain(dateFormatter.string(from: window.startSlot.time)),
                    .plain(dateFormatter.string(from: window.endSlot.time)),
                    .primary(window.formattedDuration),
                ])
            }
            
            noora.table(headers: headers, rows: rows)
        }
        
        // MARK: - iCal Export
        
        /// Export the leadership schedule (and optionally maintenance windows) to an .ics file
        private func exportToICS(
            schedule: [LeaderSlot],
            maintenanceWindows: [MaintenanceWindow],
            poolId: String,
            outputPath: FilePath
        ) throws {
            var calendar = ICalendar(productId: "-//SwiftCardanoMultitool//Leadership Schedule//EN")
            
            // Add block production events
            for slot in schedule {
                let event = EventBuilder(summary: "Block Production - Slot \(slot.slot)")
                    .starts(at: slot.time, timeZone: TimeZone(identifier: "UTC")!)
                    .duration(20) // ~20 seconds block production window
                    .description("Scheduled block production for pool \(poolId) at slot \(slot.slot).")
                    .buildEvent()
                
                calendar.addEvent(event)
            }
            
            // Add maintenance window events
            for window in maintenanceWindows {
                let event = EventBuilder(summary: "Maintenance Window (\(window.formattedDuration))")
                    .starts(at: window.startSlot.time, timeZone: TimeZone(identifier: "UTC")!)
                    .ends(at: window.endSlot.time, timeZone: TimeZone(identifier: "UTC")!)
                    .description(
                        "Maintenance window for pool \(poolId). "
                        + "No blocks scheduled between slot \(window.startSlot.slot) and slot \(window.endSlot.slot). "
                        + "Duration: \(window.formattedDuration)."
                    )
                    .buildEvent()
                
                calendar.addEvent(event)
            }
            
            let serializer = ICalendarSerializer()
            let icsString = try serializer.serialize(calendar)
            try icsString.write(
                to: URL(fileURLWithPath: outputPath.string),
                atomically: true,
                encoding: .utf8
            )
            
            spacedPrint(
                "\n\(.success("✓")) iCal file exported to \(.primary(outputPath.string))"
            )
        }
    }
}
