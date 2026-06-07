import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

// MARK: - Loaded voter key

/// Voter artifacts loaded for a vote-casting transaction. Mirrors `LoadedMintBurnPolicy`
/// from `MintBurnUtils.swift`: the verification key derives the on-chain `Voter`, and a
/// matching `.skey` (software) or `.hwsfile` (hardware) lives alongside for signing.
struct LoadedVoterKey {
    let name: String                    // stem, e.g. "myDRep" from "myDRep.drep.vkey"
    let role: VoterRole
    let voter: Voter                    // ready for txBuilder.addVote / cardano-cli
    let voterVKeyHash: VerificationKeyHash
    let signingKeyPath: FilePath
    let vkeyPath: FilePath
    let isHardwareWallet: Bool
}

/// Inputs for `runCastVote`. Held as a struct so the call site stays readable.
struct VoteCastInputs {
    let govActionId: GovActionID
    let voter: LoadedVoterKey
    let choice: Vote
    let anchor: Anchor?
    let skipAnchorVerify: Bool
    let ttlExtra: UInt64
    let ttlOverride: UInt64?
}

// MARK: - Role inference

/// Infer the voter role from the file extension. Matches the codebase's
/// `<stem>.<role>.vkey` naming convention. Throws if the suffix is unrecognised.
func inferVoterRole(from vkeyPath: FilePath) throws -> VoterRole {
    let lower = vkeyPath.string.lowercased()
    if lower.hasSuffix(".drep.vkey") { return .drep }
    if lower.hasSuffix(".node.vkey") { return .spo }
    if lower.hasSuffix(".cc-hot.vkey") { return .ccHot }
    noora.error(.alert(
        "Could not infer voter role from \(.danger(vkeyPath.string)).",
        takeaways: [
            "Expected one of: .drep.vkey, .node.vkey, .cc-hot.vkey.",
            "Pass --voter-role to override the inference."
        ]
    ))
    throw ExitCode.validationFailure
}

// MARK: - Voter key loading

/// Load the voter's vkey + matching skey (or hwsfile), derive the on-chain `Voter`, and
/// return everything bundled. Parallels `loadPolicyForMintBurn` in `MintBurnUtils.swift`.
func loadVoterKey(vkeyPath: FilePath, roleOverride: VoterRole?) throws -> LoadedVoterKey {
    let role = try roleOverride ?? inferVoterRole(from: vkeyPath)
    let expectedSuffix = ".\(role.keyFileSuffix).vkey"
    let lower = vkeyPath.string.lowercased()
    let stem: String
    if lower.hasSuffix(expectedSuffix) {
        stem = String(vkeyPath.string.dropLast(expectedSuffix.count))
    } else {
        // Role override was used but extension doesn't match — fall back to stripping `.vkey`.
        let last = vkeyPath.lastComponent?.string ?? vkeyPath.string
        let stemBase = (last as NSString).deletingPathExtension
        let dir = vkeyPath.removingLastComponent().string
        stem = dir.isEmpty ? stemBase : "\(dir)/\(stemBase)"
    }
    let name = (stem as NSString).lastPathComponent

    guard FileManager.default.fileExists(atPath: vkeyPath.string) else {
        noora.error(.alert(
            "Voter verification key not found: \(.danger(vkeyPath.string))"
        ))
        throw ExitCode.failure
    }

    let skeyFile = FilePath("\(stem).\(role.keyFileSuffix).skey")
    let hwsFile = FilePath("\(stem).\(role.keyFileSuffix).hwsfile")

    let hasSkey = FileManager.default.fileExists(atPath: skeyFile.string)
    let hasHws = FileManager.default.fileExists(atPath: hwsFile.string)

    let signingKeyPath: FilePath
    let isHardware: Bool
    if hasSkey {
        signingKeyPath = skeyFile
        isHardware = false
    } else if hasHws {
        signingKeyPath = hwsFile
        isHardware = true
    } else {
        noora.error(.alert(
            "Missing signing key for voter '\(.primary(name))'.",
            takeaways: [
                "Expected \(skeyFile.string) or \(hwsFile.string)."
            ]
        ))
        throw ExitCode.failure
    }

    let vkeyHash: VerificationKeyHash
    let voterType: VoterType
    switch role {
        case .drep:
            let vkey = try DRepVerificationKey.load(from: vkeyPath.string)
            vkeyHash = try vkey.hash()
            voterType = .drepKeyhash(vkeyHash)
        case .spo:
            let vkey = try StakePoolVerificationKey.load(from: vkeyPath.string)
            vkeyHash = try vkey.hash()
            voterType = .stakePoolKeyhash(vkeyHash)
        case .ccHot:
            let vkey = try CommitteeHotVerificationKey.load(from: vkeyPath.string)
            vkeyHash = try vkey.hash()
            voterType = .constitutionalCommitteeHotKeyhash(vkeyHash)
    }

    return LoadedVoterKey(
        name: name,
        role: role,
        voter: Voter(credential: voterType),
        voterVKeyHash: vkeyHash,
        signingKeyPath: signingKeyPath,
        vkeyPath: vkeyPath,
        isHardwareWallet: isHardware
    )
}

