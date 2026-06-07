import Foundation
import SwiftCardanoCore
import SwiftCardanoChain
import ArgumentParser
import Noora
import SystemPackage

func getAddressBy(title: TerminalText? = nil) async throws -> GetAddressBy {
    return noora.singleChoicePrompt(
        title: title ?? "Payment Address",
        question: "Enter address files by:",
        description: "Do you want to enter the name of the address files or select them from the current working directory?.",
    )
}


func getTransactionBy(title: TerminalText? = nil) async throws -> GetTransactionBy {
    return noora.singleChoicePrompt(
        title: title ?? "Transaction",
        question: "Enter transaction files by:",
        description: "Do you want to enter the transaction CBOR Hex or select the file from the current working directory?.",
    )
}

func enterAddressBy(title: TerminalText? = nil) async throws -> EnterAddressBy {
    return noora.singleChoicePrompt(
        title: title ?? "Payment Address",
        question: "Enter address by:",
        description: "Do you want to enter the address or AdaHandle directly or provide a file containing the address?.",
    )
}

/// Prompt user to enter DRep by various methods.
/// - Parameter title: Optional title for the prompt.
/// - Returns: EnterDRepBy enum value.
/// - Throws: ExitCode.failure if no valid input is provided.
func enterDRepBy(title: TerminalText? = nil) async throws -> EnterDRepBy {
    return noora.singleChoicePrompt(
        title: title ?? "Enter DRep",
        question: "Enter DRep by:",
        description: """
            Accepted formats:
            \n  • Bech32: drep1... (56 chars) or drep_script1... (63 chars)
            \n  • Hex: 56-character hex string (with or without 0x prefix)
            \n  • File: path to .drep.vkey file
            \n  • Special: 'always-abstain' or 'always-no-confidence'
            \n  • Aliases: 'abstain', 'noc', 'no-confidence'
            """,
    )
}

/// Prompt user to enter Pool Operator by various methods.
/// - Parameter title: Optional title for the prompt.
/// - Returns: EnterPoolOperatorBy enum value.
/// - Throws: ExitCode.failure if no valid input is provided.
func enterPoolOperatorBy(title: TerminalText? = nil) async throws -> EnterPoolOperatorBy {
    return noora.singleChoicePrompt(
        title: title ?? "Enter Pool Operator",
        question: "Enter Pool Operator by:",
        description: """
            Accepted formats:
            \n  • Bech32: pool1... (56 chars) 
            \n  • Hex: 56-character hex string (with or without 0x prefix)
            \n  • File: path to .pool.id file
            \n  • File: path to .pool.id-bech file
            \n  • File: path to .node.vkey file
            \n  • File: path to .node.skey file
            """,
    )
}

/// Prompt user to choose how they want to identify an asset for metadata lookup.
/// - Parameter title: Optional title for the prompt.
/// - Returns: EnterAssetMetaBy enum value.
func enterAssetMetaBy(title: TerminalText? = nil) async throws -> EnterAssetMetaBy {
    return noora.singleChoicePrompt(
        title: title ?? "Asset",
        question: "Enter asset by:",
        description: """
            Accepted formats:
            \n  • Hex Subject: 56-120 hex characters (policyId || assetNameHex)
            \n  • File Path: a .asset JSON file with a top-level `subject` field
            """,
    )
}

/// Prompt user to select a stake address from the current directory.
/// - Parameter title: Optional title for the prompt.
/// - Returns: StakeAddressInfo of the selected stake address.
/// - Throws: ExitCode.failure if no stake address files are found.
func getStakeAddress(title: TerminalText? = nil) async throws -> StakeAddressInfo {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let stakingFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".stake.addr") }
    
    if stakingFiles.isEmpty {
        noora.error(.alert(
            "No stake address files found in current directory.",
            takeaways: [
                "Please create a stake address first using the 'generate payment-and-stake-address' command."
            ]
        ))
        throw ExitCode.failure
    }
    
    let stakeAddressFileName = noora.singleChoicePrompt(
        title: title ?? "Stake Address",
        question: "Select the stake address file:",
        options: stakingFiles,
        description: "Available .stake.addr files in current directory"
    )
    
    let info = try AddressInfo(
        fromFile: cwd.appending(stakeAddressFileName),
        name: stakeAddressFileName.replacingOccurrences(of: ".stake.addr", with: "")
    )
    return StakeAddressInfo(info: info)
}

