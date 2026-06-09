import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

// MARK: - Action

/// Direction of a single-asset transaction. `mint` produces a positive `MultiAsset`
/// quantity; `burn` produces a negative one (the on-chain ledger encoding).
enum MintAction {
    case mint
    case burn

    var verb: String { self == .mint ? "Mint" : "Burn" }
    var verbLower: String { self == .mint ? "mint" : "burn" }
    var pastTense: String { self == .mint ? "minted" : "burned" }
    var fileSuffix: String { self == .mint ? "mint" : "burn" }

    /// Apply the action's sign to a positive amount.
    func signedAmount(_ amount: UInt64) -> Int64 {
        switch self {
        case .mint: return Int64(amount)
        case .burn: return -Int64(amount)
        }
    }
}

// MARK: - Policy loading (mint/burn-aware)

/// Policy artifacts loaded for a mint/burn transaction. Unlike the asset-meta
/// loader, this accepts either a software signing key (`.policy.skey`) or a
/// hardware-wallet signing file (`.policy.hwsfile`).
struct LoadedMintBurnPolicy {
    let name: String
    let policyId: String
    let nativeScript: NativeScript
    let signingKeyPath: FilePath
    let vkeyPath: FilePath
    let isHardwareWallet: Bool
    /// `nil` for sig-only policies; set when the script contains an `invalidBefore`
    /// clause (top-level or nested inside a `scriptAll`).
    let validBeforeSlot: UInt64?
}

/// Load `<name>.policy.{id,script,vkey}` plus either `.policy.skey` or `.policy.hwsfile`
/// from `dir`. Used by both `transaction mint-asset` and `transaction burn-asset`.
func loadPolicyForMintBurn(name: String, in dir: FilePath) throws -> LoadedMintBurnPolicy {
    let idFile = dir.appending("\(name).policy.id")
    let scriptFile = dir.appending("\(name).policy.script")
    let vkeyFile = dir.appending("\(name).policy.vkey")
    let skeyFile = dir.appending("\(name).policy.skey")
    let hwsFile = dir.appending("\(name).policy.hwsfile")

    do {
        try FileUtils.checkFileExists(idFile)
        try FileUtils.checkFileExists(scriptFile)
        try FileUtils.checkFileExists(vkeyFile)
    } catch {
        noora.error(.alert(
            "Policy files for '\(.primary(name))' not found in current directory.",
            takeaways: [
                "Expected: \(name).policy.id, \(name).policy.script, \(name).policy.vkey",
                "Generate a policy first with 'scm generate policy'."
            ]
        ))
        throw ExitCode.failure
    }

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
            "Missing signing key for policy '\(.primary(name))'.",
            takeaways: [
                "Expected \(name).policy.skey or \(name).policy.hwsfile alongside the .policy.id and .policy.script files."
            ]
        ))
        throw ExitCode.failure
    }

    let policyId = try FileUtils.loadFile(idFile).trimmingCharacters(in: .whitespacesAndNewlines)
    let nativeScript = try NativeScript.loadJSON(from: scriptFile.string)

    var validBeforeSlot: UInt64? = nil
    if case .scriptAll(let all) = nativeScript {
        for child in all.scripts {
            if case .invalidBefore(let before) = child {
                validBeforeSlot = before.slot
                break
            }
        }
    } else if case .invalidBefore(let before) = nativeScript {
        validBeforeSlot = before.slot
    }

    return LoadedMintBurnPolicy(
        name: name,
        policyId: policyId,
        nativeScript: nativeScript,
        signingKeyPath: signingKeyPath,
        vkeyPath: vkeyFile,
        isHardwareWallet: isHardware,
        validBeforeSlot: validBeforeSlot
    )
}

// MARK: - Positional identifier parsing

/// Split a combined `PolicyName.AssetName` token into its two parts. The asset name
/// may itself be a `{hex}` literal containing dots is not supported — we split on
/// the first unbraced `.` (mirroring the bash `11a_mintAsset.sh` convention).
/// A bare `PolicyName` (no `.`) parses as `(PolicyName, "")` — the default asset.
func splitPolicyAssetPositional(_ raw: String) -> (policyName: String, assetName: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    // Split on the first '.' that is not inside braces.
    var inBraces = false
    for (offset, ch) in trimmed.enumerated() {
        if ch == "{" { inBraces = true }
        else if ch == "}" { inBraces = false }
        else if ch == "." && !inBraces {
            let idx = trimmed.index(trimmed.startIndex, offsetBy: offset)
            let policy = String(trimmed[..<idx])
            let asset = String(trimmed[trimmed.index(after: idx)...])
            return (policy, asset)
        }
    }
    return (trimmed, "")
}

