import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

// MARK: - Payload

/// Per-type payload for a Conway governance action create-* call. Built by each subcommand's
/// `run()` and consumed by the shared executor.
///
/// `prevActionID` is nullable for action types whose CDDL allows a null reference (the first
/// action of its kind on chain). On NewConstitution / NoConfidence the SwiftCardanoCore model
/// treats it as non-optional — those payloads still carry an `Optional` so we can prompt the
/// user, and the executor errors out when SwiftCardano mode is requested with a nil id.
enum GovernanceActionPayload {
    case infoAction
    case treasuryWithdrawal(
        withdrawals: [TreasuryWithdrawalEntry],
        guardrailsScriptHash: ScriptHash?
    )
    case noConfidence(prevActionID: GovActionID?)
    case newConstitution(
        prevActionID: GovActionID?,
        constitutionUrl: String,
        constitutionHash: String,
        scriptHash: ScriptHash?
    )
    case hardForkInitiation(
        prevActionID: GovActionID?,
        major: Int,
        minor: Int
    )
    case updateCommittee(
        prevActionID: GovActionID?,
        threshold: UnitInterval,
        additions: [CommitteeAddition],
        removals: [CommitteeColdCredential]
    )
    case parameterChange(
        prevActionID: GovActionID?,
        update: ProtocolParamUpdate,
        guardrailsScriptHash: ScriptHash?
    )

    var type: GovernanceActionType {
        switch self {
            case .infoAction: return .infoAction
            case .treasuryWithdrawal: return .treasuryWithdrawal
            case .noConfidence: return .noConfidence
            case .newConstitution: return .newConstitution
            case .hardForkInitiation: return .hardForkInitiation
            case .updateCommittee: return .updateCommittee
            case .parameterChange: return .parameterChange
        }
    }
}

/// One withdrawal target: stake address (bech32) + lovelaces. We keep the bech32 alongside the
/// parsed `Address` so we can spawn cardano-cli flags without re-encoding.
struct TreasuryWithdrawalEntry {
    let stakeAddressBech32: String
    let stakeAddress: Address
    let amount: UInt64
}

/// One add-to-committee directive: cold credential + term end epoch.
struct CommitteeAddition {
    let credential: CommitteeColdCredential
    let termEpoch: UInt64
    /// Hex of the underlying key/script hash — kept for cardano-cli flag emission.
    let hashHex: String
    /// Whether this is a script hash (vs key hash) — drives the cardano-cli flag choice.
    let isScriptHash: Bool
}

// MARK: - Inputs

/// Aggregated inputs for `runCreateGovernanceAction`. Mirrors `VoteCastInputs` in shape.
struct GovernanceActionInputs {
    let payload: GovernanceActionPayload
    /// Resolved stake address whose reward account collects the proposal deposit on rejection.
    let depositReturnStakeAddress: StakeAddressInfo
    /// Lovelace deposit. Pulled from `govActionDeposit` protocol param when zero.
    var deposit: UInt64
    let anchor: Anchor
    let skipAnchorVerify: Bool
    let ttlExtra: UInt64
    let ttlOverride: UInt64?
    let generateOnly: Bool
    /// Optional override for the emitted `.action` file path. When nil the executor derives
    /// `<fee-payment-name>_<type-slug>_<timestamp>.action` in the current directory.
    let actionOutFile: FilePath?
}

// MARK: - GovAction construction (SwiftCardano path)

