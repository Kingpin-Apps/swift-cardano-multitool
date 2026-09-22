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
        description: "Enter the name of the address files in the current directory, or choose the files from any folder.",
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
            \n  • Pool ID: pool1... or 56-character hex (with or without 0x prefix)
            \n  • Cold verification key: pool_vk1... or 64-character hex
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
    guard isInteractiveSession() else {
        throw ValidationError("A stake address is required when not running interactively. Provide it via the corresponding flag/argument.")
    }
    let stakeAddressFile = try filePathPrompt(
        title: title ?? "Stake Address",
        question: "Select the stake address file:",
        description: "Stake address files (.stake.addr) are suggested.",
        fileMatches: { $0.hasSuffix(".stake.addr") }
    )
    
    let fileName = stakeAddressFile.lastComponent?.string ?? stakeAddressFile.string
    let info = try AddressInfo(
        fromFile: FileUtils.absolutePath(stakeAddressFile),
        name: fileName.replacingOccurrences(of: ".stake.addr", with: "")
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
            let addressFile = try promptPaymentAddressFile(title: "Payment Address", question: "Select the address file:")
            info = try AddressInfo(
                fromFile: FileUtils.absolutePath(addressFile),
                name: PaymentAddressFiles.stem(of: addressFile.lastComponent?.string ?? addressFile.string)
            )
    }
        
    return PaymentAddressInfo(info: info)
}

/// Prompt user to select a fee payment address file, with path completion, from any directory.
/// - Parameter title: Optional title for the prompt.
/// - Returns: PaymentAddressInfo of the selected fee payment address.
/// - Throws: ValidationError when not interactive.
func getFeePaymentAddress(title: TerminalText? = nil) async throws -> PaymentAddressInfo {
    guard isInteractiveSession() else {
        throw ValidationError("A fee payment address is required when not running interactively. Provide --fee-payment-address.")
    }
    let addressFile = try promptPaymentAddressFile(
        title: title ?? "Fee Payment Address",
        question: "Select the fee payment address file:"
    )
    let info = try AddressInfo(
        fromFile: FileUtils.absolutePath(addressFile),
        name: PaymentAddressFiles.stem(of: addressFile.lastComponent?.string ?? addressFile.string)
    )
    return PaymentAddressInfo(info: info)
}

/// Prompt for a payment address file (`<name>.payment.addr` or `<name>.addr`), with path completion.
private func promptPaymentAddressFile(title: TerminalText, question: TerminalText) throws -> FilePath {
    try filePathPrompt(
        title: title,
        question: question,
        description: "Payment address files (.payment.addr, .addr) are suggested.",
        fileMatches: { PaymentAddressFiles.isPaymentAddressFile($0) }
    )
}

/// Prompt for a transaction file, with path completion.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected transaction file.
func getTransactionFilePath(title: TerminalText? = nil) async throws -> FilePath {
    try filePathPrompt(
        title: title ?? "Transaction File",
        question: "Select the transaction file:",
        description: "Transaction files (.tx, .raw, .signed) are suggested; any file can be chosen.",
        fileMatches: { [".tx", ".raw", ".signed"].contains(where: $0.hasSuffix) }
    )
}

/// Prompt for a signing key file, with path completion.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected signing key file.
func getSigningKeyFilePath(title: TerminalText? = nil) async throws -> FilePath {
    try filePathPrompt(
        title: title ?? "Signing Key File",
        question: "Select the signing key file:",
        description: "Signing keys (.skey, .hwsfile) are suggested; any file can be chosen.",
        fileMatches: { $0.hasSuffix(".skey") || $0.hasSuffix(".hwsfile") }
    )
}