/// Prompt user to select a fee payment address from the current directory or by name.
/// - Parameter title: Optional title for the prompt.
/// - Returns: PaymentAddressInfo of the selected fee payment address.
/// - Throws: ExitCode.failure if no payment address files are found.
func getDestinationAddress(title: TerminalText? = nil) async throws -> PaymentAddressInfo {
    let addressBy = try await enterAddressBy(title: title)
    
    let info: AddressInfo
    
    switch addressBy {
        case .address:
            let bech32 = noora.textPrompt(
                title: "Bech32 Address",
                prompt: "Enter the address in Bech32 format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let name = noora.textPrompt(
                title: "Address Name",
                prompt: "Enter a name for this address (for reference purposes):",
                collapseOnAnswer: true,
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let address = try Address.fromBech32(bech32)
            
            info = try AddressInfo(name: name, address: address)
        case .adahandle:
            let adaHandle = noora.textPrompt(
                title: "AdaHandle",
                prompt: "Enter the AdaHandle (e.g., 'alice.ada'):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "AdaHandle cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let name = noora.textPrompt(
                title: "Address Name",
                prompt: "Enter a name for this address (for reference purposes):",
                collapseOnAnswer: true,
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            info = try AddressInfo(name: name, adaHandle: adaHandle)
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".payment.addr") }
            
            if addressFiles.isEmpty {
                noora.error(.alert(
                    "No payment address files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate payment-and-stake-address' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let addressFileName = noora.singleChoicePrompt(
                title: "Payment Address",
                question: "Select the address file:",
                options: addressFiles,
                description: "Available .addr files in current directory"
            )
            
            info = try AddressInfo(
                fromFile: cwd.appending(addressFileName),
                name: addressFileName.replacingOccurrences(of: ".addr", with: "")
            )
    }
        
    return PaymentAddressInfo(info: info)
}

/// Prompt user to select a fee payment address from the current directory or by name.
/// - Parameter title: Optional title for the prompt.
/// - Returns: PaymentAddressInfo of the selected fee payment address.
/// - Throws: ExitCode.failure if no payment address files are found.
func getFeePaymentAddress(title: TerminalText? = nil) async throws -> PaymentAddressInfo {
    let addressBy = try await getAddressBy(title: title)
    
    let info: AddressInfo
    
    switch addressBy {
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".payment.addr") }
            
            if addressFiles.isEmpty {
                noora.error(.alert(
                    "No payment address files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate payment-and-stake-address' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let addressFileName = noora.singleChoicePrompt(
                title: "Fee Payment Address",
                question: "Select the fee payment address file:",
                options: addressFiles,
                description: "Available .payment.addr files in current directory"
            )
            
            info = try AddressInfo(
                fromFile: cwd.appending(addressFileName),
                name: addressFileName.replacingOccurrences(of: ".payment.addr", with: "")
            )
        case .name:
            let addressName = noora.textPrompt(
                title: "Fee Payment Address Name",
                prompt: "Enter the name of the fee payment address (as used during its creation):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Address name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let addressFilePath = cwd.appending("\(addressName).payment.addr")
            
            info = try AddressInfo(
                fromFile: addressFilePath,
                name: addressName
            )
    }
    
    return PaymentAddressInfo(info: info)
}

/// Prompt user to select a transaction file from the current directory.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected transaction file.
/// - Throws: ExitCode.failure if no transaction files are found.
func getTransactionFilePath(title: TerminalText? = nil) async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let transactionFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".tx") }
    
    if transactionFiles.isEmpty {
        noora.error(.alert(
            "No transaction files found in current directory.",
            takeaways: [
                "Please create a transaction first.",
                "Make sure you are in the correct directory containing the transaction file."
                
            ]
        ))
        throw ExitCode.failure
    }
    
    let transactionFileName = noora.singleChoicePrompt(
        title: title ?? "Transaction File",
        question: "Select the transaction file:",
        options: transactionFiles,
        description: "Available .tx files in current directory",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    
    return FilePath(transactionFileName)
}

/// Prompt user to select a signing key file from the current directory.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected signing key file.
/// - Throws: ExitCode.failure if no signing key files are found.
func getSigningKeyFilePath(title: TerminalText? = nil) async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let signingKeyFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".skey") || $0.hasSuffix(".hwsfile") }
    
    if signingKeyFiles.isEmpty {
        noora.error(.alert(
            "No signing key files found in current directory.",
            takeaways: [
                "Please create a signing key first.",
                "Make sure you are in the correct directory containing the signing key file."
                
            ]
        ))
        throw ExitCode.failure
    }
    
    let signingKeyFileName = noora.singleChoicePrompt(
        title: title ?? "Signing Key File",
        question: "Select the signing key file:",
        options: signingKeyFiles,
        description: "Available `.skey` and `.hwsfile` files in current directory",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    
    return FilePath(signingKeyFileName)
}