// MARK: - Interactive voter picker

/// Scan the current working directory for `*.{drep,node,cc-hot}.vkey` and prompt the
/// user to pick one. Throws if none are found. Mirrors `selectPolicyNameInteractive`.
func selectVoterVKeyInteractive() throws -> FilePath {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let entries = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { name in
            let lower = name.lowercased()
            return lower.hasSuffix(".drep.vkey")
                || lower.hasSuffix(".node.vkey")
                || lower.hasSuffix(".cc-hot.vkey")
        }
        .sorted()

    if entries.isEmpty {
        noora.error(.alert(
            "No voter verification keys (.drep.vkey / .node.vkey / .cc-hot.vkey) found in current directory.",
            takeaways: [
                "Generate one with 'scm generate drep-keys' or use existing node/CC-hot keys.",
                "Or pass --voter-vkey-file with an explicit path."
            ]
        ))
        throw ExitCode.failure
    }

    let chosen = noora.singleChoicePrompt(
        title: "Voter Key",
        question: "Select the voter verification key to use:",
        options: entries,
        description: "Role is inferred from the file extension.",
        collapseOnSelection: true,
        filterMode: .enabled
    )
    return cwd.appending(chosen)
}

// MARK: - Argument-based anchor parser

/// Build an `Anchor` from `--anchor-url` + `--anchor-hash` flags. Returns `nil` when both
/// are absent. Validates that they're both present or both absent, and that the hash is
/// 64 hex characters.
func parseAnchorArguments(url: String?, hash: String?) throws -> Anchor? {
    switch (url, hash) {
        case (nil, nil): return nil
        case (.some, nil), (nil, .some):
            throw ValidationError("--anchor-url and --anchor-hash must both be provided, or neither.")
        case let (.some(u), .some(h)):
            let trimmedUrl = u.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHash = h.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard trimmedHash.count == 64, trimmedHash.allSatisfy({ $0.isHexDigit }) else {
                throw ValidationError("--anchor-hash must be 64 hex characters, got '\(h)'.")
            }
            let anchorUrl = try Url(trimmedUrl)
            let anchorDataHash = AnchorDataHash(payload: trimmedHash.hexStringToData)
            return Anchor(anchorUrl: anchorUrl, anchorDataHash: anchorDataHash)
    }
}

// MARK: - cardano-cli vote file generation

