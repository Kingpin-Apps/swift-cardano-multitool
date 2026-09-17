import Foundation
import SwiftCardanoCore
import SwiftCardanoTxValidator
import CBORCodable

/// Turns text envelope files (and native script JSON) into a readable `TextView`.
struct TextViewDecoder {
    /// Network used to show addresses derived from keys and credentials; omitted when nil.
    var network: NetworkId?
    /// Show signing key material instead of hiding it.
    var showSecret = false
    /// Include the CBOR hex and diagnostic notation.
    var includeCBOR = false

    // MARK: - Entry points

    func view(fileData data: Data, source: String) throws -> TextView {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SwiftCardanoMultitoolError.valueError("\(source) is not a text envelope or script JSON file.")
        }

        if json["cborHex"] == nil, json["encrHex"] != nil {
            var decoded = DecodedObject()
            decoded.add("Encrypted", .bool(true))
            return TextView(
                title: "Encrypted File",
                type: json["type"] as? String ?? "",
                description: json["description"] as? String ?? "",
                decoded: decoded,
                notes: ["Decrypt it first with 'scm protect decrypt' to view its contents."]
            )
        }

        if json["cborHex"] == nil, let type = json["type"] as? String,
           ["sig", "all", "any", "atLeast", "before", "after"].contains(type) {
            let script = try HashUtils.nativeScript(fromJSON: json)
            var decoded = DecodedObject()
            decoded.add("Script Hash", try script.scriptHash().payload.toHex)
            decoded.add("Script", .object(nativeScript(script)))
            var view = TextView(title: "Native Script", type: "SimpleScript", description: "", decoded: decoded)
            if includeCBOR {
                let cbor = try script.toCBORData()
                view.cborHex = cbor.toHex
                view.cborDiagnostic = try diagnostic(cbor)
            }
            return view
        }