/// Build the SwiftCardanoCore `GovAction` variant for a given payload. Used on the SwiftCardano
/// build path. Throws `ValidationError` when the payload references a missing previous action ID
/// in cases where the CDDL model requires it.
func buildGovAction(payload: GovernanceActionPayload) throws -> GovAction {
    switch payload {
        case .infoAction:
            return .infoAction(InfoAction())

        case let .treasuryWithdrawal(withdrawals, guardrailsScriptHash):
            var dict: [RewardAccount: Coin] = [:]
            for entry in withdrawals {
                let account = RewardAccount(entry.stakeAddress.toBytes())
                dict[account] = Coin(entry.amount)
            }
            return .treasuryWithdrawalsAction(
                TreasuryWithdrawalsAction(
                    withdrawals: dict,
                    policyHash: guardrailsScriptHash
                )
            )

        case let .noConfidence(prevActionID):
            guard let id = prevActionID else {
                throw ValidationError("SwiftCardano build mode requires --prev-action-id for no-confidence actions. Pass --use-cardano-cli to let the CLI infer it, or query gov-state and supply it explicitly.")
            }
            return .noConfidence(NoConfidence(id: id))

        case let .newConstitution(prevActionID, urlStr, hashHex, scriptHash):
            guard let id = prevActionID else {
                throw ValidationError("SwiftCardano build mode requires --prev-action-id for new-constitution actions. Pass --use-cardano-cli or supply --prev-action-id.")
            }
            let url = try Url(urlStr)
            let hashData = hashHex.hexStringToData
            let anchor = Anchor(anchorUrl: url, anchorDataHash: AnchorDataHash(payload: hashData))
            let constitution = Constitution(anchor: anchor, scriptHash: scriptHash)
            return .newConstitution(NewConstitution(id: id, constitution: constitution))

        case let .hardForkInitiation(prevActionID, major, minor):
            let pv = ProtocolVersion(major: major, minor: minor)
            return .hardForkInitiationAction(
                HardForkInitiationAction(id: prevActionID, protocolVersion: pv)
            )

        case let .updateCommittee(prevActionID, threshold, additions, removals):
            var credentialEpochs: [CommitteeColdCredential: UInt64] = [:]
            for add in additions {
                credentialEpochs[add.credential] = add.termEpoch
            }
            return .updateCommittee(
                UpdateCommittee(
                    id: prevActionID,
                    coldCredentials: Set(removals),
                    credentialEpochs: credentialEpochs,
                    interval: threshold
                )
            )

        case let .parameterChange(prevActionID, update, scriptHash):
            // SwiftCardanoCore's ParameterChangeAction.id is declared non-optional in the
            // type but the on-chain CDDL allows null. Pass nil via the public init by way of
            // a workaround when prevActionID is nil — but in v1 we require it.
            guard let id = prevActionID else {
                throw ValidationError("SwiftCardano build mode requires --prev-action-id for parameter-change actions. Pass --use-cardano-cli or supply --prev-action-id.")
            }
            return .parameterChangeAction(
                ParameterChangeAction(
                    id: id,
                    protocolParamUpdate: update,
                    policyHash: scriptHash
                )
            )
    }
}

// MARK: - cardano-cli action-file generation