/// Generate a TextEnvelope `.vote` file via `cardano-cli conway governance vote create`,
/// returning the path. Used only on the `--use-cardano-cli` path; SwiftCardano builds
/// the vote directly into the TransactionBody via `txBuilder.addVote`.
func generateVoteFileViaCardanoCLI(
    inputs: VoteCastInputs,
    config: MultitoolConfig
) async throws -> FilePath {
    let cli = try await CardanoCLI(
        configuration: Config(cardano: config.cardano),
        logger: getLogger(config: config)
    )

    let tmpFile = FilePath(
        FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("\(inputs.voter.name)-\(UUID().uuidString).vote")
            .path
    )

    var args: [String] = ["create"]
    switch inputs.choice {
        case .yes:     args.append("--yes")
        case .no:      args.append("--no")
        case .abstain: args.append("--abstain")
    }

    args.append(contentsOf: [
        "--governance-action-tx-id", inputs.govActionId.transactionID.payload.toHex,
        "--governance-action-index", String(inputs.govActionId.govActionIndex),
    ])

    // Voter key flag follows bash 24a_genVote.sh conventions:
    //  - DRep   → --drep-verification-key-file
    //  - SPO    → --cold-verification-key-file (stake pool cold key, same as .node.vkey)
    //  - CC Hot → --cc-hot-verification-key-file
    switch inputs.voter.role {
        case .drep:
            args.append(contentsOf: ["--drep-verification-key-file", inputs.voter.vkeyPath.string])
        case .spo:
            args.append(contentsOf: ["--cold-verification-key-file", inputs.voter.vkeyPath.string])
        case .ccHot:
            args.append(contentsOf: ["--cc-hot-verification-key-file", inputs.voter.vkeyPath.string])
    }

    if let anchor = inputs.anchor {
        args.append(contentsOf: [
            "--anchor-url", anchor.anchorUrl.absoluteString,
            "--anchor-data-hash", anchor.anchorDataHash.payload.toHex,
        ])
    }

    args.append(contentsOf: ["--out-file", tmpFile.string])

    _ = try await cli.governance.vote(arguments: args)
    return tmpFile
}

// MARK: - Shared executor

extension TransactionSendable {
    /// Run the full vote-casting pipeline: load config, optionally verify the anchor,
    /// query UTxOs, set the vote via either `TxBuilder.addVote` (SwiftCardano mode) or
    /// a pre-generated `.vote` file passed as `--vote-file` (cardano-cli mode), then
    /// hand off to `Sign --submit`.
    ///
    /// `outFile` is the signed transaction file path; on completion the caller can use
    /// it for display. Pass `nil` to derive a default from the voter name.
    mutating func runCastVote(
        inputs: VoteCastInputs,
        outFile: inout FilePath?
    ) async throws {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        let config = try await MultitoolConfig.load()
        let cardanoConfig = try getCardanoConfig(config: config)
        try await resolveAdaHandles(network: cardanoConfig.network)

        guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
            noora.error(.alert(
                "Fee payment address is required.",
                takeaways: ["Pass --fee-payment-address (or run without args for wizard mode)."]
            ))
            throw ExitCode.validationFailure
        }

        // Votes have no destination — change returns to the source address.
        if transactionOptions.toAddress == nil {
            transactionOptions.toAddress = feePaymentAddress
        }

        // 1. Anchor verification (optional, on by default per plan).
        if let anchor = inputs.anchor, !inputs.skipAnchorVerify {
            try await verifyAnchor(anchor: anchor, config: config, kind: .voteRationale)
        }

        // 2. Context, params, chain state
        let context = try await getContext(config: config)
        try await printContextInfo(config: config, context: context)

        let protocolParamsFile = cwd.appending("protocol-parameters.json")
        _ = try await getProtocolParameters(
            context: context,
            protocolParamsFile: protocolParamsFile
        )

        // 3. Fetch UTxOs
        let utxos = try await queryAndFilterUtxos(
            feePaymentAddress: feePaymentAddress.info,
            context: context,
            config: config
        )

        // 4. TTL — explicit override wins, otherwise tip + extra slots
        let ttl: UInt64
        if let override = inputs.ttlOverride {
            ttl = override
        } else {
            let tip = try await context.lastBlockSlot()
            ttl = UInt64(tip) &+ inputs.ttlExtra
        }

        // 5. Wire up TxBuilder and per-mode vote handling
        let logger = getLogger(config: config)
        let txBuilder = TxBuilder(context: context, logger: logger)
        txBuilder.ttl = SlotNumber(ttl)

        // Require the voter signer in the witness so the fee accounts for it. The payment
        // signer is inferred by the change-address pathway (matches Mint.runMintOrBurn).
        txBuilder.requiredSigners = [inputs.voter.voterVKeyHash]