        let envelope = try HashUtils.Envelope(json: data, source: source)
        return try view(envelope: envelope)
    }

    func view(envelope: HashUtils.Envelope) throws -> TextView {
        var view: TextView
        do {
            view = try decode(envelope)
        } catch {
            // Show what can be shown rather than failing on a type we can't interpret.
            var decoded = DecodedObject()
            decoded.add("CBOR", TextViewFormat.decoded(try CBORDecoder().decode(CBOR.self, from: try envelope.cborData)))
            view = TextView(
                title: "Decoded CBOR",
                type: envelope.type,
                description: envelope.description,
                decoded: decoded,
                notes: ["No readable decoder for this file (\(String(describing: error))); showing the raw CBOR structure."]
            )
        }
        if includeCBOR {
            view.cborHex = envelope.cborHex
            view.cborDiagnostic = try diagnostic(try envelope.cborData)
        }
        return view
    }

    private func diagnostic(_ data: Data) throws -> String {
        TextViewFormat.diagnostic(try CBORDecoder().decode(CBOR.self, from: data))
    }

    private func decode(_ envelope: HashUtils.Envelope) throws -> TextView {
        let type = envelope.type
        func make(_ title: String, _ decoded: DecodedObject, notes: [String] = []) -> TextView {
            TextView(title: title, type: type, description: envelope.description, decoded: decoded, notes: notes)
        }

        if let role = KeyRole(envelopeType: type) {
            return try keyView(envelope: envelope, role: role)
        }

        switch type {
            case "NodeOperationalCertificate":
                return make("Operational Certificate", try operationalCertificate(envelope.cborHex))
            case "NodeOperationalCertificateIssueCounter":
                return make("Operational Certificate Issue Counter", try issueCounter(envelope.cborHex))
            case "PlutusScriptV1", "PlutusScriptV2", "PlutusScriptV3":
                let hash = try HashUtils.plutusScriptHash(envelope: envelope)
                var decoded = DecodedObject()
                decoded.add("Language", "Plutus V\(type.suffix(1))")
                decoded.add("Size", "\(try envelope.keyPayload.count) bytes")
                decoded.add("Script Hash", hash.hash)
                return make(hash.kind.capitalized, decoded)
            case "Governance voting procedures":
                return make("Governance Votes", try votes(VotingProcedures.fromCBORHex(envelope.cborHex)))
            case "Governance proposal":
                return make("Governance Proposal", try proposal(ProposalProcedure.fromCBORHex(envelope.cborHex)))
            default:
                break
        }

        if type == "Certificate" || type.hasPrefix("Certificate") || type.contains("Certificate") {
            let certificate = try Certificate.fromCBORHex(envelope.cborHex)
            return make(certificateTitle(certificate), try self.certificate(certificate))
        }
        if type.hasPrefix("TxWitness") {
            return make("Transaction Witness", try witness(VerificationKeyWitness.fromCBORHex(envelope.cborHex)))
        }
        if type.contains("TxBody") {
            let body = try TransactionBody.fromCBORHex(envelope.cborHex)
            let tx = Transaction(transactionBody: body, transactionWitnessSet: TransactionWitnessSet())
            return make("Transaction Body", try transaction(tx, bodyOnly: true))
        }
        if type.contains("Tx ") || type.hasPrefix("Tx") {
            let tx = try Transaction.fromCBORHex(envelope.cborHex)
            let witnessed = !(tx.transactionWitnessSet.vkeyWitnesses?.asList.isEmpty ?? true)
            return make(witnessed ? "Signed Transaction" : "Unsigned Transaction", try transaction(tx, bodyOnly: false))
        }

        throw SwiftCardanoMultitoolError.valueError("unsupported type '\(type)'")
    }

    // MARK: - Keys

    enum KeyRole: Equatable {
        case payment, stake, stakePool, vrf, kes, drep, committeeCold, committeeHot
        case genesis, genesisDelegate, genesisUTxO

        init?(envelopeType type: String) {
            guard type.contains("SigningKey") || type.contains("VerificationKey") else { return nil }
            // Longest prefixes first: "StakePool" before "Stake", "GenesisDelegate" before "Genesis".
            let prefixes: [(String, KeyRole)] = [
                ("StakePool", .stakePool), ("Stake", .stake), ("Payment", .payment),
                ("Vrf", .vrf), ("Kes", .kes), ("DRep", .drep),
                ("ConstitutionalCommitteeCold", .committeeCold), ("ConstitutionalCommitteeHot", .committeeHot),
                ("GenesisDelegate", .genesisDelegate), ("GenesisUTxO", .genesisUTxO), ("Genesis", .genesis),
            ]
            guard let match = prefixes.first(where: { type.hasPrefix($0.0) }) else { return nil }
            self = match.1
        }

        var name: String {
            switch self {
                case .payment: return "Payment"
                case .stake: return "Stake"
                case .stakePool: return "Stake Pool Cold"
                case .vrf: return "VRF"
                case .kes: return "KES"
                case .drep: return "DRep"
                case .committeeCold: return "Committee Cold"
                case .committeeHot: return "Committee Hot"
                case .genesis: return "Genesis"
                case .genesisDelegate: return "Genesis Delegate"
                case .genesisUTxO: return "Genesis UTxO"
            }
        }

        /// Bech32 prefix for the verification and signing key, as cardano-cli prints them.
        func bech32Prefix(signing: Bool, extended: Bool) -> String {
            let base: String
            switch self {
                case .payment: base = "addr"
                case .stake: base = "stake"
                case .stakePool: base = "pool"
                case .vrf: base = "vrf"
                case .kes: base = "kes"
                case .drep: base = "drep"
                case .committeeCold: base = "cc_cold"
                case .committeeHot: base = "cc_hot"
                case .genesis: base = "genesis"
                case .genesisDelegate: base = "genesis_delegate"
                case .genesisUTxO: base = "genesis_utxo"
            }
            return "\(base)_\(extended ? "x" : "")\(signing ? "sk" : "vk")"
        }
    }

    private func keyView(envelope: HashUtils.Envelope, role: KeyRole) throws -> TextView {
        let signing = envelope.type.contains("SigningKey")
        let extended = envelope.type.contains("Extended")
        let payload = try envelope.keyPayload

        var decoded = DecodedObject()
        decoded.add("Key Role", role.name)
        decoded.add("Key Kind", "\(extended ? "Extended " : "")\(signing ? "Signing" : "Verification") Key")

        var notes: [String] = []
        let verificationPayload: Data?
        if signing {
            if showSecret {
                decoded.add("Signing Key", bech32(role.bech32Prefix(signing: true, extended: extended), payload))
                decoded.add("Signing Key Hex", payload.toHex)
            } else {
                decoded.add("Signing Key", "hidden (use --show-secret to display)")
            }
            verificationPayload = try? derivedVerificationKey(role: role, extended: extended, payload: payload)
            if verificationPayload == nil {
                notes.append("The verification key could not be derived from this signing key.")
            }
        } else {
            verificationPayload = payload
        }

        if let verificationPayload {
            var vkey = DecodedObject()
            vkey.add("Bech32", bech32(role.bech32Prefix(signing: false, extended: extended), verificationPayload))
            vkey.add("Hex", verificationPayload.toHex)
            if extended, verificationPayload.count == 64 {
                vkey.add("Public Key", verificationPayload.prefix(32).toHex)
                vkey.add("Chain Code", verificationPayload.suffix(32).toHex)
            }
            decoded.add(signing ? "Derived Verification Key" : "Verification Key", vkey)
            decoded.append(contentsOf: try keyIdentifiers(role: role, verificationPayload: verificationPayload))
        }

        let title = "\(role.name) \(extended ? "Extended " : "")\(signing ? "Signing" : "Verification") Key"
        return TextView(title: title, type: envelope.type, description: envelope.description, decoded: decoded, notes: notes)
    }

    private func derivedVerificationKey(role: KeyRole, extended: Bool, payload: Data) throws -> Data {
        switch role {
            case .vrf:
                return try VRFSigningKey(payload: payload).toVerificationKey().payload
            case .kes:
                return try KESSigningKey(payload: payload).toVerificationKey().payload
            default:
                if extended {
                    // cardano-cli extended signing keys: 64-byte private key, 32-byte public key, 32-byte chain code.
                    guard payload.count >= 128 else {
                        throw SwiftCardanoMultitoolError.valueError("Unexpected extended signing key size.")
                    }
                    return payload.subdata(in: payload.startIndex + 64 ..< payload.startIndex + 128)
                }
                let vkey: VerificationKey = try SigningKey(payload: payload).toVerificationKey()
                return vkey.payload
        }
    }

    private func keyIdentifiers(role: KeyRole, verificationPayload: Data) throws -> DecodedObject {
        var decoded = DecodedObject()
        switch role {
            case .vrf:
                decoded.add("VRF Key Hash", try HashUtils.blake2b(verificationPayload, digestSize: 32).toHex)
                return decoded
            case .kes:
                return decoded
            default:
                break
        }

        let keyHash = VerificationKeyHash(payload: try HashUtils.blake2b(verificationPayload.prefix(32), digestSize: 28))
        switch role {
            case .payment:
                decoded.add("Key Hash", keyHash.payload.toHex)
                decoded.add("Enterprise Address", address(payment: .verificationKeyHash(keyHash)))
            case .stake:
                decoded.add("Key Hash", keyHash.payload.toHex)
                decoded.add("Stake Address", stakeAddress(.verificationKeyHash(keyHash)))
            case .stakePool:
                decoded.append(contentsOf: poolId(PoolKeyHash(payload: keyHash.payload)))
            case .drep:
                decoded.add("Key Hash", keyHash.payload.toHex)
                decoded.add("DRep ID", try DRepCredential(credential: .verificationKeyHash(keyHash)).id())
                decoded.add("DRep ID (CIP-105)", try DRep(credential: .verificationKeyHash(keyHash)).id())
            case .committeeCold:
                decoded.add("Key Hash", keyHash.payload.toHex)
                decoded.add("Committee Cold ID", try CommitteeColdCredential(credential: .verificationKeyHash(keyHash)).id())
            case .committeeHot:
                decoded.add("Key Hash", keyHash.payload.toHex)
                decoded.add("Committee Hot ID", try CommitteeHotCredential(credential: .verificationKeyHash(keyHash)).id())
            case .genesis, .genesisDelegate, .genesisUTxO:
                decoded.add("Key Hash", keyHash.payload.toHex)
            case .vrf, .kes:
                break
        }
        return decoded
    }

    // MARK: - Operational certificates

    private func operationalCertificate(_ cborHex: String) throws -> DecodedObject {
        let opcert = try OperationalCertificate.fromCBORHex(cborHex)
        var decoded = DecodedObject()
        var kes = DecodedObject()
        kes.add("Bech32", bech32("kes_vk", opcert.hotVKey.payload))
        kes.add("Hex", opcert.hotVKey.payload.toHex)
        decoded.add("KES Verification Key", kes)
        decoded.add("Issue Counter", .number(opcert.sequenceNumber))
        decoded.add("KES Period", .number(opcert.kesPeriod))
        decoded.add("Cold Key Signature", opcert.sigma.toHex)
        if let cold = opcert.coldVerificationKey {
            decoded.add("Cold Verification Key", bech32("pool_vk", cold.payload))
            decoded.append(contentsOf: poolId(try cold.poolKeyHash()))
        }
        return decoded
    }

    private func issueCounter(_ cborHex: String) throws -> DecodedObject {
        let counter = try OperationalCertificateIssueCounter.fromCBORHex(cborHex)
        var decoded = DecodedObject()
        decoded.add("Next Issue Counter", .number(counter.counterValue))
        decoded.add("Cold Verification Key", bech32("pool_vk", counter.coldVerificationKey.payload))
        decoded.append(contentsOf: poolId(try counter.coldVerificationKey.poolKeyHash()))
        return decoded
    }

    // MARK: - Certificates

    func certificateTitle(_ certificate: Certificate) -> String {
        switch certificate {
            case .stakeRegistration: return "Stake Address Registration Certificate (Shelley)"
            case .stakeDeregistration: return "Stake Address Deregistration Certificate (Shelley)"
            case .stakeDelegation: return "Stake Pool Delegation Certificate"
            case .poolRegistration: return "Stake Pool Registration Certificate"
            case .poolRetirement: return "Stake Pool Retirement Certificate"
            case .genesisKeyDelegation: return "Genesis Key Delegation Certificate"
            case .moveInstantaneousRewards: return "Move Instantaneous Rewards Certificate"
            case .register: return "Stake Address Registration Certificate"
            case .unregister: return "Stake Address Deregistration Certificate"
            case .voteDelegate: return "Vote Delegation Certificate"
            case .stakeVoteDelegate: return "Stake and Vote Delegation Certificate"
            case .stakeRegisterDelegate: return "Stake Registration and Pool Delegation Certificate"
            case .voteRegisterDelegate: return "Stake Registration and Vote Delegation Certificate"
            case .stakeVoteRegisterDelegate: return "Stake Registration, Pool and Vote Delegation Certificate"
            case .authCommitteeHot: return "Committee Hot Key Authorization Certificate"
            case .resignCommitteeCold: return "Committee Cold Key Resignation Certificate"
            case .registerDRep: return "DRep Registration Certificate"
            case .unRegisterDRep: return "DRep Retirement Certificate"
            case .updateDRep: return "DRep Update Certificate"
        }
    }

    func certificate(_ certificate: Certificate) throws -> DecodedObject {
        var decoded = DecodedObject()
        switch certificate {
            case .stakeRegistration(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
            case .stakeDeregistration(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
            case .stakeDelegation(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.append(contentsOf: poolId(cert.poolKeyHash))
            case .poolRegistration(let cert):
                decoded.append(contentsOf: poolParams(cert.poolParams))
            case .poolRetirement(let cert):
                decoded.append(contentsOf: poolId(cert.poolKeyHash))
                decoded.add("Retirement Epoch", .number(cert.epoch))
            case .genesisKeyDelegation(let cert):
                decoded.add("Genesis Key Hash", cert.genesisHash.payload.toHex)
                decoded.add("Genesis Delegate Key Hash", cert.genesisDelegateHash.payload.toHex)
                decoded.add("VRF Key Hash", cert.vrfKeyHash.payload.toHex)
            case .moveInstantaneousRewards(let cert):
                let mir = cert.moveInstantaneousRewards
                decoded.add("Source", mir.source == .reserves ? "Reserves" : "Treasury")
                if let coin = mir.coin {
                    decoded.add("Transfer to Other Pot", ada(coin))
                }
                if let rewards = mir.rewards {
                    var map = DecodedObject()
                    for (credential, delta) in rewards.sorted(by: { $0.key < $1.key }) {
                        map.add(credential, "\(delta.deltaCoin) lovelace", key: credential)
                    }
                    decoded.add("Rewards", map)
                }
            case .register(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.add("Deposit", ada(cert.coin))
            case .unregister(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.add("Deposit Refund", ada(cert.coin))
            case .voteDelegate(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.add("DRep", try drep(cert.drep))
            case .stakeVoteDelegate(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.append(contentsOf: poolId(cert.poolKeyHash))
                decoded.add("DRep", try drep(cert.drep))
            case .stakeRegisterDelegate(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.append(contentsOf: poolId(cert.poolKeyHash))
                decoded.add("Deposit", ada(cert.coin))
            case .voteRegisterDelegate(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.add("DRep", try drep(cert.drep))
                decoded.add("Deposit", ada(cert.coin))
            case .stakeVoteRegisterDelegate(let cert):
                decoded.add("Stake Credential", stakeCredential(cert.stakeCredential))
                decoded.append(contentsOf: poolId(cert.poolKeyHash))
                decoded.add("DRep", try drep(cert.drep))
                decoded.add("Deposit", ada(cert.coin))
            case .authCommitteeHot(let cert):
                decoded.add("Committee Cold Credential", try governanceCredential(cert.committeeColdCredential))
                decoded.add("Committee Hot Credential", try governanceCredential(cert.committeeHotCredential))
            case .resignCommitteeCold(let cert):
                decoded.add("Committee Cold Credential", try governanceCredential(cert.committeeColdCredential))
                decoded.add("Anchor", anchor(cert.anchor))
            case .registerDRep(let cert):
                decoded.add("DRep Credential", try governanceCredential(cert.drepCredential))
                decoded.add("Deposit", ada(cert.coin))
                decoded.add("Anchor", anchor(cert.anchor))
            case .unRegisterDRep(let cert):
                decoded.add("DRep Credential", try governanceCredential(cert.drepCredential))
                decoded.add("Deposit Refund", ada(cert.coin))
            case .updateDRep(let cert):
                decoded.add("DRep Credential", try governanceCredential(cert.drepCredential))
                decoded.add("Anchor", anchor(cert.anchor))
        }
        return decoded
    }

    private func poolParams(_ params: PoolParams) -> DecodedObject {
        var decoded = poolId(params.poolOperator)
        decoded.add("VRF Key Hash", params.vrfKeyHash.payload.toHex)
        decoded.add("Pledge", ada(params.pledge))
        decoded.add("Cost", ada(params.cost))
        decoded.add("Margin", "\(PoolParamsFormat.margin(params.margin)) (\(params.margin.numerator)/\(params.margin.denominator))")
        decoded.add("Reward Account", PoolParamsFormat.rewardAccount(params.rewardAccount))
        decoded.add("Owners", .array(params.poolOwners.asArray.map { owner in
            var object = DecodedObject()
            object.add("Key Hash", owner.payload.toHex)
            object.add("Stake Address", stakeAddress(.verificationKeyHash(owner)))
            return .object(object)
        }))
        decoded.add("Relays", .array((params.relays ?? []).map { .string(PoolRelay(relay: $0).displayString) }))
        if let metadata = params.poolMetadata {
            var object = DecodedObject()
            object.add("URL", metadata.url?.absoluteString)
            object.add("Hash", metadata.poolMetadataHash?.payload.toHex)
            decoded.add("Metadata", object)
        } else {
            decoded.add("Metadata", .null)
        }
        return decoded
    }

    // MARK: - Governance

    private func votes(_ procedures: VotingProcedures) throws -> DecodedObject {
        let votes = try procedures.allVotes.map { voter, actionId, procedure -> (String, DecodedValue) in
            var object = DecodedObject()
            object.add("Voter", try self.voter(voter))
            object.add("Governance Action", try govActionId(actionId))
            object.add("Vote", voteText(procedure.vote))
            object.add("Anchor", anchor(procedure.anchor))
            let sortKey = "\(voter.credential)-\(actionId.transactionID.payload.toHex)#\(actionId.govActionIndex)"
            return (sortKey, .object(object))
        }
        var decoded = DecodedObject()
        decoded.add("Votes", .array(votes.sorted { $0.0 < $1.0 }.map(\.1)))
        return decoded
    }

    private func voteText(_ vote: Vote) -> String {
        switch vote {
            case .yes: return "Yes"
            case .no: return "No"
            case .abstain: return "Abstain"
        }
    }

    private func voter(_ voter: Voter) throws -> DecodedObject {
        var object = DecodedObject()
        switch voter.credential {
            case .constitutionalCommitteeHotKeyhash(let hash):
                object.add("Role", "Constitutional Committee (hot key)")
                object.add("ID", try CommitteeHotCredential(credential: .verificationKeyHash(hash)).id())
                object.add("Key Hash", hash.payload.toHex)
            case .constitutionalCommitteeHotScriptHash(let hash):
                object.add("Role", "Constitutional Committee (hot script)")
                object.add("ID", try CommitteeHotCredential(credential: .scriptHash(hash)).id())
                object.add("Script Hash", hash.payload.toHex)
            case .drepKeyhash(let hash):
                object.add("Role", "DRep (key)")
                object.add("ID", try DRepCredential(credential: .verificationKeyHash(hash)).id())
                object.add("Key Hash", hash.payload.toHex)
            case .drepScriptHash(let hash):
                object.add("Role", "DRep (script)")
                object.add("ID", try DRepCredential(credential: .scriptHash(hash)).id())
                object.add("Script Hash", hash.payload.toHex)
            case .stakePoolKeyhash(let hash):
                object.add("Role", "Stake Pool")
                object.append(contentsOf: poolId(PoolKeyHash(payload: hash.payload)))
        }
        return object
    }

    private func govActionId(_ id: GovActionID?) throws -> DecodedValue {
        guard let id else { return .null }
        var object = DecodedObject()
        object.add("ID", try id.toBech32())
        object.add("Transaction", "\(id.transactionID.payload.toHex)#\(id.govActionIndex)")
        return .object(object)
    }

    private func proposal(_ proposal: ProposalProcedure) throws -> DecodedObject {
        var decoded = DecodedObject()
        decoded.add("Deposit", ada(proposal.deposit))
        decoded.add("Deposit Return Address", rewardAddress(proposal.rewardAccount))
        decoded.add("Anchor", anchor(proposal.anchor))

        var action = DecodedObject()
        switch proposal.govAction {
            case .parameterChangeAction(let change):
                action.add("Type", "Protocol Parameter Change")
                action.add("Previous Action", try govActionId(change.id))
                action.add("Guardrail Script Hash", change.policyHash.map { .string($0.payload.toHex) } ?? .null)
                action.add("Parameter Updates", reflectedFields(change.protocolParamUpdate))
            case .hardForkInitiationAction(let fork):
                action.add("Type", "Hard Fork Initiation")
                action.add("Previous Action", try govActionId(fork.id))
                action.add("Protocol Version", "\(fork.protocolVersion.major.map(String.init) ?? "?").\(fork.protocolVersion.minor.map(String.init) ?? "?")")
            case .treasuryWithdrawalsAction(let withdrawals):
                action.add("Type", "Treasury Withdrawals")
                var map = DecodedObject()
                for (account, coin) in withdrawals.withdrawals.sorted(by: { $0.key.toHex < $1.key.toHex }) {
                    let address = rewardAddress(account)
                    map.add(address, ada(coin), key: address)
                }
                action.add("Withdrawals", map)
                action.add("Guardrail Script Hash", withdrawals.policyHash.map { .string($0.payload.toHex) } ?? .null)
            case .noConfidence(let noConfidence):
                action.add("Type", "No Confidence")
                action.add("Previous Action", try govActionId(noConfidence.id))
            case .updateCommittee(let update):
                action.add("Type", "Update Committee")
                action.add("Previous Action", try govActionId(update.id))
                action.add("Remove Members", .array(try update.coldCredentials
                    .map { try $0.id() }
                    .sorted()
                    .map(DecodedValue.string)))
                action.add("Add Members", .array(try update.credentialEpochs
                    .map { credential, epoch in (try credential.id(), epoch) }
                    .sorted { $0.0 < $1.0 }
                    .map { id, epoch in
                        var member = DecodedObject()
                        member.add("ID", id)
                        member.add("Expiry Epoch", .number(epoch))
                        return .object(member)
                    }))
                action.add("Quorum", "\(update.interval.numerator)/\(update.interval.denominator)")
            case .newConstitution(let constitution):
                action.add("Type", "New Constitution")
                action.add("Previous Action", try govActionId(constitution.id))
                action.add("Constitution Anchor", anchor(constitution.constitution.anchor))
                action.add("Guardrail Script Hash", constitution.constitution.scriptHash.map { .string($0.payload.toHex) } ?? .null)
            case .infoAction:
                action.add("Type", "Info")
        }
        decoded.add("Action", action)
        return decoded
    }

    /// Non-nil stored properties of a value, for types too large to lay out by hand.
    private func reflectedFields(_ value: Any) -> DecodedValue {
        var object = DecodedObject()
        for child in Mirror(reflecting: value).children {
            guard let label = child.label else { continue }
            let mirror = Mirror(reflecting: child.value)
            let unwrapped: Any
            if mirror.displayStyle == .optional {
                guard let some = mirror.children.first?.value else { continue }
                unwrapped = some
            } else {
                unwrapped = child.value
            }
            let name = label.hasPrefix("_") ? String(label.dropFirst()) : label
            object.add(name, String(describing: unwrapped), key: name)
        }
        return .object(object)
    }

    // MARK: - Witnesses and transactions

    private func witness(_ witness: VerificationKeyWitness) throws -> DecodedObject {
        var decoded = DecodedObject()
        let vkey = witness.vkey.payload
        decoded.add("Verification Key", vkey.toHex)
        decoded.add("Key Hash", try HashUtils.verificationKeyHash(payload: vkey))
        decoded.add("Signature", witness.signature.toHex)
        return decoded
    }

    private func transaction(_ tx: Transaction, bodyOnly: Bool) throws -> DecodedObject {
        let body = tx.transactionBody
        let view = try TxValidator().inspect(transaction: tx)
        var decoded = DecodedObject()

        decoded.add("Transaction ID", body.id.payload.toHex)
        if !bodyOnly {
            decoded.add("Valid", .bool(tx.valid))
        }
        decoded.add("Fee", ada(body.fee))
        decoded.add("Network ID", body.networkId.map { .string($0 == 1 ? "Mainnet (1)" : "Testnet (\($0))") })
        if body.validityStart != nil || body.ttl != nil {
            var validity = DecodedObject()
            validity.add("From Slot", body.validityStart.map { .number($0) } ?? .null)
            validity.add("Until Slot", body.ttl.map { .number($0) } ?? .null)
            decoded.add("Validity Interval", validity)
        }

        decoded.add("Inputs", .array(view.inputs.map(DecodedValue.string)))
        if !view.referenceInputs.isEmpty {
            decoded.add("Reference Inputs", .array(view.referenceInputs.map(DecodedValue.string)))
        }
        if !view.collateralInputs.isEmpty {
            decoded.add("Collateral Inputs", .array(view.collateralInputs.map(DecodedValue.string)))
        }
        decoded.add("Outputs", .array(view.outputs.map(output)))
        if let collateralReturn = view.collateralReturn {
            decoded.add("Collateral Return", output(collateralReturn))
        }
        if let totalCollateral = body.totalCollateral {
            decoded.add("Total Collateral", ada(totalCollateral))
        }
        if let mint = view.mint, !mint.isEmpty {
            decoded.add("Mint", assets(mint))
        }
        if let certificates = body.certificates?.asList, !certificates.isEmpty {
            decoded.add("Certificates", .array(try certificates.map { certificate in
                var object = DecodedObject()
                object.add("Certificate", certificateTitle(certificate))
                object.append(contentsOf: try self.certificate(certificate))
                return .object(object)
            }))
        }
        if let withdrawals = body.withdrawals, !withdrawals.data.isEmpty {
            var map = DecodedObject()
            for (account, coin) in withdrawals.data {
                let address = rewardAddress(account)
                map.add(address, ada(coin), key: address)
            }
            decoded.add("Withdrawals", map)
        }
        if let votingProcedures = body.votingProcedures, !votingProcedures.isEmpty {
            decoded.append(contentsOf: try votes(votingProcedures))
        }
        if let proposals = body.proposalProcedures {
            decoded.add("Proposals", .array(try proposals.elementsOrdered.map { .object(try proposal($0)) }))
        }
        if let donation = body.treasuryDonation {
            decoded.add("Treasury Donation", ada(UInt64(donation.value)))
        }
        if !view.requiredSigners.isEmpty {
            decoded.add("Required Signers", .array(view.requiredSigners.map(DecodedValue.string)))
        }
        decoded.add("Script Data Hash", view.scriptDataHash)
        decoded.add("Auxiliary Data Hash", view.auxiliaryDataHash)

        if !bodyOnly {
            let witnesses = tx.transactionWitnessSet
            var witnessObject = DecodedObject()
            witnessObject.add("Key Witnesses", .array(try (witnesses.vkeyWitnesses?.asList ?? []).map { witness in
                .string(try HashUtils.verificationKeyHash(payload: witness.vkey.payload))
            }))
            let counts: [(String, Int)] = [
                ("Native Scripts", witnesses.nativeScripts?.asList.count ?? 0),
                ("Plutus V1 Scripts", witnesses.plutusV1Script?.asList.count ?? 0),
                ("Plutus V2 Scripts", witnesses.plutusV2Script?.asList.count ?? 0),
                ("Plutus V3 Scripts", witnesses.plutusV3Script?.asList.count ?? 0),
                ("Datums", witnesses.plutusData?.asList.count ?? 0),
                ("Redeemers", view.redeemerCount),
                ("Bootstrap Witnesses", witnesses.bootstrapWitness?.asList.count ?? 0),
            ]
            for (label, count) in counts where count > 0 {
                witnessObject.add(label, .number(count))
            }
            decoded.add("Witnesses", witnessObject)
            decoded.add("Metadata", .bool(tx.auxiliaryData != nil))
        }
        return decoded
    }

    private func output(_ output: OutputView) -> DecodedValue {
        var object = DecodedObject()
        object.add("Address", output.address)
        object.add("Amount", ada(output.lovelace))
        if let multiAsset = output.multiAsset, !multiAsset.isEmpty {
            object.add("Assets", assets(multiAsset))
        }
        if output.hasInlineDatum { object.add("Inline Datum", .bool(true)) }
        if output.hasDatumHash { object.add("Datum Hash", .bool(true)) }
        if output.hasScriptRef { object.add("Reference Script", .bool(true)) }
        return .object(object)
    }

    private func assets(_ policies: [String: [String: Int64]]) -> DecodedValue {
        .array(policies.sorted { $0.key < $1.key }.flatMap { policy, names in
            names.sorted { $0.key < $1.key }.map { name, amount -> DecodedValue in
                .string("\(amount) \(policy).\(name)")
            }
        })
    }

    // MARK: - Native scripts

    func nativeScript(_ script: NativeScript) -> DecodedObject {
        var object = DecodedObject()
        switch script {
            case .scriptPubkey(let sig):
                object.add("Type", "Signature")
                object.add("Key Hash", sig.keyHash.payload.toHex)
            case .scriptAll(let all):
                object.add("Type", "All of")
                object.add("Scripts", .array(all.scripts.map { .object(nativeScript($0)) }))
            case .scriptAny(let any):
                object.add("Type", "Any of")
                object.add("Scripts", .array(any.scripts.map { .object(nativeScript($0)) }))
            case .scriptNofK(let nOfK):
                object.add("Type", "At least \(nOfK.required) of \(nOfK.scripts.count)")
                object.add("Required", .number(nOfK.required))
                object.add("Scripts", .array(nOfK.scripts.map { .object(nativeScript($0)) }))
            case .invalidBefore(let after):
                object.add("Type", "Valid from slot")
                object.add("Slot", .number(after.slot))
            case .invalidHereAfter(let before):
                object.add("Type", "Valid before slot")
                object.add("Slot", .number(before.slot))
        }
        return object
    }

    // MARK: - Shared pieces

    private func bech32(_ hrp: String, _ payload: Data) -> String {
        Bech32().encode(hrp: hrp, witprog: payload) ?? payload.toHex
    }

    /// `170000000` → `"170 ADA (170000000 lovelace)"`, exact and without abbreviation.
    static func ada<T: BinaryInteger>(_ lovelace: T) -> String {
        let magnitude = UInt64(clamping: lovelace.magnitude)
        let grouped = NumberFormatter()
        grouped.numberStyle = .decimal
        grouped.locale = Locale(identifier: "en_US_POSIX")
        grouped.usesGroupingSeparator = true
        grouped.groupingSeparator = ","
        let whole = grouped.string(from: NSNumber(value: magnitude / 1_000_000)) ?? String(magnitude / 1_000_000)
        var fraction = String(format: "%06llu", magnitude % 1_000_000)
        while fraction.hasSuffix("0") { fraction.removeLast() }
        let sign = lovelace < 0 ? "-" : ""
        return "\(sign)\(whole)\(fraction.isEmpty ? "" : ".\(fraction)") ADA (\(lovelace) lovelace)"
    }

    private func ada<T: BinaryInteger>(_ lovelace: T) -> String {
        Self.ada(lovelace)
    }

    private func poolId(_ hash: PoolKeyHash) -> DecodedObject {
        var decoded = DecodedObject()
        decoded.add("Pool ID", (try? PoolOperator(poolKeyHash: hash).toBech32()) ?? hash.payload.toHex)
        decoded.add("Pool ID Hex", hash.payload.toHex)
        return decoded
    }

    private func stakeCredential(_ credential: StakeCredential) -> DecodedObject {
        var object = DecodedObject()
        switch credential.credential {
            case .verificationKeyHash(let hash):
                object.add("Type", "Key hash")
                object.add("Hash", hash.payload.toHex)
                object.add("Stake Address", stakeAddress(.verificationKeyHash(hash)))
            case .scriptHash(let hash):
                object.add("Type", "Script hash")
                object.add("Hash", hash.payload.toHex)
                object.add("Stake Address", stakeAddress(.scriptHash(hash)))
        }
        return object
    }

    private func governanceCredential<C: GovernanceCredential>(_ credential: C) throws -> DecodedObject {
        var object = DecodedObject()
        object.add("ID", try credential.id())
        switch credential.credential {
            case .verificationKeyHash(let hash):
                object.add("Key Hash", hash.payload.toHex)
            case .scriptHash(let hash):
                object.add("Script Hash", hash.payload.toHex)
        }
        return object
    }

    private func drep(_ drep: DRep) throws -> DecodedValue {
        switch drep.credential {
            case .alwaysAbstain:
                return .string("Always abstain")
            case .alwaysNoConfidence:
                return .string("Always no confidence")
            case .verificationKeyHash(let hash):
                return .object(try governanceCredential(DRepCredential(credential: .verificationKeyHash(hash))))
            case .scriptHash(let hash):
                return .object(try governanceCredential(DRepCredential(credential: .scriptHash(hash))))
        }
    }

    private func anchor(_ anchor: Anchor?) -> DecodedValue {
        guard let anchor else { return .null }
        var object = DecodedObject()
        object.add("URL", anchor.anchorUrl.absoluteString)
        object.add("Hash", anchor.anchorDataHash.payload.toHex)
        return .object(object)
    }

    private func address(payment: PaymentPart) -> String? {
        guard let network else { return nil }
        return try? Address(paymentPart: payment, network: network).toBech32()
    }

    private func stakeAddress(_ staking: StakingPart) -> String? {
        guard let network else { return nil }
        return try? Address(stakingPart: staking, network: network).toBech32()
    }

    private func rewardAddress(_ account: Data) -> String {
        (try? Address(from: .bytes(account)).toBech32()) ?? account.toHex
    }
}