/// Prompt for a witness file, with path completion.
/// - Parameter title: Optional title for the prompt.
/// - Returns: FilePath of the selected witness file.
func getWitnessFilePath(title: TerminalText? = nil) async throws -> FilePath {
    try filePathPrompt(
        title: title ?? "Witness File",
        question: "Select the witness file:",
        description: "Witness files (.witness) are suggested; any file can be chosen.",
        fileMatches: { $0.hasSuffix(".witness") }
    )
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
            let drepFileName = try filePathPrompt(
                title: "DRep ID",
                question: "Select the DRep ID file:",
                description: ".drep.id files are suggested.",
                fileMatches: { $0.hasSuffix(".drep.id") }
            )
            
            return try DRep.load(from: FileUtils.absolutePath(drepFileName).string)
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
            let drepFileName = try filePathPrompt(
                title: "DRep ID",
                question: "Select the DRep Verification Key file:",
                description: ".drep.vkey files are suggested.",
                fileMatches: { $0.hasSuffix(".drep.vkey") }
            )
            let drepVKey = try DRepVerificationKey.load(from: FileUtils.absolutePath(drepFileName).string)
            return DRep(credential: .verificationKeyHash(try drepVKey.hash()))
        case .skey:
            let drepFileName = try filePathPrompt(
                title: "DRep ID",
                question: "Select the DRep Signing Key file:",
                description: ".drep.skey files are suggested.",
                fileMatches: { $0.hasSuffix(".drep.skey") }
            )
            let drepSKey = try DRepSigningKey.load(
                from: FileUtils.absolutePath(drepFileName).string
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
    
    switch enterPoolOperatorBy {
        case .path:
            let poolOperatorFileName = try filePathPrompt(
                title: "Pool ID",
                question: "Select the Pool ID file:",
                description: ".pool.id and .pool.id-bech files are suggested.",
                fileMatches: { $0.hasSuffix(".pool.id") || $0.hasSuffix(".pool.id-bech") }
            )
            
            return try PoolOperator.load(from: FileUtils.absolutePath(poolOperatorFileName).string)
        case .id:
            let poolId = noora.textPrompt(
                title: "Pool ID",
                prompt: "Enter the pool ID or cold verification key:",
                description: "Accepts pool1…, 56-character hex, pool_vk1…, or 64-character hex.",
                collapseOnAnswer: true,
                validationRules: [
                    NonEmptyValidationRule(error: "Pool ID cannot be empty."),
                    PoolOperatorValidationRule(error: "Not a valid pool ID or cold verification key.")
                ]
            )
            guard let poolOperator = PoolOperator(argument: poolId) else {
                throw ExitCode.validationFailure
            }
            return poolOperator
        case .vkey:
            let poolOperatorFileName = try filePathPrompt(
                title: "Pool VKey",
                question: "Select the Node Verification Key file:",
                description: ".node.vkey files are suggested.",
                fileMatches: { $0.hasSuffix(".node.vkey") }
            )
            let poolOperatorVKey = try StakePoolVerificationKey.load(from: FileUtils.absolutePath(poolOperatorFileName).string
            )
            return PoolOperator(poolKeyHash: try poolOperatorVKey.poolKeyHash())
        case .skey:
            let poolOperatorFileName = try filePathPrompt(
                title: "Pool SKey",
                question: "Select the Node Signing Key file:",
                description: ".node.skey files are suggested.",
                fileMatches: { $0.hasSuffix(".node.skey") }
            )
            let poolOperatorSKey = try StakePoolSigningKey.load(
                from: FileUtils.absolutePath(poolOperatorFileName).string
            )
            let poolOperatorVKey: StakePoolVerificationKey = try poolOperatorSKey.toVerificationKey()
            return PoolOperator(poolKeyHash: try poolOperatorVKey.poolKeyHash())
    }
}

/// Prompt for a pool.json file, with path completion.
/// - Returns: FilePath of the selected pool.json file.
func getPoolJSON() async throws -> FilePath {
    try filePathPrompt(
        title: "Pool JSON File",
        question: "Select the pool.json file:",
        description: "JSON files are suggested; any file can be chosen.",
        fileMatches: { $0.hasSuffix(".json") }
    )
}

/// Prompt user to enter a Committee Cold Credential.
func getCommitteeColdCredential(title: TerminalText? = nil) async throws -> CommitteeColdCredential {
    let method: EnterCommitteeColdCredentialBy = noora.singleChoicePrompt(
        title: title ?? "Committee Cold Credential",
        question: "Enter Committee Cold Credential by:",
        description: "Accepted formats: Bech32 (cc_cold1...), hex, or key file."
    )

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
            let fileName = try filePathPrompt(
                title: "CC Cold VKey",
                question: "Select the Committee Cold verification key file:",
                description: ".cc-cold.vkey files are suggested.",
                fileMatches: { $0.hasSuffix(".cc-cold.vkey") }
            )
            let vkey = try CommitteeColdVerificationKey.load(from: FileUtils.absolutePath(fileName).string)
            return CommitteeColdCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let fileName = try filePathPrompt(
                title: "CC Cold SKey",
                question: "Select the Committee Cold signing key file:",
                description: ".cc-cold.skey files are suggested.",
                fileMatches: { $0.hasSuffix(".cc-cold.skey") }
            )
            let skey = try CommitteeColdSigningKey.load(from: FileUtils.absolutePath(fileName).string)
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
            let fileName = try filePathPrompt(
                title: "CC Hot VKey",
                question: "Select the Committee Hot verification key file:",
                description: ".cc-hot.vkey files are suggested.",
                fileMatches: { $0.hasSuffix(".cc-hot.vkey") }
            )
            let vkey = try CommitteeHotVerificationKey.load(from: FileUtils.absolutePath(fileName).string)
            return CommitteeHotCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let fileName = try filePathPrompt(
                title: "CC Hot SKey",
                question: "Select the Committee Hot signing key file:",
                description: ".cc-hot.skey files are suggested.",
                fileMatches: { $0.hasSuffix(".cc-hot.skey") }
            )
            let skey = try CommitteeHotSigningKey.load(from: FileUtils.absolutePath(fileName).string)
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
            let fileName = try filePathPrompt(
                title: "DRep VKey",
                question: "Select the DRep verification key file:",
                description: ".drep.vkey files are suggested.",
                fileMatches: { $0.hasSuffix(".drep.vkey") }
            )
            let vkey = try DRepVerificationKey.load(from: FileUtils.absolutePath(fileName).string)
            return DRepCredential(credential: .verificationKeyHash(try vkey.hash()))
        case .skey:
            let fileName = try filePathPrompt(
                title: "DRep SKey",
                question: "Select the DRep signing key file:",
                description: ".drep.skey files are suggested.",
                fileMatches: { $0.hasSuffix(".drep.skey") }
            )
            let skey = try DRepSigningKey.load(from: FileUtils.absolutePath(fileName).string)
            let vkey: DRepVerificationKey = try skey.toVerificationKey()
            return DRepCredential(credential: .verificationKeyHash(try vkey.hash()))
    }
}