// MARK: - MultiAsset construction

/// Build a single-policy, single-asset `MultiAsset` value with the given signed
/// quantity. `signedQty` is `+amount` for mint and `-amount` for burn. Throws if the
/// policy ID is not 56 hex characters.
func buildMintMultiAsset(
    policyIdHex: String,
    assetNameHex: String,
    signedQty: Int64
) throws -> MultiAsset {
    let normalizedPolicy = policyIdHex.lowercased()
    guard normalizedPolicy.count == 56,
          normalizedPolicy.allSatisfy({ $0.isHexDigit }) else {
        noora.error(.alert(
            "Invalid policy ID: \(.danger(policyIdHex))",
            takeaways: ["Expected 56 hex characters."]
        ))
        throw ExitCode.validationFailure
    }
    let scriptHash = ScriptHash(payload: normalizedPolicy.hexStringToData)
    let assetNameData = assetNameHex.lowercased().hexStringToData
    let assetName = try AssetName(payload: assetNameData)
    var ma = MultiAsset([:])
    ma.data[scriptHash] = Asset([assetName: signedQty])
    return ma
}

// MARK: - TTL computation

/// Compute a TTL slot for a mint/burn transaction.
/// - If the policy has a `before` slot constraint, return `min(beforeSlot - 1, tip + extraSlots)`.
///   If the policy has already expired (`tip >= beforeSlot`), throw with a clear error.
/// - Otherwise return `tip + extraSlots`.
func computeMintBurnTTL(
    tipSlot: UInt64,
    policy: LoadedMintBurnPolicy,
    extraSlots: UInt64,
    action: MintAction
) throws -> UInt64 {
    let defaultTTL = tipSlot &+ extraSlots
    guard let policyBefore = policy.validBeforeSlot else { return defaultTTL }
    guard tipSlot < policyBefore else {
        noora.error(.alert(
            "Policy is no longer valid for \(action.verbLower)ing.",
            takeaways: [
                "Current slot: \(tipSlot)",
                "Policy invalid at slot: \(policyBefore)"
            ]
        ))
        throw ExitCode.failure
    }
    return min(policyBefore &- 1, defaultTTL)
}

// MARK: - Burn pre-flight

/// Sum the available quantity of `(policyId, assetName)` across the given UTxOs and
/// throw if the fee payment address holds less than `amount` tokens to burn. Mirrors
/// the pre-flight check in `11b_burnAsset.sh`.
func verifyBurnHoldings(
    utxos: [UTxO],
    policyIdHex: String,
    assetNameHex: String,
    amount: UInt64
) throws {
    let scriptHash = ScriptHash(payload: policyIdHex.lowercased().hexStringToData)
    let assetName: AssetName
    do {
        assetName = try AssetName(payload: assetNameHex.lowercased().hexStringToData)
    } catch {
        noora.error(.alert(
            "Invalid asset name hex: \(.danger(assetNameHex))",
            takeaways: ["\(error.localizedDescription)"]
        ))
        throw ExitCode.validationFailure
    }

    var available: Int64 = 0
    for utxo in utxos {
        if let perPolicy = utxo.output.amount.multiAsset.data[scriptHash],
           let qty = perPolicy.data[assetName] {
            available &+= qty
        }
    }

    guard available >= Int64(amount) else {
        noora.error(.alert(
            "Insufficient tokens to burn.",
            takeaways: [
                "Policy: \(policyIdHex)",
                "Asset name (hex): \(assetNameHex.isEmpty ? "(empty)" : assetNameHex)",
                "Available: \(available)",
                "Requested: \(amount)"
            ]
        ))
        throw ExitCode.failure
    }
}

// MARK: - Sidecar update