/// Prompt user to select a witness file from the current directory.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected witness file.
/// - Throws: ExitCode.failure if no witness files are found.
func getWitnessFilePath(title: TerminalText? = nil) async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let witnessFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".witness") }
    
    if witnessFiles.isEmpty {
        noora.error(.alert(
            "No witness files found in current directory.",
            takeaways: [
                "Please create a witness first.",
                "Make sure you are in the correct directory containing the witness file."
                
            ]
        ))
        throw ExitCode.failure
    }
    
    let witnessFileName = noora.singleChoicePrompt(
        title: title ?? "Witness File",
        question: "Select the witness file:",
        options: witnessFiles,
        description: "Available `.witness` files in current directory",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    
    return FilePath(witnessFileName)
}

/// Prompt user to enter DRep by various methods and return the DRep instance.
/// - Parameter title: Optional title for the prompt.
/// - Returns: DRep instance.
/// - Throws: ExitCode.failure if no valid DRep ID files are found or input is invalid.
func getDRep(title: TerminalText? = nil) async throws -> DRep {
    let enterDRepBy = try await enterDRepBy(title: title)
    
    switch enterDRepBy {
        case .alwaysAbstain:
            return DRep(credential: .alwaysAbstain)
        case .alwaysNoConfidence:
            return DRep(credential: .alwaysNoConfidence)
        case .path:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.id") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep ID files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'certificate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep ID file:",
                options: drepFiles,
                description: "Available .drep.id files in current directory"
            )
            
            return try DRep.load(from: cwd.appending(drepFileName).string)
        case .hex:
            let drepId = noora.textPrompt(
                title: "DRep ID",
                prompt: "Enter the DRep ID in hexadecimal format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "DRep ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try DRep(from: drepId.hexStringToData)
        case .bech32:
            let drepId = noora.textPrompt(
                title: "DRep ID",
                prompt: "Enter the DRep ID in Bech32 format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "DRep ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Handle friendly aliases
            let normalizedRaw: String
            switch drepId.lowercased() {
                case "abstain":
                    normalizedRaw = "drep_always_abstain"
                case "noc", "no-confidence":
                    normalizedRaw = "drep_always_no_confidence"
                default:
                    normalizedRaw = drepId
            }
            
            return try DRep(from: normalizedRaw)
        case .vkey:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.vkey") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep Verification Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep Verification Key file:",
                options: drepFiles,
                description: "Available .drep.vkey files in current directory"
            )
            let drepVKey = try DRepVerificationKey.load(from: cwd.appending(drepFileName).string)
            return DRep(credential: .verificationKeyHash(try drepVKey.hash()))
        case .skey:
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let drepFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.skey") }
            
            if drepFiles.isEmpty {
                noora.error(.alert(
                    "No DRep Verification Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate drep' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let drepFileName = noora.singleChoicePrompt(
                title: "DRep ID",
                question: "Select the DRep Signing Key file:",
                options: drepFiles,
                description: "Available .drep.skey files in current directory"
            )
            let drepSKey = try DRepSigningKey.load(
                from: cwd.appending(drepFileName).string
            )
            let drepVKey: DRepVerificationKey = try drepSKey.toVerificationKey()
            return DRep(credential: .verificationKeyHash(try drepVKey.hash()))
        case .mnemonics:
            throw SwiftCardanoMultitoolError.notImplemented("Mnemonic-based DRep entry is not yet implemented.")
    }
}

/// Prompt user to enter Pool Operator ID by various methods and return the PoolOperator instance.
/// - Parameter title: Optional title for the prompt.
/// - Returns: PoolOperator instance.
/// - Throws: ExitCode.failure if no valid Pool ID files are found or input is invalid.
func getPoolOperator(title: TerminalText? = nil) async throws -> PoolOperator {
    let enterPoolOperatorBy = try await enterPoolOperatorBy(title: title)
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    
    switch enterPoolOperatorBy {
        case .path:
            let poolOperatorFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".pool.id") || $0.hasSuffix(".pool.id-bech") }
            
            if poolOperatorFiles.isEmpty {
                noora.error(.alert(
                    "No Pool ID files found in current directory.",
                    takeaways: [
                        "Please create a pool first using the 'certificate stake-pool' command and register it.",
                        "Or, if you already have a pool ID, you can enter it directly here."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let poolOperatorFileName = noora.singleChoicePrompt(
                title: "Pool ID",
                question: "Select the Pool ID file:",
                options: poolOperatorFiles,
                description: "Available .pool.id and .pool.id-bech files in current directory"
            )
            
            return try PoolOperator.load(from: cwd.appending(poolOperatorFileName).string)
        case .hex:
            let poolId = noora.textPrompt(
                title: "Pool ID",
                prompt: "Enter the Pool ID in hexadecimal format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try PoolOperator(from: poolId.hexStringToData)
        case .bech32:
            let poolId = noora.textPrompt(
                title: "Pool ID",
                prompt: "Enter the Pool ID in Bech32 format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            
            return try PoolOperator(from: poolId)
        case .vkey:
            let poolOperatorFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".node.vkey") }
            
            if poolOperatorFiles.isEmpty {
                noora.error(.alert(
                    "No Node Verification Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate node-keys' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let poolOperatorFileName = noora.singleChoicePrompt(
                title: "Pool VKey",
                question: "Select the Node Verification Key file:",
                options: poolOperatorFiles,
                description: "Available .node.vkey files in current directory"
            )
            let poolOperatorVKey = try StakePoolVerificationKey.load(from: cwd.appending(poolOperatorFileName).string
            )
            return PoolOperator(poolKeyHash: try poolOperatorVKey.poolKeyHash())
        case .skey:
            let poolOperatorFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".node.skey") }
            
            if poolOperatorFiles.isEmpty {
                noora.error(.alert(
                    "No Node Signing Keys files found in current directory.",
                    takeaways: [
                        "Please create an address first using the 'generate  node-keys' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            let poolOperatorFileName = noora.singleChoicePrompt(
                title: "Pool SKey",
                question: "Select the Node Signing Key file:",
                options: poolOperatorFiles,
                description: "Available .node.skey files in current directory"
            )
            let poolOperatorSKey = try DRepSigningKey.load(
                from: cwd.appending(poolOperatorFileName).string
            )
            let poolOperatorVKey: StakePoolVerificationKey = try poolOperatorSKey.toVerificationKey()
            return PoolOperator(poolKeyHash: try poolOperatorVKey.poolKeyHash())
    }
}

/// Prompt user to select a pool.json file from the current directory.
/// - Returns: FilePath of the selected pool.json file.
/// - Throws: ExitCode.failure if no pool.json files are found.
func getPoolJSON() async throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".json") }
    
    return FilePath(
        noora.singleChoicePrompt(
            title: "Pool JSON Files",
            question: "Select the pool.json file:",
            options: files,
            filterMode: .enabled
        )
    )
}

/// Prompt user to enter a Committee Cold Credential.
func getCommitteeColdCredential(title: TerminalText? = nil) async throws -> CommitteeColdCredential {
    let method: EnterCommitteeColdCredentialBy = noora.singleChoicePrompt(
        title: title ?? "Committee Cold Credential",
        question: "Enter Committee Cold Credential by:",
        description: "Accepted formats: Bech32 (cc_cold1...), hex, or key file."
    )
    let cwd = FilePath(FileManager.default.currentDirectoryPath)

    switch method {
        case .bech32:
            let raw = noora.textPrompt(
                title: "CC Cold Credential",
                prompt: "Enter the Committee Cold Credential in Bech32 format (cc_cold1...):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try CommitteeColdCredential(from: raw)
        case .hex:
            let raw = noora.textPrompt(
                title: "CC Cold Credential",
                prompt: "Enter the Committee Cold key hash in hex format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try CommitteeColdCredential(from: raw.hexStringToData, as: .keyHash)
        case .vkey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".cc-cold.vkey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No Committee Cold verification key files found in current directory.",
                    takeaways: ["Ensure a .cc-cold.vkey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "CC Cold VKey",
                question: "Select the Committee Cold verification key file:",
                options: files,
                description: "Available .cc-cold.vkey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let vkey = try CommitteeColdVerificationKey.load(from: cwd.appending(fileName).string)
            return CommitteeColdCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".cc-cold.skey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No Committee Cold signing key files found in current directory.",
                    takeaways: ["Ensure a .cc-cold.skey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "CC Cold SKey",
                question: "Select the Committee Cold signing key file:",
                options: files,
                description: "Available .cc-cold.skey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let skey = try CommitteeColdSigningKey.load(from: cwd.appending(fileName).string)
            let vkey: CommitteeColdVerificationKey = try skey.toVerificationKey()
            return CommitteeColdCredential(credential: .verificationKeyHash(try vkey.hash()))
    }
}

/// Prompt user to enter a Committee Hot Credential.
func getCommitteeHotCredential(title: TerminalText? = nil) async throws -> CommitteeHotCredential {
    let method: EnterCommitteeHotCredentialBy = noora.singleChoicePrompt(
        title: title ?? "Committee Hot Credential",
        question: "Enter Committee Hot Credential by:",
        description: "Accepted formats: Bech32 (cc_hot1...), hex, or key file."
    )
    let cwd = FilePath(FileManager.default.currentDirectoryPath)

    switch method {
        case .bech32:
            let raw = noora.textPrompt(
                title: "CC Hot Credential",
                prompt: "Enter the Committee Hot Credential in Bech32 format (cc_hot1...):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try CommitteeHotCredential(from: raw)
        case .hex:
            let raw = noora.textPrompt(
                title: "CC Hot Credential",
                prompt: "Enter the Committee Hot key hash in hex format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try CommitteeHotCredential(from: raw.hexStringToData, as: .keyHash)
        case .vkey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".cc-hot.vkey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No Committee Hot verification key files found in current directory.",
                    takeaways: ["Ensure a .cc-hot.vkey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "CC Hot VKey",
                question: "Select the Committee Hot verification key file:",
                options: files,
                description: "Available .cc-hot.vkey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let vkey = try CommitteeHotVerificationKey.load(from: cwd.appending(fileName).string)
            return CommitteeHotCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".cc-hot.skey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No Committee Hot signing key files found in current directory.",
                    takeaways: ["Ensure a .cc-hot.skey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "CC Hot SKey",
                question: "Select the Committee Hot signing key file:",
                options: files,
                description: "Available .cc-hot.skey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let skey = try CommitteeHotSigningKey.load(from: cwd.appending(fileName).string)
            let vkey: CommitteeHotVerificationKey = try skey.toVerificationKey()
            return CommitteeHotCredential(credential: .verificationKeyHash(try vkey.hash()))
    }
}

/// Prompt user to enter a DRep Credential (for DRep certificate commands).
func getDRepCredential(title: TerminalText? = nil) async throws -> DRepCredential {
    let method: EnterDRepCredentialBy = noora.singleChoicePrompt(
        title: title ?? "DRep Credential",
        question: "Enter DRep Credential by:",
        description: "Accepted formats: Bech32 (drep1...), hex, or key file."
    )
    let cwd = FilePath(FileManager.default.currentDirectoryPath)

    switch method {
        case .bech32:
            let raw = noora.textPrompt(
                title: "DRep Credential",
                prompt: "Enter the DRep Credential in Bech32 format (drep1...):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try DRepCredential(from: raw)
        case .hex:
            let raw = noora.textPrompt(
                title: "DRep Credential",
                prompt: "Enter the DRep key hash in hex format:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Value cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return try DRepCredential(from: raw.hexStringToData, as: .keyHash)
        case .vkey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.vkey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No DRep verification key files found in current directory.",
                    takeaways: ["Ensure a .drep.vkey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "DRep VKey",
                question: "Select the DRep verification key file:",
                options: files,
                description: "Available .drep.vkey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let vkey = try DRepVerificationKey.load(from: cwd.appending(fileName).string)
            return DRepCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".drep.skey") }
            if files.isEmpty {
                noora.error(.alert(
                    "No DRep signing key files found in current directory.",
                    takeaways: ["Ensure a .drep.skey file exists in the current directory."]
                ))
                throw ExitCode.failure
            }
            let fileName = noora.singleChoicePrompt(
                title: "DRep SKey",
                question: "Select the DRep signing key file:",
                options: files,
                description: "Available .drep.skey files in current directory",
                collapseOnSelection: true,
                filterMode: .enabled
            )
            let skey = try DRepSigningKey.load(from: cwd.appending(fileName).string)
            let vkey: DRepVerificationKey = try skey.toVerificationKey()
            return DRepCredential(credential: .verificationKeyHash(try vkey.hash()))
    }
}

/// Prompt user to optionally provide an Anchor (metadata URL + hash).
/// - Parameter purpose: Describes the context (e.g. "DRep registration", "committee resignation").
/// - Returns: Anchor if user confirmed, nil otherwise.
func getOptionalAnchor(purpose: String = "metadata") async throws -> Anchor? {
    let include = noora.yesOrNoChoicePrompt(
        title: "Include Anchor",
        question: "Include \(purpose) anchor (URL + hash)?",
        description: "An anchor links this certificate to off-chain metadata (CIP-100)."
    )
    guard include else { return nil }

    let urlString = noora.textPrompt(
        title: "Anchor URL",
        prompt: "Enter the metadata URL (max 128 characters):",
        collapseOnAnswer: true,
        validationRules: [NonEmptyValidationRule(error: "URL cannot be empty.")]
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    let hashHex = noora.textPrompt(
        title: "Anchor Hash",
        prompt: "Enter the metadata hash (32-byte hex, 64 characters):",
        collapseOnAnswer: true,
        validationRules: [NonEmptyValidationRule(error: "Hash cannot be empty.")]
    ).trimmingCharacters(in: .whitespacesAndNewlines)

    let anchorUrl = try Url(urlString)
    let hashData = hashHex.hexStringToData
    let anchorDataHash = AnchorDataHash(payload: hashData)
    return Anchor(anchorUrl: anchorUrl, anchorDataHash: anchorDataHash)
}

/// Prompt user to select which tool to use for generating keys (cardano-cli or SwiftCardano).
/// - Returns: Tool enum value indicating the selected tool.
func getToolToUse() async throws -> Tool {
    if Environment.getBool(Environment.useCardanoCLI) {
        return .cardanoCLI
    }
    else if Environment.getBool(Environment.useSwiftCardano) {
        return .swiftCardano
    } else {
        return noora.singleChoicePrompt(
            title: "Which Tool",
            question: "Use cardano-cli or SwiftCardano?",
            options: Tool.allCases,
            description: """
                Options are:
                \n- • swiftCardano: Use the SwiftCardano package.
                \n- • cardanoCLI: Use the cardano-cli.
                """
        )
    }
}

func enterVoterBy(title: TerminalText? = nil) async throws -> EnterVoterBy {
    return noora.singleChoicePrompt(
        title: title ?? "Voter filter",
        question: "Filter votes by voter?",
        description: "Choose 'No voter filter' to see all votes, or pick a class to narrow to one voter."
    )
}

/// Resolve a voter through the wizard. Reuses `getDRep`, `getPoolOperator`,
/// `getCommitteeColdCredential`, `getCommitteeHotCredential`.
func getVoter(title: TerminalText? = nil) async throws -> VoterFilter {
    switch try await enterVoterBy(title: title) {
        case .none:
            return .none
        case .drep:
            return .drep(try await getDRep(title: "Voter (DRep)"))
        case .spo:
            return .spo(try await getPoolOperator(title: "Voter (SPO)"))
        case .ccCold:
            return .ccCold(try await getCommitteeColdCredential(title: "Voter (CC cold)"))
        case .ccHot:
            return .ccHot(try await getCommitteeHotCredential(title: "Voter (CC hot)"))
    }
}

/// Parse a raw `--voter` CLI argument. Dispatches by bech32 prefix / file extension.
/// Returns `.none` for empty input. Throws if the input format is unrecognized.
func parseVoterArgument(_ raw: String) throws -> VoterFilter {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return .none }

    // File paths first.
    if trimmed.hasSuffix(".drep") || trimmed.hasSuffix(".drep.id") || trimmed.hasSuffix(".drep.vkey") {
        let drep = try DRep.load(from: trimmed)
        return .drep(drep)
    }
    if trimmed.hasSuffix(".pool.id") || trimmed.hasSuffix(".node.vkey") {
        let raw = try String(contentsOfFile: trimmed, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .spo(try PoolOperator(from: .string(raw)))
    }

    // Bech32 prefixes.
    if trimmed.hasPrefix("drep1") || trimmed.hasPrefix("drep_script1") {
        return .drep(try DRep(from: trimmed))
    }
    if trimmed.hasPrefix("pool1") {
        return .spo(try PoolOperator(from: .string(trimmed)))
    }
    if trimmed.hasPrefix("cc_cold1") || trimmed.hasPrefix("cc_cold_script1") {
        return .ccCold(try CommitteeColdCredential(from: trimmed))
    }
    if trimmed.hasPrefix("cc_hot1") || trimmed.hasPrefix("cc_hot_script1") {
        return .ccHot(try CommitteeHotCredential(from: trimmed))
    }
    if trimmed.hasPrefix("stake1") || trimmed.hasPrefix("stake_test1") {
        let addr = try Address(from: .string(trimmed))
        guard let staking = addr.stakingPart else {
            throw ValidationError("Stake address \(raw) has no staking part.")
        }
        let cred: CredentialType
        switch staking {
        case .verificationKeyHash(let h): cred = .verificationKeyHash(h)
        case .scriptHash(let h):          cred = .scriptHash(h)
        case .pointerAddress:
            throw ValidationError("Pointer stake addresses are not supported as voter filters.")
        }
        return .stakeAddress(StakeCredential(credential: cred))
    }

    // Bare 28-byte hex hash — bash accepts this without forcing a class.
    if trimmed.count == 56, let bytes = Data(hexString: trimmed.lowercased()), bytes.count == 28 {
        return .unknownHex(bytes)
    }

    throw ValidationError(
        "Unrecognized --voter format: \(raw). Expected bech32 (drep1…/pool1…/cc_cold1…/cc_hot1…/stake1…), a 56-char hex key/script hash, or a key file (.drep.id, .pool.id, .drep.vkey, .node.vkey)."
    )
}

func getActionTypeFilter(title: TerminalText? = nil) async throws -> VoteActionTypeFilter {
    return noora.singleChoicePrompt(
        title: title ?? "Action type filter",
        question: "Filter by governance action type?",
        description: "Pick 'any' to include every type."
    )
}