/// Generate a TextEnvelope `.action` file via `cardano-cli conway governance action create-*`,
/// returning the path. Used by the cardano-cli build path and by `--generate-only`.
///
/// Mirrors the bash duo's `25a_genAction.sh` argv exactly so the on-chain bytes are bit-for-bit
/// identical regardless of which backend produced them.
func generateActionFileViaCardanoCLI(
    payload: GovernanceActionPayload,
    deposit: UInt64,
    depositReturnStakeAddressBech32: String,
    anchor: Anchor,
    outFile: FilePath,
    config: MultitoolConfig
) async throws -> FilePath {
    let cli = try await CardanoCLI(
        configuration: Config(cardano: config.cardano),
        logger: getLogger(config: config)
    )

    let cardanoConfig = try getCardanoConfig(config: config)
    let networkArgs = cardanoConfig.network.arguments

    let common: [String] = networkArgs + [
        "--governance-action-deposit", String(deposit),
        "--deposit-return-stake-address", depositReturnStakeAddressBech32,
        "--anchor-url", anchor.anchorUrl.absoluteString,
        "--anchor-data-hash", anchor.anchorDataHash.payload.toHex,
        "--out-file", outFile.string,
    ]

    var args: [String]

    switch payload {
        case .infoAction:
            args = ["create-info"] + common

        case let .treasuryWithdrawal(withdrawals, guardrailsScriptHash):
            args = ["create-treasury-withdrawal"] + common
            for entry in withdrawals {
                args.append(contentsOf: [
                    "--funds-receiving-stake-address", entry.stakeAddressBech32,
                    "--transfer", String(entry.amount),
                ])
            }
            if let scriptHash = guardrailsScriptHash {
                args.append(contentsOf: ["--constitution-script-hash", scriptHash.payload.toHex])
            }

        case let .noConfidence(prevActionID):
            args = ["create-no-confidence"] + common
            args.append(contentsOf: prevActionIDFlags(prevActionID))

        case let .newConstitution(prevActionID, urlStr, hashHex, scriptHash):
            args = ["create-constitution"] + common
            args.append(contentsOf: prevActionIDFlags(prevActionID))
            args.append(contentsOf: [
                "--constitution-url", urlStr,
                "--constitution-hash", hashHex,
            ])
            if let scriptHash {
                args.append(contentsOf: ["--constitution-script-hash", scriptHash.payload.toHex])
            }

        case let .hardForkInitiation(prevActionID, major, minor):
            args = ["create-hardfork"] + common
            args.append(contentsOf: prevActionIDFlags(prevActionID))
            args.append(contentsOf: [
                "--protocol-major-version", String(major),
                "--protocol-minor-version", String(minor),
            ])

        case let .updateCommittee(prevActionID, threshold, additions, removals):
            args = ["update-committee"] + common
            args.append(contentsOf: prevActionIDFlags(prevActionID))
            args.append(contentsOf: [
                "--threshold", "\(threshold.numerator)/\(threshold.denominator)",
            ])
            for add in additions {
                let addFlag = add.isScriptHash
                    ? "--add-cc-cold-script-hash"
                    : "--add-cc-cold-verification-key-hash"
                args.append(contentsOf: [addFlag, add.hashHex, "--epoch", String(add.termEpoch)])
            }
            for rem in removals {
                let (hashHex, isScript) = credentialHashAndKind(rem)
                let removeFlag = isScript
                    ? "--remove-cc-cold-script-hash"
                    : "--remove-cc-cold-verification-key-hash"
                args.append(contentsOf: [removeFlag, hashHex])
            }

        case let .parameterChange(prevActionID, update, scriptHash):
            args = ["create-protocol-parameters-update"] + common
            args.append(contentsOf: prevActionIDFlags(prevActionID))
            args.append(contentsOf: try parameterChangeFlags(from: update))
            if let scriptHash {
                args.append(contentsOf: ["--constitution-script-hash", scriptHash.payload.toHex])
            }
    }

    _ = try await cli.governance.action(arguments: args)
    return outFile
}

/// Emit the `--prev-governance-action-tx-id` / `--prev-governance-action-index` pair, or nothing
/// when nil. The CLI accepts the absence to mean "no previous action".
private func prevActionIDFlags(_ id: GovActionID?) -> [String] {
    guard let id else { return [] }
    return [
        "--prev-governance-action-tx-id", id.transactionID.payload.toHex,
        "--prev-governance-action-index", String(id.govActionIndex),
    ]
}

/// Extract hash hex + is-script flag from a CommitteeColdCredential.
private func credentialHashAndKind(_ cred: CommitteeColdCredential) -> (String, Bool) {
    switch cred.credential {
        case .verificationKeyHash(let h): return (h.payload.toHex, false)
        case .scriptHash(let h): return (h.payload.toHex, true)
    }
}

