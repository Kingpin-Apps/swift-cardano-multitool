import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GenerateMainCommand {
    struct PoolJSON: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "pool-json",
            abstract: "Create a new pool.json file with the specified pool details.",
            usage: """
            scm generate pool-json --pool-name test
            """,
            discussion: """
            This command helps you create a new pool.json file for your Cardano 
            stake pool. You can specify the pool name, and the command will 
            interactively prompt you for all necessary details such as pool 
            parameters, metadata, relay information, and key file locations. 
            The generated pool.json file will be saved as <poolName>.pool.json 
            in the current directory.
            """,
            aliases: ["pool"]
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The pool file will be saved as <poolName>.pool.json.")
        var poolName: String? = nil
        
        @Flag(name: .shortAndLong, help: "Overwrite the existing pool.json file if it exists.")
        var overwrite: Bool = false
        
        // MARK: - File Prompt Helpers
        
        /// Attempts to find a file at the default path. If found, confirms with user.
        /// If not found, offers to select from matching files in cwd, enter a path, or skip.
        private func resolveFilePath(
            defaultPath: FilePath,
            title: String,
            fileExtension: String,
            allowSkip: Bool = true
        ) -> FilePath? {
            let fm = FileManager.default
            
            let fileName = "\(poolName!).\(fileExtension)"
            let filePath = defaultPath.appending(fileName)
            
            // Check default path
            if fm.fileExists(atPath: filePath.string) {
                noora.success(.alert("Found \(title): \(filePath.lastComponent?.string ?? filePath.string)"))
                let useDefault = noora.yesOrNoChoicePrompt(
                    title: "\(title)",
                    question: "Use \(filePath.lastComponent?.string ?? filePath.string)?",
                    defaultAnswer: true
                )
                if useDefault { return filePath }
            }
            
            // Search cwd for matching files
            let cwd = FilePath(fm.currentDirectoryPath)
            let matchingFiles = (try? fm.contentsOfDirectory(atPath: cwd.string))
                .map { $0.filter { $0.hasSuffix(fileExtension) } } ?? []
            
            var options: [String] = []
            if !matchingFiles.isEmpty {
                options.append("Select from current directory")
            }
            options.append("Enter file path manually")
            if allowSkip {
                options.append("Skip (leave empty)")
            }
            
            let choice = noora.singleChoicePrompt(
                title: "\(title)",
                question: "How would you like to provide the \(title.lowercased()) file?",
                options: options,
                description: "File not found at default location: \(filePath.lastComponent?.string ?? filePath.string)"
            )
            
            if choice == "Select from current directory" {
                let selected = noora.singleChoicePrompt(
                    title: "\(title)",
                    question: "Select the \(title.lowercased()) file:",
                    options: matchingFiles,
                    description: "Available \(fileExtension) files in current directory",
                    collapseOnSelection: true,
                    filterMode: .enabled
                )
                return cwd.appending(selected)
            } else if choice == "Enter file path manually" {
                let path = noora.textPrompt(
                    title: "\(title)",
                    prompt: "Enter the file path:",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                )
                return FilePath(path)
            }
            
            return nil
        }
        
        /// Resolve a file with two possible default paths (e.g., .skey or .hwsfile)
        private func resolveFilePathWithFallback(
            primaryPath: FilePath,
            fallbackPath: FilePath,
            title: String,
            fileExtension: String,
            allowSkip: Bool = true
        ) -> FilePath? {
            let fm = FileManager.default
            
            if fm.fileExists(atPath: primaryPath.string) {
                return resolveFilePath(
                    defaultPath: primaryPath,
                    title: title,
                    fileExtension: fileExtension,
                    allowSkip: allowSkip
                )
            } else if fm.fileExists(atPath: fallbackPath.string) {
                return resolveFilePath(
                    defaultPath: fallbackPath,
                    title: title,
                    fileExtension: fileExtension.replacingOccurrences(of: ".skey", with: ".hwsfile"),
                    allowSkip: allowSkip
                )
            }
            
            return resolveFilePath(
                defaultPath: primaryPath,
                title: title,
                fileExtension: fileExtension,
                allowSkip: allowSkip
            )
        }
        
        // MARK: - Section Wizards
        
        /// Prompt for pool parameters: pledge, cost, margin
        private func promptPoolParams() -> (pledge: Int, cost: Int, margin: Double) {
            print(noora.format("\n\(.primary("── Pool Parameters ──"))\n"))

            let adaFormatter = AdaFormatter(defaultUnit: .ada)

            let pledgeStr = noora.textPrompt(
                title: "Pledge",
                prompt: "Enter the pool pledge (e.g., 100K, 1.5M ADA, 100000000000 lovelace):",
                description: "The amount you commit to hold in your owner wallet(s). Defaults to ADA; suffix with 'lovelace' or 'L' for lovelace.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pledge cannot be empty."),
                    AdaValidationRule(defaultUnit: .ada, error: "Pledge must be a non-negative ADA amount.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let pledge = Int(adaFormatter.toLovelace(pledgeStr)!)

            let costStr = noora.textPrompt(
                title: "Cost",
                prompt: "Enter the pool fixed cost per epoch (minimum 170 ADA):",
                description: "The fixed fee taken from rewards each epoch before distribution. Defaults to ADA; suffix with 'lovelace' or 'L' for lovelace.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Cost cannot be empty."),
                    AdaValidationRule(
                        defaultUnit: .ada,
                        minLovelace: 170_000_000,
                        error: "Cost must be at least 170 ADA (170000000 lovelace)."
                    )
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let cost = Int(adaFormatter.toLovelace(costStr)!)
            
            let marginStr = noora.textPrompt(
                title: "Margin",
                prompt: "Enter the pool margin as a decimal (e.g., 0.05 = 5%, 0.10 = 10%):",
                description: "The percentage of rewards taken before distribution. 0.00=0%, 1.00=100%.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Margin cannot be empty.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let margin = Double(marginStr) ?? 0.0
            
            return (pledge, cost, margin)
        }
        
        /// Prompt for pool metadata
        private func promptMetadata(poolName: String) -> (
            metaName: String, metaDescription: String, metaTicker: String,
            metaHomepage: URL?, metaUrl: URL?, extendedMetaUrl: URL?
        ) {
            print(noora.format("\n\(.primary("── Pool Metadata ──"))\n"))
            
            let metaName = noora.textPrompt(
                title: "Pool Display Name",
                prompt: "Enter the display name for your pool (max 50 chars):",
                description: "This name is shown in wallets like Daedalus and Yoroi.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool display name cannot be empty."),
                    LengthValidationRule(max: 50, error: "Pool display name must be 50 chars or less.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let metaDescription = noora.textPrompt(
                title: "Pool Description",
                prompt: "Enter a description for your pool (max 255 chars):",
                description: "This description is shown in wallets.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool description cannot be empty."),
                    LengthValidationRule(max: 255, error: "Pool description must be 255 chars or less.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let metaTicker = noora.textPrompt(
                title: "Pool Ticker",
                prompt: "Enter the pool ticker (3-5 characters):",
                description: "The short name/ticker shown in wallets (e.g., MYPOOL).",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool ticker cannot be empty."),
                    LengthValidationRule(min: 3, max: 5, error: "Pool ticker must be between 3-5 characters.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let metaHomepageStr = noora.textPrompt(
                title: "Pool Homepage",
                prompt: "Enter your pool homepage URL (e.g., https://mypool.com):",
                description: "This should be an https:// URL (max 64 chars).",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool homepage cannot be empty."),
                    LengthValidationRule(max: 64, error: "Pool homepage URL must be 64 chars or less.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let metaHomepage = URL(string: metaHomepageStr)
            
            let metaUrlStr = noora.textPrompt(
                title: "Metadata URL",
                prompt: "Enter the URL where your metadata JSON will be hosted:",
                description: "e.g., https://mypool.com/\(poolName).metadata.json (max 64 chars).",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Metadata URL cannot be empty."),
                    LengthValidationRule(max: 64, error: "Metadata URL must be 64 chars or less.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let metaUrl = URL(string: metaUrlStr)
            
            var extendedMetaUrl: URL? = nil
            let hasExtended = noora.yesOrNoChoicePrompt(
                title: "Extended Metadata",
                question: "Do you want to add an extended metadata URL?",
                defaultAnswer: false
            )
            if hasExtended {
                let extUrlStr = noora.textPrompt(
                    title: "Extended Metadata URL",
                    prompt: "Enter the extended metadata URL:",
                    collapseOnAnswer: true,
                    validationRules: [
                        NonEmptyValidationRule(error: "Extended metadata URL cannot be empty."),
                        LengthValidationRule(max: 64, error: "Extended metadata URL must be 64 chars or less.")
                    ]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                extendedMetaUrl = URL(string: extUrlStr)
            }
            
            return (metaName, metaDescription, metaTicker, metaHomepage, metaUrl, extendedMetaUrl)
        }
        
        /// Prompt for relay configuration (supports multiple relays)
        private func promptRelays() -> [PoolRelay] {
            print(noora.format("\n\(.primary("── Pool Relays ──"))\n"))
            
            var relays: [PoolRelay] = []
            var addMore = true
            
            while addMore {
                let relayType: SPORelayType = noora.singleChoicePrompt(
                    title: "Relay Type",
                    question: "Select the relay type:",
                    description: "IP for direct IP address, DNS for domain name."
                )
                
                let host = noora.textPrompt(
                    title: "Relay Host",
                    prompt: relayType == .ip
                        ? "Enter the relay IP address:"
                        : "Enter the relay DNS hostname:",
                    collapseOnAnswer: true,
                    validationRules: [
                        NonEmptyValidationRule(error: "Host cannot be empty."),
                        LengthValidationRule(max: 64, error: "Host must be 64 chars or less.")
                    ]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let portInput = noora.textPrompt(
                    title: "Relay Port",
                    prompt: "Enter the relay port (default 3001):",
                    collapseOnAnswer: true,
                    validationRules: [
                        PortOrEmptyValidationRule(error: "Port must be empty or between 1 and 65535.")
                    ]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                let port = portInput.isEmpty ? "3001" : portInput
                
                let hostType: HostType
                if relayType == .ip {
                    hostType = noora.singleChoicePrompt(
                        title: "Host Type",
                        question: "Select the host type:",
                        options: [HostType.ipv4, HostType.ipv6],
                        description: "IPv4 or IPv6 address type."
                    )
                } else {
                    hostType = noora.singleChoicePrompt(
                        title: "Host Type",
                        question: "Select the DNS host type:",
                        options: [HostType.single, HostType.multi],
                        description: "Single or multi-host DNS relay."
                    )
                }
                
                relays.append(PoolRelay(
                    type: relayType,
                    host: host,
                    port: port,
                    hostType: hostType
                ))
                
                addMore = noora.yesOrNoChoicePrompt(
                    title: "Add Another Relay",
                    question: "Do you want to add another relay?",
                    defaultAnswer: false
                )
            }
            
            return relays
        }
        
        /// Prompt for pool cold keys, VRF keys, and attempt pool ID generation
        private func promptPoolKeys(poolName: String, cwd: FilePath) -> (
            coldVkey: FilePath?, coldSkey: FilePath?, nodeCounter: FilePath?,
            vrfVkey: FilePath?, vrfSkey: FilePath?,
            idHex: String?, idBech: String?
        ) {
            print(noora.format("\n\(.primary("── Pool Keys ──"))\n"))
            
            // Cold Keys
            let coldVkey = resolveFilePath(
                defaultPath: cwd.appending("\(poolName).cold.vkey"),
                title: "Cold Verification Key",
                fileExtension: ".cold.vkey",
                allowSkip: true
            )
            
            let coldSkey = resolveFilePathWithFallback(
                primaryPath: cwd.appending("\(poolName).cold.skey"),
                fallbackPath: cwd.appending("\(poolName).cold.hwsfile"),
                title: "Cold Signing Key",
                fileExtension: ".cold.skey",
                allowSkip: true
            )
            
            let nodeCounter = resolveFilePath(
                defaultPath: cwd.appending("\(poolName).cold.counter"),
                title: "Node Counter",
                fileExtension: ".cold.counter",
                allowSkip: true
            )
            
            // VRF Keys
            print(noora.format("\n\(.primary("── VRF Keys ──"))\n"))
            
            let vrfVkey = resolveFilePath(
                defaultPath: cwd.appending("\(poolName).vrf.vkey"),
                title: "VRF Verification Key",
                fileExtension: ".vrf.vkey",
                allowSkip: true
            )
            
            let vrfSkey = resolveFilePath(
                defaultPath: cwd.appending("\(poolName).vrf.skey"),
                title: "VRF Signing Key",
                fileExtension: ".vrf.skey",
                allowSkip: true
            )
            
            // Pool IDs - attempt to generate from cold vkey
            var idHex: String? = nil
            var idBech: String? = nil
            
            let idHexFile = cwd.appending("\(poolName).pool.id")
            let idBechFile = cwd.appending("\(poolName).pool.id-bech")
            let fm = FileManager.default
            
            // Try loading existing files first
            if fm.fileExists(atPath: idBechFile.string) {
                idBech = try? String(contentsOfFile: idBechFile.string, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if fm.fileExists(atPath: idHexFile.string) {
                idHex = try? String(contentsOfFile: idHexFile.string, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // If not found, try to generate from cold vkey
            if (idHex == nil || idBech == nil), let vkeyPath = coldVkey,
               fm.fileExists(atPath: vkeyPath.string) {
                do {
                    let stakePoolVKey = try StakePoolVerificationKey.load(from: vkeyPath.string)
                    let poolKeyHash = try stakePoolVKey.poolKeyHash()
                    let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)

                    let generatedBech = try poolOperator.toBech32()
                    let generatedHex = try poolOperator.toBytes().toHex

                    idBech = idBech ?? generatedBech
                    idHex = idHex ?? generatedHex

                    // Save generated ID files
                    if !fm.fileExists(atPath: idBechFile.string) {
                        try poolOperator.save(to: idBechFile.string, format: .bech32)
                        noora.success(.alert("Generated pool ID (bech32): \(idBechFile.lastComponent?.string ?? idBechFile.string)"))
                    }
                    if !fm.fileExists(atPath: idHexFile.string) {
                        try poolOperator.save(to: idHexFile.string, format: .hex)
                        noora.success(.alert("Generated pool ID (hex): \(idHexFile.lastComponent?.string ?? idHexFile.string)"))
                    }
                } catch {
                    noora.warning(.alert(
                        "Could not generate pool IDs from cold verification key: \(error.localizedDescription)"
                    ))
                }
            }

            // Still nothing — ask the user for a pool ID in bech32 or hex.
            if idHex == nil && idBech == nil {
                if let poolOperator = promptPoolId() {
                    if let bech = try? poolOperator.toBech32() {
                        idBech = bech
                    }
                    if let hex = try? poolOperator.toBytes().toHex {
                        idHex = hex
                    }

                    // Save both files so subsequent runs pick them up automatically.
                    if !fm.fileExists(atPath: idBechFile.string) {
                        try? poolOperator.save(to: idBechFile.string, format: .bech32)
                        noora.success(.alert("Saved pool ID (bech32): \(idBechFile.lastComponent?.string ?? idBechFile.string)"))
                    }
                    if !fm.fileExists(atPath: idHexFile.string) {
                        try? poolOperator.save(to: idHexFile.string, format: .hex)
                        noora.success(.alert("Saved pool ID (hex): \(idHexFile.lastComponent?.string ?? idHexFile.string)"))
                    }
                }
            }

            if let idBech = idBech {
                spacedPrint("Pool ID (Bech32): \(.primary(idBech))")
            }
            if let idHex = idHex {
                spacedPrint("Pool ID (Hex): \(.primary(idHex))")
            }

            return (coldVkey, coldSkey, nodeCounter, vrfVkey, vrfSkey, idHex, idBech)
        }

        /// Prompt the user for a pool ID in bech32 or hex format, validating and returning a `PoolOperator`.
        /// Returns `nil` if the user skips or input cannot be parsed.
        private func promptPoolId() -> PoolOperator? {
            spacedPrint("No pool ID files found and no cold verification key available.")

            let provide = noora.yesOrNoChoicePrompt(
                title: "Pool ID",
                question: "Would you like to enter a pool ID now?",
                defaultAnswer: true,
                description: "Accepts bech32 (pool1…) or 56-character hex. Both .pool.id and .pool.id-bech files will be created."
            )
            guard provide else { return nil }

            let input = noora.textPrompt(
                title: "Pool ID",
                prompt: "Enter the pool ID (bech32 or hex):",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool ID cannot be empty."),
                    PoolIdValidationRule(error: "Pool ID must be a valid bech32 (pool1…) or 56-character hex string.")
                ]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            return parsePoolId(input)
        }

        /// Parse a pool ID string accepting either bech32 (`pool1…`) or hex (with optional `0x` prefix).
        private func parsePoolId(_ input: String) -> PoolOperator? {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("pool") {
                return try? PoolOperator(from: trimmed)
            }

            let hexCandidate = (trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X"))
                ? String(trimmed.dropFirst(2))
                : trimmed
            let data = hexCandidate.hexStringToData
            guard !data.isEmpty else { return nil }
            return try? PoolOperator(from: data)
        }
        
        /// Prompt for payment key files
        private func promptPaymentKeys(cwd: FilePath) -> (
            paymentVkey: FilePath?, paymentSkey: FilePath?, paymentAddr: String?
        ) {
            print(noora.format("\n\(.primary("── Payment Keys ──"))\n"))
            
            let paymentVkey = resolveFilePath(
                defaultPath: cwd,
                title: "Payment Verification Key",
                fileExtension: ".payment.vkey",
                allowSkip: true
            )
            
            let paymentSkey = resolveFilePath(
                defaultPath: cwd,
                title: "Payment Signing Key",
                fileExtension: ".payment.skey",
                allowSkip: true
            )
            
            // Try to find and load payment address
            var paymentAddr: String? = nil
            let fm = FileManager.default
            let addrFiles = (try? fm.contentsOfDirectory(atPath: cwd.string))
                .map { $0.filter { $0.hasSuffix(".payment.addr") } } ?? []
            
            if !addrFiles.isEmpty {
                let useAddr = noora.yesOrNoChoicePrompt(
                    title: "Payment Address",
                    question: "Payment address files found. Load a payment address?",
                    defaultAnswer: true
                )
                if useAddr {
                    let selected = noora.singleChoicePrompt(
                        title: "Payment Address",
                        question: "Select the payment address file:",
                        options: addrFiles,
                        description: "Available .payment.addr files in current directory",
                        collapseOnSelection: true,
                        filterMode: .enabled
                    )
                    paymentAddr = try? String(
                        contentsOfFile: cwd.appending(selected).string,
                        encoding: .utf8
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return (paymentVkey, paymentSkey, paymentAddr)
        }
        
        /// Prompt for stake key files
        private func promptStakeKeys(cwd: FilePath) -> (
            stakeVkey: FilePath?, stakeSkey: FilePath?, stakeAddr: String?
        ) {
            print(noora.format("\n\(.primary("── Stake Keys ──"))\n"))
            
            let stakeVkey = resolveFilePath(
                defaultPath: cwd,
                title: "Stake Verification Key",
                fileExtension: ".stake.vkey",
                allowSkip: true
            )
            
            let stakeSkey = resolveFilePath(
                defaultPath: cwd,
                title: "Stake Signing Key",
                fileExtension: ".stake.skey",
                allowSkip: true
            )
            
            // Try to find and load stake address
            var stakeAddr: String? = nil
            let fm = FileManager.default
            let addrFiles = (try? fm.contentsOfDirectory(atPath: cwd.string))
                .map { $0.filter { $0.hasSuffix(".stake.addr") } } ?? []
            
            if !addrFiles.isEmpty {
                let useAddr = noora.yesOrNoChoicePrompt(
                    title: "Stake Address",
                    question: "Stake address files found. Load a stake address?",
                    defaultAnswer: true
                )
                if useAddr {
                    let selected = noora.singleChoicePrompt(
                        title: "Stake Address",
                        question: "Select the stake address file:",
                        options: addrFiles,
                        description: "Available .stake.addr files in current directory",
                        collapseOnSelection: true,
                        filterMode: .enabled
                    )
                    stakeAddr = try? String(
                        contentsOfFile: cwd.appending(selected).string,
                        encoding: .utf8
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            return (stakeVkey, stakeSkey, stakeAddr)
        }
        
        /// Prompt for pool owners (at least one required)
        private func promptOwners(cwd: FilePath) -> [PoolOwner] {
            print(noora.format("\n\(.primary("── Pool Owners ──"))\n"))
            
            var owners: [PoolOwner] = []
            var addMore = true
            
            while addMore {
                let ownerName = noora.textPrompt(
                    title: "Owner Name",
                    prompt: "Enter the owner name (used to locate stake key files like <name>.stake.vkey):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Owner name cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let witness: WitnessType = noora.singleChoicePrompt(
                    title: "Witness Type",
                    question: "Select the witness type for this owner:",
                    description: "Local: signing key is available locally. External: signing will be done externally."
                )
                
                // Check for default stake key files based on owner name
                let defaultStakeVkey = cwd.appending("\(ownerName).stake.vkey")
                let defaultStakeSkey = cwd.appending("\(ownerName).stake.skey")
                let fm = FileManager.default
                
                var stakeVkey: FilePath? = nil
                var stakeSkey: FilePath? = nil
                
                if fm.fileExists(atPath: defaultStakeVkey.string) {
                    stakeVkey = defaultStakeVkey
                    noora.success(.alert("Found owner stake vkey: \(defaultStakeVkey.lastComponent?.string ?? "")"))
                } else {
                    stakeVkey = resolveFilePath(
                        defaultPath: defaultStakeVkey,
                        title: "Owner \(ownerName) Stake VKey",
                        fileExtension: ".stake.vkey",
                        allowSkip: true
                    )
                }
                
                if fm.fileExists(atPath: defaultStakeSkey.string) {
                    stakeSkey = defaultStakeSkey
                    noora.success(.alert("Found owner stake skey: \(defaultStakeSkey.lastComponent?.string ?? "")"))
                } else if witness == .local {
                    stakeSkey = resolveFilePath(
                        defaultPath: defaultStakeSkey,
                        title: "Owner \(ownerName) Stake SKey",
                        fileExtension: ".stake.skey",
                        allowSkip: true
                    )
                }
                
                owners.append(PoolOwner(
                    name: ownerName,
                    witness: witness,
                    stakeVkey: stakeVkey,
                    stakeSkey: stakeSkey
                ))
                
                addMore = noora.yesOrNoChoicePrompt(
                    title: "Add Another Owner",
                    question: "Do you want to add another pool owner?",
                    defaultAnswer: false
                )
            }
            
            return owners
        }
        
        /// Prompt for rewards owner
        private func promptRewardsOwner(cwd: FilePath) -> RewardsOwner {
            print(noora.format("\n\(.primary("── Rewards Owner ──"))\n"))
            
            let rewardsName = noora.textPrompt(
                title: "Rewards Owner Name",
                prompt: "Enter the rewards owner name (can be the same as the pool owner):",
                description: "Used to locate stake key files like <name>.stake.vkey for rewards destination.",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Rewards owner name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let fm = FileManager.default
            let defaultStakeVkey = cwd.appending("\(rewardsName).stake.vkey")
            let defaultStakeSkey = cwd.appending("\(rewardsName).stake.skey")
            
            var stakeVkey: FilePath? = nil
            var stakeSkey: FilePath? = nil
            
            if fm.fileExists(atPath: defaultStakeVkey.string) {
                stakeVkey = defaultStakeVkey
                noora.success(.alert("Found rewards stake vkey: \(defaultStakeVkey.lastComponent?.string ?? "")"))
            } else {
                stakeVkey = resolveFilePath(
                    defaultPath: defaultStakeVkey,
                    title: "Rewards Owner Stake VKey",
                    fileExtension: ".stake.vkey",
                    allowSkip: true
                )
            }
            
            if fm.fileExists(atPath: defaultStakeSkey.string) {
                stakeSkey = defaultStakeSkey
                noora.success(.alert("Found rewards stake skey: \(defaultStakeSkey.lastComponent?.string ?? "")"))
            } else {
                stakeSkey = resolveFilePath(
                    defaultPath: defaultStakeSkey,
                    title: "Rewards Owner Stake SKey",
                    fileExtension: ".stake.skey",
                    allowSkip: true
                )
            }
            
            return RewardsOwner(
                name: rewardsName,
                stakeVkey: stakeVkey,
                stakeSkey: stakeSkey
            )
        }
        
        // MARK: - Wizard & Run
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            poolName = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the name of the pool:",
                description: "This name is used for file naming (e.g., <poolName>.pool.json, <poolName>.cold.vkey, etc.).",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil {
                try await self.wizard()
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let poolFile = cwd.appending("\(poolName!).pool.json")
            
            if !overwrite && FileManager.default.fileExists(atPath: poolFile.string) {
                noora.warning(.alert(
                    "Pool.json file already exists at location: \(poolFile.lastComponent?.string ?? poolFile.string)"
                ))
                let shouldOverwrite = noora.yesOrNoChoicePrompt(
                    title: "Overwrite",
                    question: "Do you want to overwrite the existing pool.json file?",
                    defaultAnswer: false,
                    description: "This will replace the existing file with a new one."
                )
                if shouldOverwrite {
                    overwrite = true
                } else {
                    noora.error(.alert(
                        "Aborted. The existing pool.json file was not overwritten.",
                        takeaways: [
                            "Delete or move the existing file if you want to create a new one with the same name.",
                            "Use the --overwrite flag to automatically overwrite the existing file."
                        ]
                    ))
                    throw ExitCode.validationFailure
                }
            }
            
            // 1. Pool Parameters
            let params = promptPoolParams()
            
            // 2. Metadata
            let meta = promptMetadata(poolName: poolName!)
            
            // 3. Relays
            let relays = promptRelays()
            
            // 4 & 5. Pool Keys (Cold + VRF) & 6. Pool IDs
            let keys = promptPoolKeys(poolName: poolName!, cwd: cwd)
            
            // 7. Payment Keys
            let payment = promptPaymentKeys(cwd: cwd)
            
            // 8. Stake Keys
            let stake = promptStakeKeys(cwd: cwd)
            
            // 9. Owners
            let owners = promptOwners(cwd: cwd)
            
            // 10. Rewards Owner
            let rewardsOwner = promptRewardsOwner(cwd: cwd)
            
            // Build the Pool
            let pool = try Pool(
                name: poolName!,
                owners: owners,
                pledge: params.pledge,
                cost: params.cost,
                margin: params.margin,
                relays: relays,
                metaName: meta.metaName,
                metaDescription: meta.metaDescription,
                metaTicker: meta.metaTicker,
                metaHomepage: meta.metaHomepage,
                metaUrl: meta.metaUrl,
                extendedMetaUrl: meta.extendedMetaUrl,
                idHex: keys.idHex,
                idBech: keys.idBech,
                coldVkey: keys.coldVkey,
                coldSkey: keys.coldSkey,
                nodeCounter: keys.nodeCounter,
                vrfSkey: keys.vrfSkey,
                vrfVkey: keys.vrfVkey,
                rewardsOwner: rewardsOwner,
                paymentAddr: payment.paymentAddr,
                paymentSkey: payment.paymentSkey,
                paymentVkey: payment.paymentVkey,
                stakeAddr: stake.stakeAddr,
                stakeSkey: stake.stakeSkey,
                stakeVkey: stake.stakeVkey
            )
            
            try pool.validate()
            try pool.save(to: poolFile, overwrite: overwrite)
            
            try await FileUtils.displayJSONFile(poolFile)
            
            noora.success(.alert(
                "Pool.json file created successfully.",
                takeaways: [
                    "File location: \(poolFile.string)",
                    "You can edit the file to update details or add information that was skipped.",
                    "Fields like registration, KES keys, and opcert are managed by other commands."
                ]
            ))
        }
    }
}