/// Prompt user to optionally provide an Anchor (metadata URL + hash).
/// - Parameter purpose: Describes the context (e.g. "DRep registration", "committee resignation").
/// - Returns: Anchor if user confirmed, nil otherwise.
func getOptionalAnchor(purpose: String = "metadata") async throws -> Anchor? {
    // Non-interactive: no anchor is supplied here. Callers that require one
    // (e.g. governance actions) surface their own clear error.
    guard isInteractiveSession() else { return nil }
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

/// Whether the process can interactively prompt the user.
///
/// Returns `false` when standard input is not a TTY (e.g. piped/scripted/CI) or
/// when prompts have been explicitly suppressed via `CARDANO_MULTITOOL_SKIP_PROMPT`.
/// Callers should use this to pick a sensible default (or throw a clear error)
/// instead of calling a Noora prompt, which aborts the process with a fatal
/// error when it cannot prompt.
func isInteractiveSession() -> Bool {
    return isatty(FileHandle.standardInput.fileDescriptor) != 0
        && !Environment.getBool(Environment.skipPrompt)
}

/// Prompt user to select which tool to use for generating keys (cardano-cli or SwiftCardano).
/// - Returns: Tool enum value indicating the selected tool.
func getToolToUse() async throws -> Tool {
    if Environment.getBool(Environment.useCardanoCLI) {
        return .cardanoCLI
    }
    else if Environment.getBool(Environment.useSwiftCardano) {
        return .swiftCardano
    } else if !isInteractiveSession() {
        // Non-interactive (piped/scripted or CARDANO_MULTITOOL_SKIP_PROMPT):
        // default to the built-in SwiftCardano path rather than aborting on a
        // prompt that cannot be displayed.
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

/// Prompt for a file path with completion, suggesting the files that match.
/// - Parameters:
///   - title: Prompt title.
///   - question: Question shown above the input.
///   - matching: Which file names to suggest; any file can still be chosen.
/// - Returns: The selected or entered path.
func promptFilePath(
    title: TerminalText,
    question: TerminalText,
    matching: @escaping @Sendable (String) -> Bool
) throws -> FilePath {
    try filePathPrompt(title: title, question: question, fileMatches: matching)
}