/// Translate a non-nil-field `ProtocolParamUpdate` into `cardano-cli` flags. Only the fields the
/// user actually set are emitted; nil fields are skipped. Returns the flag list (no leading
/// subcommand). Throws when an unsupported field is set so the user gets a clear error.
private func parameterChangeFlags(from update: ProtocolParamUpdate) throws -> [String] {
    var flags: [String] = []

    if let v = update.minFeeA { flags.append(contentsOf: ["--min-fee-linear", String(v)]) }
    if let v = update.minFeeB { flags.append(contentsOf: ["--min-fee-constant", String(v)]) }
    if let v = update.maxBlockBodySize { flags.append(contentsOf: ["--max-block-body-size", String(v)]) }
    if let v = update.maxTransactionSize { flags.append(contentsOf: ["--max-tx-size", String(v)]) }
    if let v = update.maxBlockHeaderSize { flags.append(contentsOf: ["--max-block-header-size", String(v)]) }
    if let v = update.keyDeposit { flags.append(contentsOf: ["--key-reg-deposit-amt", String(v)]) }
    if let v = update.poolDeposit { flags.append(contentsOf: ["--pool-reg-deposit", String(v)]) }
    if let v = update.maximumEpoch { flags.append(contentsOf: ["--pool-retirement-epoch-interval", String(v)]) }
    if let v = update.nOpt { flags.append(contentsOf: ["--number-of-pools", String(v)]) }
    if let v = update.minPoolCost { flags.append(contentsOf: ["--min-pool-cost", String(v)]) }
    if let v = update.adaPerUtxoByte { flags.append(contentsOf: ["--utxo-cost-per-byte", String(v)]) }
    if let v = update.maxValueSize { flags.append(contentsOf: ["--max-value-size", String(v)]) }
    if let v = update.collateralPercentage { flags.append(contentsOf: ["--collateral-percent", String(v)]) }
    if let v = update.maxCollateralInputs { flags.append(contentsOf: ["--max-collateral-inputs", String(v)]) }
    if let v = update.minCommitteeSize { flags.append(contentsOf: ["--min-committee-size", String(v)]) }
    if let v = update.committeeTermLimit { flags.append(contentsOf: ["--committee-term-length", String(v)]) }
    if let v = update.governanceActionValidityPeriod { flags.append(contentsOf: ["--governance-action-lifetime", String(v)]) }
    if let v = update.governanceActionDeposit { flags.append(contentsOf: ["--new-governance-action-deposit", String(v)]) }
    if let v = update.drepDeposit { flags.append(contentsOf: ["--drep-deposit", String(v)]) }
    if let v = update.drepInactivityPeriod { flags.append(contentsOf: ["--drep-activity", String(v)]) }

    if let v = update.expansionRate {
        flags.append(contentsOf: ["--monetary-expansion", "\(v.numerator)/\(v.denominator)"])
    }
    if let v = update.treasuryGrowthRate {
        flags.append(contentsOf: ["--treasury-expansion", "\(v.numerator)/\(v.denominator)"])
    }
    if let v = update.poolPledgeInfluence {
        // NonNegativeInterval stores its rational as `lowerBound / upperBound`
        // (a misnamed numerator/denominator pair — see Types/Interval.swift).
        flags.append(contentsOf: ["--pool-influence", "\(v.lowerBound)/\(v.upperBound)"])
    }
    if let v = update.minFeeRefScriptCoinsPerByte {
        flags.append(contentsOf: ["--ref-script-cost-per-byte", "\(v.lowerBound)/\(v.upperBound)"])
    }

    if let v = update.protocolVersion {
        flags.append(contentsOf: ["--protocol-major-version", String(v.major ?? 0)])
        flags.append(contentsOf: ["--protocol-minor-version", String(v.minor ?? 0)])
    }

    if update.costModels != nil
        || update.executionCosts != nil
        || update.maxTxExUnits != nil
        || update.maxBlockExUnits != nil
        || update.poolVotingThresholds != nil
        || update.drepVotingThresholds != nil
    {
        throw ValidationError("""
        cardano-cli mode does not yet support setting cost models, execution prices, ex-units,
        voting thresholds, or ref-script fees from a JSON protocol-param-update file.
        Re-run without --use-cardano-cli (SwiftCardano backend) to set these fields.
        """)
    }

    return flags
}

// MARK: - JSON helpers