        var extraBuildArgs: [String] = []
        var generatedVoteFile: FilePath? = nil

        if transactionOptions.useCardanoCLI {
            // cardano-cli path: pre-generate a TextEnvelope .vote file and pass it through
            // via the existing buildArgs pass-through in buildTransactionWithCardanoCLI.
            let voteFile = try await generateVoteFileViaCardanoCLI(
                inputs: inputs,
                config: config
            )
            generatedVoteFile = voteFile
            extraBuildArgs.append(contentsOf: ["--vote-file", voteFile.string])
        } else {
            // SwiftCardano path: TxBuilder.build() reads votingProcedures into the body.
            txBuilder.addVote(
                voter: inputs.voter.voter,
                govActionId: inputs.govActionId,
                vote: inputs.choice,
                anchor: inputs.anchor
            )
        }

        spacedPrint("\n\(.primary("━━━ Cast Vote ━━━"))\n")

        let govActionLabel = "\(inputs.govActionId.transactionID.payload.toHex)#\(inputs.govActionId.govActionIndex)"
        let choiceLabel: String = {
            switch inputs.choice {
                case .yes: return "YES"
                case .no: return "NO"
                case .abstain: return "ABSTAIN"
            }
        }()

        noora.info(.alert(
            "Casting \(.primary(choiceLabel)) vote as \(.primary(inputs.voter.role.name)) '\(.primary(inputs.voter.name))'",
            takeaways: [
                "Governance action: \(govActionLabel)",
                "Voter vkey: \(inputs.voter.vkeyPath.string)",
                "TTL: slot \(ttl)",
                "Build via: \(transactionOptions.useCardanoCLI ? "cardano-cli" : "SwiftCardano")",
                "Anchor: \(inputs.anchor.map { $0.anchorUrl.absoluteString } ?? "(none)")"
            ]
        ))

        // 6. Build via shared pipeline. Witness count: payment signer + voter signer = 2.
        let timestamp = DateUtils.getCurrentTimestamp()
        let baseName = "\(inputs.voter.name)-\(timestamp).vote"
        let txRawFile = cwd.appending("\(baseName).raw.tx")
        let txFile = cwd.appending("\(baseName).tx")
        let txSignedFile = outFile ?? cwd.appending("\(baseName).signed.tx")
        outFile = txSignedFile

        try await buildTransaction(
            txBuilder: txBuilder,
            config: config,
            utxos: utxos,
            witnessOverride: 2,
            buildArgs: extraBuildArgs,
            protocolParamsFile: protocolParamsFile,
            txRawFile: txRawFile,
            txFile: txFile,
            txSignedFile: txSignedFile
        )

        // 7. Sign with payment + voter keys; optionally submit. Sign auto-detects .skey vs .hwsfile.
        var signArgs: [String] = []
        if transactionOptions.useCardanoCLI { signArgs.append("--use-cardano-cli") }
        if transactionOptions.save          { signArgs.append("--save") }
        if transactionOptions.submit        { signArgs.append("--submit") }

        let paymentSigningPath = try feePaymentAddress.info.getSigningMethod().path.string

        await TransactionMainCommand.Sign.main([
            "--tx-file", txFile.string,
            "--out-file", txSignedFile.string
        ] + signArgs + [
            "--signing-keys", paymentSigningPath,
            "--signing-keys", inputs.voter.signingKeyPath.string
        ])

        noora.success(.alert(
            "Vote \(.primary(choiceLabel)) prepared for \(.primary(govActionLabel)).",
            takeaways: [
                "Signed tx: \(txSignedFile.string)",
                transactionOptions.submit
                    ? "Submitted to the chain."
                    : "Not submitted — pass --submit to broadcast."
            ]
        ))

        if !transactionOptions.save {
            try? FileManager.default.removeItem(atPath: txRawFile.string)
            try? FileManager.default.removeItem(atPath: txFile.string)
            try? FileManager.default.removeItem(atPath: txSignedFile.string)
        }
        if let generatedVoteFile {
            try? FileManager.default.removeItem(atPath: generatedVoteFile.string)
        }
    }
}