/// Create or update the `<policyName>.<assetDisplay>.asset` sidecar with a
/// mint/burn audit entry: `sequenceNumber` is bumped, `lastUpdate` set to now,
/// `lastAction` set to e.g. `"minted 1000 tokens"`.
func updateMintBurnSidecar(
    at path: FilePath,
    policy: LoadedMintBurnPolicy,
    assetDisplay: String,
    assetNameHex: String,
    action: MintAction,
    amount: UInt64
) throws {
    let now = rfc2822Timestamp()
    let actionLine = "\(action.pastTense) \(amount) tokens"

    if var existing = loadAssetSidecar(at: path) {
        existing.sequenceNumber += 1
        existing.lastUpdate = now
        existing.lastAction = actionLine
        try writeAssetSidecar(existing, to: path)
    } else {
        let subject = (policy.policyId + assetNameHex).lowercased()
        let sidecar = AssetSidecar(
            metaName: "",
            metaDescription: "",
            metaTicker: nil,
            metaUrl: nil,
            metaDecimals: nil,
            metaLogoPNG: nil,
            name: assetDisplay,
            hexname: assetNameHex,
            policyID: policy.policyId,
            policyValidBeforeSlot: policy.validBeforeSlot.map(String.init) ?? "unlimited",
            subject: subject,
            sequenceNumber: 0,
            lastUpdate: now,
            lastAction: actionLine
        )
        try writeAssetSidecar(sidecar, to: path)
    }
}

// MARK: - Interactive policy picker

/// Scan the current working directory for `*.policy.id` files and prompt the user
/// to pick one. Throws if none are found. Shared between `generate asset-meta`
/// and the mint/burn wizards.
func selectPolicyNameInteractive() throws -> String {
    let cwd = FilePath(FileManager.default.currentDirectoryPath)
    let policyIds = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
        .filter { $0.hasSuffix(".policy.id") }
        .map { String($0.dropLast(".policy.id".count)) }
        .sorted()

    if policyIds.isEmpty {
        noora.error(.alert(
            "No .policy.id files found in the current directory.",
            takeaways: ["Generate a policy first with 'scm generate policy'."]
        ))
        throw ExitCode.failure
    }

    return noora.singleChoicePrompt(
        title: "Policy",
        question: "Select the policy to use:",
        options: policyIds,
        description: "Loads <name>.policy.{id,script,skey|hwsfile}.",
        collapseOnSelection: true,
        filterMode: .enabled
    )
}

// MARK: - Shared executor

/// Inputs needed by `runMintOrBurn`. Held as a single struct so the call site stays
/// readable and both `MintAsset` and `BurnAsset` can share the same body.
struct MintBurnInputs {
    let action: MintAction
    let policyName: String
    let assetName: String
    let amount: UInt64
    let ttlExtra: UInt64
    let ttlOverride: UInt64?
}