/// Decode a `ProtocolParamUpdate` from a JSON file. The JSON keys must match the struct's
/// Codable conformance — see `ProtocolParamUpdate` in SwiftCardanoCore. Throws with a clear
/// error message on malformed input.
func loadProtocolParamUpdate(from path: FilePath) throws -> ProtocolParamUpdate {
    guard FileManager.default.fileExists(atPath: path.string) else {
        throw ValidationError("Protocol param update file not found: \(path.string)")
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
    do {
        return try JSONDecoder().decode(ProtocolParamUpdate.self, from: data)
    } catch {
        throw ValidationError("Failed to decode \(path.string) as ProtocolParamUpdate: \(error)")
    }
}

// MARK: - Shared executor

extension TransactionSendable {
    /// Run the full create-action pipeline: load config, verify anchor, query UTxOs, generate the
    /// `.action` file (SwiftCardano or cardano-cli), build the tx, sign, and (with `--submit`)
    /// broadcast.
    ///
    /// When `inputs.generateOnly` is `true` this returns immediately after writing the `.action`
    /// file — no tx is built or signed.
    ///
    /// Parallels `runCastVote` in `VoteCastUtils.swift`. The witness count override is 1: the
    /// proposer's payment signer is the only required signature.
    mutating func runCreateGovernanceAction(
        inputs: GovernanceActionInputs,
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

        if transactionOptions.toAddress == nil {
            transactionOptions.toAddress = feePaymentAddress
        }

        // 1. Anchor verification (download + blake2b + CIP-100 sig).
        if !inputs.skipAnchorVerify {
            try await verifyAnchor(anchor: inputs.anchor, config: config, kind: .governanceAction)
        }

        // 2. Resolve the deposit-return stake address.
        guard let stakeAddrObj = inputs.depositReturnStakeAddress.info.address else {
            throw ValidationError("Could not resolve deposit-return stake address.")
        }
        let depositReturnBech32 = (try? stakeAddrObj.toBech32()) ?? ""
        guard !depositReturnBech32.isEmpty else {
            throw ValidationError("Deposit-return stake address could not be encoded as bech32.")
        }
        let rewardAccount = RewardAccount(stakeAddrObj.toBytes())

        // 3. Context + protocol params (used both to derive default deposit and to drive build).
        let context = try await getContext(config: config)
        try await printContextInfo(config: config, context: context)

        let protocolParamsFile = cwd.appending("protocol-parameters.json")
        let protocolParams = try await getProtocolParameters(
            context: context,
            protocolParamsFile: protocolParamsFile
        )

        var resolvedDeposit = inputs.deposit
        if resolvedDeposit == 0 {
            let onChainDeposit = protocolParams.govActionDeposit
            guard onChainDeposit > 0 else {
                throw ValidationError("Could not read a positive govActionDeposit from protocol parameters. Pass --deposit to override.")
            }
            resolvedDeposit = UInt64(onChainDeposit)
        }

        // 4. Resolve action-file path.
        let timestamp = DateUtils.getCurrentTimestamp()
        let payerName = feePaymentAddress.info.name ?? "proposer"
        let actionFileName = "\(payerName)_\(inputs.payload.type.fileSlug)_\(timestamp).action"
        let actionFile = inputs.actionOutFile ?? cwd.appending(actionFileName)

        // 5. Emit the .action file via the selected backend.
        if transactionOptions.useCardanoCLI {
            _ = try await generateActionFileViaCardanoCLI(
                payload: inputs.payload,
                deposit: resolvedDeposit,
                depositReturnStakeAddressBech32: depositReturnBech32,
                anchor: inputs.anchor,
                outFile: actionFile,
                config: config
            )
        } else {
            let govAction = try buildGovAction(payload: inputs.payload)
            let procedure = ProposalProcedure(
                deposit: Coin(resolvedDeposit),
                rewardAccount: rewardAccount,
                govAction: govAction,
                anchor: inputs.anchor
            )
            try procedure.save(to: actionFile.string, overwrite: true)
        }

        spacedPrint("\n\(.primary("━━━ Governance Action: \(inputs.payload.type.name) ━━━"))\n")
        noora.info(.alert(
            "Action file: \(.primary(actionFile.string))",
            takeaways: [
                "Deposit: \(resolvedDeposit) lovelace",
                "Deposit-return stake address: \(depositReturnBech32)",
                "Anchor URL: \(inputs.anchor.anchorUrl.absoluteString)",
                "Anchor hash: \(inputs.anchor.anchorDataHash.payload.toHex)",
                "Build backend: \(transactionOptions.useCardanoCLI ? "cardano-cli" : "SwiftCardano")"
            ]
        ))

        if inputs.generateOnly {
            noora.success(.alert(
                "Generated \(.primary(inputs.payload.type.name)) action file. No transaction built.",
                takeaways: [
                    "Action file: \(actionFile.string)",
                    "Submit later with: scm governance submit-action --action-file \(actionFile.string) --fee-payment-address …"
                ]
            ))
            outFile = actionFile
            return
        }

        // 6. UTXO query + TTL computation.
        let utxos = try await queryAndFilterUtxos(
            feePaymentAddress: feePaymentAddress.info,
            context: context,
            config: config
        )

        let ttl: UInt64
        if let override = inputs.ttlOverride {
            ttl = override
        } else {
            let tip = try await context.lastBlockSlot()
            ttl = UInt64(tip) &+ inputs.ttlExtra
        }

        // 7. Wire up TxBuilder. Cardano-cli mode threads the action file through buildArgs;
        // SwiftCardano mode calls addProposal directly so the proposal procedure is encoded in
        // the body.
        let logger = getLogger(config: config)
        let txBuilder = TxBuilder(context: context, logger: logger)
        txBuilder.ttl = SlotNumber(ttl)

        var extraBuildArgs: [String] = []
        if transactionOptions.useCardanoCLI {
            extraBuildArgs.append(contentsOf: ["--proposal-file", actionFile.string])
        } else {
            let govAction = try buildGovAction(payload: inputs.payload)
            txBuilder.addProposal(
                deposit: Int(resolvedDeposit),
                rewardAccount: rewardAccount,
                govAction: govAction,
                anchor: inputs.anchor
            )
        }

        // 8. Build via shared pipeline. One witness: payment signer covers the proposer.
        let txRawFile = cwd.appending("\(payerName)-\(timestamp).proposal.raw.tx")
        let txFile = cwd.appending("\(payerName)-\(timestamp).proposal.tx")
        let txSignedFile = outFile ?? cwd.appending("\(payerName)-\(timestamp).proposal.signed.tx")
        outFile = txSignedFile

        try await buildTransaction(
            txBuilder: txBuilder,
            config: config,
            utxos: utxos,
            witnessOverride: 1,
            buildArgs: extraBuildArgs,
            protocolParamsFile: protocolParamsFile,
            txRawFile: txRawFile,
            txFile: txFile,
            txSignedFile: txSignedFile
        )

        // 9. Sign + optionally submit.
        var signArgs: [String] = []
        if transactionOptions.useCardanoCLI { signArgs.append("--use-cardano-cli") }
        if transactionOptions.save          { signArgs.append("--save") }
        if transactionOptions.submit        { signArgs.append("--submit") }

        let paymentSigningPath = try feePaymentAddress.info.getSigningMethod().path.string

        await TransactionMainCommand.Sign.main([
            "--tx-file", txFile.string,
            "--out-file", txSignedFile.string
        ] + signArgs + [
            "--signing-keys", paymentSigningPath
        ])

        noora.success(.alert(
            "\(.primary(inputs.payload.type.name)) proposal prepared.",
            takeaways: [
                "Action file: \(actionFile.string)",
                "Signed tx: \(txSignedFile.string)",
                transactionOptions.submit
                    ? "Submitted to the chain — the proposal ID is the tx hash + index 0."
                    : "Not submitted — pass --submit to broadcast."
            ]
        ))

        if !transactionOptions.save {
            try? FileManager.default.removeItem(atPath: txRawFile.string)
            try? FileManager.default.removeItem(atPath: txFile.string)
            try? FileManager.default.removeItem(atPath: txSignedFile.string)
            try? FileManager.default.removeItem(atPath: actionFile.string)
        }
    }

    /// Submit pre-built `.action` files. Loads each as a `ProposalProcedure` to discover deposit
    /// + reward-account, then forwards to the shared transaction pipeline with one
    /// `--proposal-file <path>` per file. Mirrors `25b_regAction.sh`.
    mutating func runSubmitActionFiles(
        actionFiles: [FilePath],
        ttlExtra: UInt64,
        ttlOverride: UInt64?,
        outFile: inout FilePath?
    ) async throws {
        guard !actionFiles.isEmpty else {
            throw ValidationError("At least one --action-file is required.")
        }

        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        let config = try await MultitoolConfig.load()
        let cardanoConfig = try getCardanoConfig(config: config)
        try await resolveAdaHandles(network: cardanoConfig.network)

        guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
            throw ValidationError("--fee-payment-address is required.")
        }
        if transactionOptions.toAddress == nil {
            transactionOptions.toAddress = feePaymentAddress
        }

        // Load each .action so we can display deposit + reward-account info.
        var procedures: [ProposalProcedure] = []
        for file in actionFiles {
            guard FileManager.default.fileExists(atPath: file.string) else {
                throw ValidationError("Action file not found: \(file.string)")
            }
            do {
                let proc = try ProposalProcedure.load(from: file.string)
                procedures.append(proc)
            } catch {
                throw ValidationError("Could not load \(file.string) as a governance action: \(error)")
            }
        }

        let totalDeposit = procedures.reduce(UInt64(0)) { $0 + UInt64($1.deposit) }
        spacedPrint("\n\(.primary("━━━ Submit Governance Action(s) ━━━"))\n")
        noora.info(.alert(
            "Submitting \(.primary(String(actionFiles.count))) governance action file(s).",
            takeaways: [
                "Total deposit: \(totalDeposit) lovelace",
                "Fee payer: \(feePaymentAddress.info.description)"
            ]
        ))

        // Context, params, UTxOs.
        let context = try await getContext(config: config)
        try await printContextInfo(config: config, context: context)
        let protocolParamsFile = cwd.appending("protocol-parameters.json")
        _ = try await getProtocolParameters(context: context, protocolParamsFile: protocolParamsFile)

        let utxos = try await queryAndFilterUtxos(
            feePaymentAddress: feePaymentAddress.info,
            context: context,
            config: config
        )

        let ttl: UInt64
        if let override = ttlOverride {
            ttl = override
        } else {
            let tip = try await context.lastBlockSlot()
            ttl = UInt64(tip) &+ ttlExtra
        }

        let logger = getLogger(config: config)
        let txBuilder = TxBuilder(context: context, logger: logger)
        txBuilder.ttl = SlotNumber(ttl)

        var extraBuildArgs: [String] = []
        if transactionOptions.useCardanoCLI {
            for file in actionFiles {
                extraBuildArgs.append(contentsOf: ["--proposal-file", file.string])
            }
        } else {
            // SwiftCardano path: re-add the parsed procedures to the builder. Since
            // ProposalProcedure carries deposit + reward account + govAction + anchor we
            // reconstruct addProposal calls directly.
            for proc in procedures {
                txBuilder.addProposal(
                    deposit: Int(proc.deposit),
                    rewardAccount: proc.rewardAccount,
                    govAction: proc.govAction,
                    anchor: proc.anchor
                )
            }
        }

        let timestamp = DateUtils.getCurrentTimestamp()
        let payerName = feePaymentAddress.info.name ?? "proposer"
        let txRawFile = cwd.appending("\(payerName)-\(timestamp).submit.raw.tx")
        let txFile = cwd.appending("\(payerName)-\(timestamp).submit.tx")
        let txSignedFile = outFile ?? cwd.appending("\(payerName)-\(timestamp).submit.signed.tx")
        outFile = txSignedFile

        try await buildTransaction(
            txBuilder: txBuilder,
            config: config,
            utxos: utxos,
            witnessOverride: 1,
            buildArgs: extraBuildArgs,
            protocolParamsFile: protocolParamsFile,
            txRawFile: txRawFile,
            txFile: txFile,
            txSignedFile: txSignedFile
        )

        var signArgs: [String] = []
        if transactionOptions.useCardanoCLI { signArgs.append("--use-cardano-cli") }
        if transactionOptions.save          { signArgs.append("--save") }
        if transactionOptions.submit        { signArgs.append("--submit") }

        let paymentSigningPath = try feePaymentAddress.info.getSigningMethod().path.string

        await TransactionMainCommand.Sign.main([
            "--tx-file", txFile.string,
            "--out-file", txSignedFile.string
        ] + signArgs + [
            "--signing-keys", paymentSigningPath
        ])

        noora.success(.alert(
            "Governance action transaction prepared.",
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
    }
}

// MARK: - Shared CLI flag bundle

/// Options every governance-action create-* subcommand exposes. Used via `@OptionGroup`.
struct SharedGovernanceActionOptions: ParsableArguments {
    @Option(name: .long, help: "Anchor URL — CIP-100 governance metadata for this action.")
    var anchorUrl: String?

    @Option(name: .long, help: "Anchor blake2b-256 hash (64 hex chars). Required if --anchor-url is set.")
    var anchorHash: String?

    @Flag(name: .long, help: "Skip download + blake2b + CIP-100 verification of the anchor.")
    var skipAnchorVerify: Bool = false

    @Option(name: .long, help: "Stake address (or .stake.addr file) that receives the deposit back on rejection.")
    var depositReturnStakeAddress: StakeAddressInfo?

    @Option(name: .long, help: "Override the on-chain governance action deposit (lovelace). Defaults to the protocol parameter.")
    var deposit: UInt64 = 0

    @Option(name: .long, help: "Extra slots added to chain tip when computing TTL (default: 500).")
    var ttlExtra: UInt64 = 500

    @Option(name: .long, help: "Override TTL with an absolute slot (skips tip + extra computation).")
    var ttlOverride: UInt64?

    @Flag(name: .long, help: "Generate just the .action file and exit — do not build or submit a transaction.")
    var generateOnly: Bool = false

    @Option(name: .long, help: "Override the emitted .action file path. Defaults to <payer>_<type>_<timestamp>.action.")
    var actionOutFile: FilePath?
}

/// Validate the shared options' anchor pair-or-none invariant.
extension SharedGovernanceActionOptions {
    func validateAnchorFlags() throws {
        if (anchorUrl == nil) != (anchorHash == nil) {
            throw ValidationError("--anchor-url and --anchor-hash must both be provided, or neither.")
        }
    }

    /// Build an `Anchor` from the parsed flags, falling back to an interactive prompt when both
    /// are nil. The anchor is REQUIRED for every governance action type.
    mutating func resolveAnchorInteractively() async throws -> Anchor {
        try validateAnchorFlags()
        if let parsed = try parseAnchorArguments(url: anchorUrl, hash: anchorHash) {
            return parsed
        }
        // No flags — prompt. Force-required: governance actions always carry an anchor.
        let interactive = try await getOptionalAnchor(purpose: "governance action metadata")
        guard let anchor = interactive else {
            throw ValidationError("An anchor (URL + blake2b-256 hash) is required for every governance action.")
        }
        anchorUrl = anchor.anchorUrl.absoluteString
        anchorHash = anchor.anchorDataHash.payload.toHex
        return anchor
    }

    mutating func resolveDepositReturnStakeAddressInteractively() async throws -> StakeAddressInfo {
        if let addr = depositReturnStakeAddress { return addr }
        let picked = try await getStakeAddress(title: "Deposit-Return Stake Address")
        depositReturnStakeAddress = picked
        return picked
    }
}

/// Parse a hex string into a `ScriptHash` (28-byte / 56-hex). Returns nil for nil input.
func parseScriptHash(_ hex: String?) throws -> ScriptHash? {
    guard let hex = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
        return nil
    }
    let lower = hex.lowercased()
    guard lower.count == 56, lower.allSatisfy({ $0.isHexDigit }) else {
        throw ValidationError("Script hash must be 56 hex chars, got '\(hex)'.")
    }
    return ScriptHash(payload: lower.hexStringToData)
}

/// Parse a hex string into a 28-byte key/script hash, returning the lowercased hex and the
/// `CommitteeColdCredential` it represents. Throws on bad input.
func parseColdCredential(_ hex: String, isScript: Bool) throws -> (CommitteeColdCredential, String) {
    let lower = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard lower.count == 56, lower.allSatisfy({ $0.isHexDigit }) else {
        throw ValidationError("Committee credential hash must be 56 hex chars, got '\(hex)'.")
    }
    let data = lower.hexStringToData
    let credType: CredentialType = isScript
        ? .scriptHash(ScriptHash(payload: data))
        : .verificationKeyHash(VerificationKeyHash(payload: data))
    return (CommitteeColdCredential(credential: credType), lower)
}

/// Parse `numerator/denominator` (or a plain decimal) into a `UnitInterval`.
func parseUnitInterval(_ s: String) throws -> UnitInterval {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.contains("/") {
        let parts = trimmed.split(separator: "/")
        guard parts.count == 2,
              let num = UInt64(parts[0]),
              let den = UInt64(parts[1]),
              den > 0
        else {
            throw ValidationError("Could not parse rational '\(s)' — expected numerator/denominator.")
        }
        return UnitInterval(numerator: num, denominator: den)
    }
    // Plain decimal: convert to numerator over a fixed denominator.
    guard let dec = Double(trimmed), dec >= 0, dec <= 1 else {
        throw ValidationError("Could not parse '\(s)' as a unit interval (must be 0…1).")
    }
    let denom: UInt64 = 1_000_000
    let num = UInt64(dec * Double(denom))
    return UnitInterval(numerator: num, denominator: denom)
}

/// Parse a governance action ID from a CLI string in any of the three accepted forms:
/// bech32 `gov_action1…`, hex, or `txHash#index`.
func parseGovActionID(_ s: String?) throws -> GovActionID? {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
        return nil
    }
    guard let parsed = GovActionID(argument: s) else {
        throw ValidationError("Could not parse governance action ID '\(s)' — use bech32, hex, or txHash#index.")
    }
    return parsed
}