extension TransactionSendable {
    /// Run the full mint-or-burn pipeline: load policy, resolve asset name, query
    /// UTxOs, optionally pre-flight burn holdings, build a balanced transaction
    /// with `txBuilder.mint`, hand off to `Sign --submit`, then update the sidecar.
    ///
    /// `outFile` is the signed transaction file path; on completion the caller can
    /// use it for display. Pass `nil` to derive a default from the fee payment address name.
    mutating func runMintOrBurn(
        inputs: MintBurnInputs,
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

        // Tokens are minted/burned at the fee payment address — destination = source.
        if transactionOptions.toAddress == nil {
            transactionOptions.toAddress = feePaymentAddress
        }

        // 1. Load policy + parse asset name
        let policy = try loadPolicyForMintBurn(name: inputs.policyName, in: cwd)
        let (assetDisplay, assetNameHex) = try parseAssetName(inputs.assetName)

        // 2. Context, params, chain state
        let context = try await getContext(config: config)
        try await printContextInfo(config: config, context: context)

        let protocolParamsFile = cwd.appending("protocol-parameters.json")
        _ = try await getProtocolParameters(
            context: context,
            protocolParamsFile: protocolParamsFile
        )

        // 3. Fetch UTxOs (with any filters the user supplied via SharedTransactionOptions)
        let utxos = try await queryAndFilterUtxos(
            feePaymentAddress: feePaymentAddress.info,
            context: context,
            config: config
        )

        // 4. Burn pre-flight
        if inputs.action == .burn {
            try verifyBurnHoldings(
                utxos: utxos,
                policyIdHex: policy.policyId,
                assetNameHex: assetNameHex,
                amount: inputs.amount
            )
        }

        // 5. TTL — explicit override wins, otherwise compute from tip + policy
        let ttl: UInt64
        if let override = inputs.ttlOverride {
            ttl = override
        } else {
            let tip = try await context.lastBlockSlot()
            ttl = try computeMintBurnTTL(
                tipSlot: UInt64(tip),
                policy: policy,
                extraSlots: inputs.ttlExtra,
                action: inputs.action
            )
        }

        // 6. Build mint MultiAsset
        let signedQty = inputs.action.signedAmount(inputs.amount)
        let mintValue = try buildMintMultiAsset(
            policyIdHex: policy.policyId,
            assetNameHex: assetNameHex,
            signedQty: signedQty
        )

        // 7. Wire up TxBuilder
        let logger = getLogger(config: config)
        let txBuilder = TxBuilder(context: context, logger: logger)
        txBuilder.mint = mintValue
        txBuilder.nativeScripts = [policy.nativeScript]
        txBuilder.ttl = SlotNumber(ttl)

        // Require the policy signer in the witness so the fee accounts for it.
        let policyVKey = try PaymentVerificationKey.load(from: policy.vkeyPath.string)
        txBuilder.requiredSigners = [try policyVKey.hash()]

        spacedPrint(
            "\n\(.primary("━━━ \(inputs.action.verb) Asset ━━━"))\n"
        )

        let assetLabel = assetNameHex.isEmpty
            ? policy.policyId
            : "\(policy.policyId).\(assetNameHex)"
        noora.info(.alert(
            "\(inputs.action.verb) \(inputs.amount) of \(.primary(assetLabel))",
            takeaways: [
                "Asset name: \(assetDisplay.isEmpty ? "(default)" : assetDisplay)",
                "Policy script: \(policy.signingKeyPath.string)",
                "TTL: slot \(ttl)\(policy.validBeforeSlot.map { " (policy valid before \($0))" } ?? "")",
                "From / change: \(feePaymentAddress.info.description)"
            ]
        ))

        // 8. Build via shared pipeline (native SwiftCardano or cardano-cli per flag)
        let timestamp = DateUtils.getCurrentTimestamp()
        let baseName = "\(feePaymentAddress.info.name!)-\(timestamp).\(inputs.action.fileSuffix)"
        let txRawFile = cwd.appending("\(baseName).raw.tx")
        let txFile = cwd.appending("\(baseName).tx")
        let txSignedFile = outFile ?? cwd.appending("\(baseName).signed.tx")
        outFile = txSignedFile

        // Witness count: payment signer + policy signer = 2 for the common case.
        try await buildTransaction(
            txBuilder: txBuilder,
            config: config,
            utxos: utxos,
            witnessOverride: 2,
            protocolParamsFile: protocolParamsFile,
            txRawFile: txRawFile,
            txFile: txFile,
            txSignedFile: txSignedFile
        )

        // 9. Sign with both keys, optionally submit. Sign auto-detects .skey vs .hwsfile.
        var args: [String] = []
        if transactionOptions.useCardanoCLI { args.append("--use-cardano-cli") }
        if transactionOptions.save          { args.append("--save") }
        if transactionOptions.submit        { args.append("--submit") }

        let paymentSigningPath = try feePaymentAddress.info.getSigningMethod().path.string

        await TransactionMainCommand.Sign.main([
            "--tx-file", txFile.string,
            "--out-file", txSignedFile.string
        ] + args + [
            "--signing-keys", paymentSigningPath,
            "--signing-keys", policy.signingKeyPath.string
        ])

        // 10. Sidecar audit entry
        let sidecarBaseName = assetDisplay.isEmpty
            ? inputs.policyName
            : "\(inputs.policyName).\(assetDisplay)"
        let sidecarPath = cwd.appending("\(sidecarBaseName).asset")
        do {
            try updateMintBurnSidecar(
                at: sidecarPath,
                policy: policy,
                assetDisplay: assetDisplay,
                assetNameHex: assetNameHex,
                action: inputs.action,
                amount: inputs.amount
            )
            noora.success(.alert(
                "\(inputs.action.verb) sidecar updated.",
                takeaways: [
                    "Path: \(.path(try AbsolutePath(validating: sidecarPath.string)))",
                    "lastAction: \"\(inputs.action.pastTense) \(inputs.amount) tokens\""
                ]
            ))
        } catch {
            noora.warning(.alert(
                "Could not update sidecar at \(sidecarPath.string).",
                takeaway: "\(error.localizedDescription)"
            ))
        }

        if !transactionOptions.save {
            try? FileManager.default.removeItem(atPath: txRawFile.string)
            try? FileManager.default.removeItem(atPath: txFile.string)
            try? FileManager.default.removeItem(atPath: txSignedFile.string)
        }
    }
}

