import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftNaCl
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Editable pool parameters

/// A mutable copy of a pool's registration parameters, e.g. fetched from on-chain,
/// that can be edited field by field and turned back into `PoolParams`.
///
/// Owners, reward account and VRF key are kept as hashes, so a registration
/// certificate can be built without any of the corresponding key files.
struct PoolParamsDraft: Equatable {
    var poolKeyHash: PoolKeyHash
    var vrfKeyHash: VrfKeyHash
    var pledge: Int
    var cost: Int
    var margin: UnitInterval
    var rewardAccount: RewardAccountHash
    var owners: [VerificationKeyHash]
    var relays: [PoolRelay]
    var metadataUrl: String?
    var metadataHash: String?

    /// Off-chain metadata content (name, ticker, ...). Not part of the certificate.
    var metadataName: String?
    var metadataDescription: String?
    var metadataTicker: String?
    var metadataHomepage: String?

    /// Whether the metadata content was edited and a new metadata.json must be written.
    var metadataContentEdited = false

    init(params: PoolParams) {
        self.poolKeyHash = params.poolOperator
        self.vrfKeyHash = params.vrfKeyHash
        self.pledge = params.pledge
        self.cost = params.cost
        // Backends that report margin as a decimal return unreduced fractions
        // (e.g. 10000000/100000000); reduce so certificates encode it canonically.
        self.margin = Self.reduced(params.margin)
        self.rewardAccount = params.rewardAccount
        self.owners = params.poolOwners.asArray
        self.relays = (params.relays ?? []).map { PoolRelay(relay: $0) }
        self.metadataUrl = params.poolMetadata?.url?.absoluteString
        self.metadataHash = params.poolMetadata?.poolMetadataHash?.payload.toHex
        self.metadataName = params.poolMetadata?.name
        self.metadataDescription = params.poolMetadata?.desc
        self.metadataTicker = params.poolMetadata?.ticker
        self.metadataHomepage = params.poolMetadata?.homepage?.absoluteString
    }

    static func == (lhs: PoolParamsDraft, rhs: PoolParamsDraft) -> Bool {
        lhs.poolKeyHash.payload == rhs.poolKeyHash.payload
            && lhs.vrfKeyHash.payload == rhs.vrfKeyHash.payload
            && lhs.pledge == rhs.pledge
            && lhs.cost == rhs.cost
            && Decimal(lhs.margin.numerator) / Decimal(max(lhs.margin.denominator, 1))
                == Decimal(rhs.margin.numerator) / Decimal(max(rhs.margin.denominator, 1))
            && lhs.rewardAccount.payload == rhs.rewardAccount.payload
            && Set(lhs.owners.map(\.payload)) == Set(rhs.owners.map(\.payload))
            && (try? lhs.relays.map { try $0.toRelay().toCBORData() }) == (try? rhs.relays.map { try $0.toRelay().toCBORData() })
            && lhs.metadataUrl == rhs.metadataUrl
            && lhs.metadataHash == rhs.metadataHash
    }

    static func reduced(_ interval: UnitInterval) -> UnitInterval {
        func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 { b == 0 ? a : gcd(b, a % b) }
        let divisor = gcd(interval.numerator, interval.denominator)
        guard divisor > 1 else { return interval }
        return UnitInterval(numerator: interval.numerator / divisor, denominator: interval.denominator / divisor)
    }

    var poolOperator: PoolOperator { PoolOperator(poolKeyHash: poolKeyHash) }

    /// The stake key hash of the reward account, if it is key-based.
    var rewardStakeKeyHash: VerificationKeyHash? {
        guard let address = try? Address(from: .bytes(rewardAccount.payload)),
              case .verificationKeyHash(let hash) = address.stakingPart else {
            return nil
        }
        return hash
    }

    func toPoolParams() throws -> PoolParams {
        var seen = Set<Data>()
        let uniqueOwners = owners.filter { seen.insert($0.payload).inserted }

        var poolMetadata: PoolMetadata? = nil
        if let metadataUrl, let metadataHash {
            poolMetadata = try PoolMetadata(
                url: try Url(metadataUrl),
                poolMetadataHash: PoolMetadataHash(payload: metadataHash.hexStringToData)
            )
        }

        return PoolParams(
            poolOperator: poolKeyHash,
            vrfKeyHash: vrfKeyHash,
            pledge: pledge,
            cost: cost,
            margin: margin,
            rewardAccount: rewardAccount,
            poolOwners: .orderedSet(try OrderedSet(uniqueOwners)),
            relays: relays.isEmpty ? nil : try relays.map { try $0.toRelay() },
            poolMetadata: poolMetadata
        )
    }

    /// Validate the parameters against ledger rules and the protocol parameters.
    func validate(minPoolCost: Int) throws {
        if cost < minPoolCost {
            throw SwiftCardanoMultitoolError.valueError(
                "Cost \(lovelaceToAdaFormatString(UInt64(cost))) is below the minimum pool cost of \(lovelaceToAdaFormatString(UInt64(minPoolCost)))."
            )
        }
        if margin.numerator > margin.denominator {
            throw SwiftCardanoMultitoolError.valueError("Margin must be between 0% and 100%.")
        }
        if owners.isEmpty {
            throw SwiftCardanoMultitoolError.valueError("A pool needs at least one owner.")
        }
        if (metadataUrl == nil) != (metadataHash == nil) {
            throw SwiftCardanoMultitoolError.valueError("Metadata URL and metadata hash must be set together.")
        }
        if let metadataUrl, metadataUrl.utf8.count > 64 {
            throw SwiftCardanoMultitoolError.valueError("Metadata URL must be 64 bytes or less.")
        }
        if let metadataHash, metadataHash.hexStringToData.count != 32 {
            throw SwiftCardanoMultitoolError.valueError("Metadata hash must be 32 bytes (64 hex characters).")
        }
        for (index, relay) in relays.enumerated() {
            try relay.validateRelayEntry(index: index)
            _ = try relay.toRelay()
        }
    }
}

// MARK: - Formatting

enum PoolParamsFormat {
    static func margin(_ margin: UnitInterval) -> String {
        guard margin.denominator > 0 else { return "-" }
        let percent = Decimal(margin.numerator) * 100 / Decimal(margin.denominator)
        var rounded = Decimal()
        var copy = percent
        NSDecimalRound(&rounded, &copy, 4, .plain)
        return "\(rounded)%"
    }

    static func ada(_ lovelace: Int) -> String {
        "\(lovelaceToAdaFormatString(UInt64(max(lovelace, 0)))) (\(lovelace) lovelace)"
    }

    static func rewardAccount(_ account: RewardAccountHash) -> String {
        (try? Address(from: .bytes(account.payload)).toBech32()) ?? account.payload.toHex
    }

    /// Parse a margin such as `0.05`, `5%` or `1/3` into an exact unit interval.
    static func parseMargin(_ input: String) -> UnitInterval? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let slash = trimmed.firstIndex(of: "/") {
            guard let num = UInt64(trimmed[..<slash].trimmingCharacters(in: .whitespaces)),
                  let den = UInt64(trimmed[trimmed.index(after: slash)...].trimmingCharacters(in: .whitespaces)),
                  den > 0, num <= den else { return nil }
            return UnitInterval(numerator: num, denominator: den)
        }

        let isPercent = trimmed.hasSuffix("%")
        let numberString = isPercent ? String(trimmed.dropLast()) : trimmed
        guard var value = Decimal(string: numberString, locale: Locale(identifier: "en_US_POSIX")),
              !numberString.isEmpty else { return nil }
        if isPercent { value /= 100 }
        guard value >= 0, value <= 1 else { return nil }

        var denominator: UInt64 = 1
        var scaled = value
        while scaled != Decimal(NSDecimalNumber(decimal: scaled).uint64Value), denominator < 1_000_000_000_000_000 {
            scaled *= 10
            denominator *= 10
        }
        let numerator = NSDecimalNumber(decimal: scaled).uint64Value
        func gcd(_ a: UInt64, _ b: UInt64) -> UInt64 { b == 0 ? a : gcd(b, a % b) }
        let divisor = max(gcd(numerator, denominator), 1)
        return UnitInterval(numerator: numerator / divisor, denominator: denominator / divisor)
    }

    /// Print the parameters, marking fields that differ from `original`.
    static func printSummary(
        _ draft: PoolParamsDraft,
        title: String,
        original: PoolParamsDraft? = nil,
        keys: PoolKeyFileMatcher? = nil
    ) {
        func line(_ label: String, _ value: String, _ previous: String?) -> String {
            let padded = label.padding(toLength: 16, withPad: " ", startingAt: 0)
            if let previous, previous != value {
                return "  \(padded)\(noora.format("\(.accent(value))"))  (was \(previous))"
            }
            return "  \(padded)\(noora.format("\(.primary(value))"))"
        }
        func ownerLabel(_ hash: VerificationKeyHash) -> String {
            let name = keys?.stakeVkey(for: hash).flatMap { PoolKeyFileMatcher.keyName($0) }
            return name.map { "\($0) (\(hash.payload.toHex))" } ?? hash.payload.toHex
        }

        var lines: [String] = [noora.format("\n\(.primary("━━━ \(title) ━━━"))")]
        lines.append(line("Pool ID:", (try? draft.poolOperator.toBech32()) ?? draft.poolKeyHash.payload.toHex, nil))
        lines.append(line("Pledge:", ada(draft.pledge), original.map { ada($0.pledge) }))
        lines.append(line("Cost:", ada(draft.cost), original.map { ada($0.cost) }))
        lines.append(line("Margin:", margin(draft.margin), original.map { margin($0.margin) }))
        lines.append(line("Reward account:", rewardAccount(draft.rewardAccount), original.map { rewardAccount($0.rewardAccount) }))
        lines.append(line("VRF key hash:", draft.vrfKeyHash.payload.toHex, original.map { $0.vrfKeyHash.payload.toHex }))

        let owners = draft.owners.map(ownerLabel).joined(separator: ", ")
        lines.append(line("Owners:", owners, original.map { $0.owners.map(ownerLabel).joined(separator: ", ") }))

        let relays = draft.relays.isEmpty ? "none" : draft.relays.map(\.displayString).joined(separator: ", ")
        let previousRelays = original.map { $0.relays.isEmpty ? "none" : $0.relays.map(\.displayString).joined(separator: ", ") }
        lines.append(line("Relays:", relays, previousRelays))

        lines.append(line("Metadata URL:", draft.metadataUrl ?? "none", original.map { $0.metadataUrl ?? "none" }))
        lines.append(line("Metadata hash:", draft.metadataHash ?? "none", original.map { $0.metadataHash ?? "none" }))
        if draft.metadataName != nil || draft.metadataTicker != nil {
            lines.append(line("Name:", draft.metadataName ?? "-", original.map { $0.metadataName ?? "-" }))
            lines.append(line("Ticker:", draft.metadataTicker ?? "-", original.map { $0.metadataTicker ?? "-" }))
            lines.append(line("Description:", draft.metadataDescription ?? "-", original.map { $0.metadataDescription ?? "-" }))
            lines.append(line("Homepage:", draft.metadataHomepage ?? "-", original.map { $0.metadataHomepage ?? "-" }))
        }
        print(lines.joined(separator: "\n"))
    }
}

// MARK: - Fetching on-chain params

/// Fetch a pool's registered parameters, filling in the off-chain metadata content
/// (name, ticker, ...) when the backend only returned the metadata URL and hash.
func fetchOnChainPoolParams(
    context: any ChainContext,
    poolOperator: PoolOperator
) async throws -> (info: StakePoolInfo, draft: PoolParamsDraft) {
    let poolId = try poolOperator.toBech32()
    let info = try await noora.progressStep(
        message: "Fetching registered parameters for \(poolId) via \(context.name)...",
        successMessage: "Fetched on-chain pool parameters.",
        errorMessage: "Could not fetch the pool's on-chain parameters.",
        showSpinner: true
    ) { _ in
        try await withRetry() {
            try await context.stakePoolInfo(poolId: poolId)
        }
    }

    var draft = PoolParamsDraft(params: info.poolParams)
    if draft.metadataName == nil, draft.metadataTicker == nil,
       let url = draft.metadataUrl, let hash = draft.metadataHash {
        do {
            let metadata = try await PoolMetadata.fetch(
                url: try Url(url),
                poolMetadataHash: PoolMetadataHash(payload: hash.hexStringToData)
            )
            draft.metadataName = metadata.name
            draft.metadataDescription = metadata.desc
            draft.metadataTicker = metadata.ticker
            draft.metadataHomepage = metadata.homepage?.absoluteString
        } catch {
            noora.warning(.alert(
                "Could not read the pool metadata at \(url).",
                takeaway: "The metadata URL and hash are kept as registered. \(error)"
            ))
        }
    }
    return (info, draft)
}

/// Blake2b-256 hash of a metadata file's exact bytes, as registered on-chain.
func poolMetadataHash(of data: Data) throws -> String {
    guard data.count <= 512 else {
        throw SwiftCardanoMultitoolError.valueError("Pool metadata must be 512 bytes or less (got \(data.count)).")
    }
    return try SwiftNaCl.Hash().blake2b(data: data, digestSize: 32, encoder: RawEncoder.self).toHex
}

/// Download a metadata file and return its hash.
func downloadPoolMetadataHash(url: String) async throws -> String {
    guard let requestURL = URL(string: url) else {
        throw SwiftCardanoMultitoolError.valueError("Invalid metadata URL: \(url)")
    }
    let (data, _) = try await URLSession.shared.data(from: requestURL)
    return try poolMetadataHash(of: data)
}

// MARK: - Local key file matching

/// Finds key files in a directory that belong to a pool's on-chain hashes, so
/// on-chain params can be linked to local files without the user naming them.
struct PoolKeyFileMatcher {
    private struct KeyFile {
        let path: FilePath
        let type: String
        let cborHex: String
    }

    private let files: [KeyFile]
    private let directory: FilePath

    init(directory: FilePath = FilePath(FileManager.default.currentDirectoryPath)) {
        self.directory = directory
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: directory.string)) ?? []
        self.files = names
            .filter { $0.hasSuffix(".vkey") || $0.hasSuffix(".skey") }
            .sorted()
            .compactMap { name in
                let path = directory.appending(name)
                guard let attrs = try? fm.attributesOfItem(atPath: path.string),
                      let size = attrs[.size] as? Int, size < 8_192,
                      let data = fm.contents(atPath: path.string),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      let cborHex = json["cborHex"] as? String else {
                    return nil
                }
                return KeyFile(path: path, type: type, cborHex: cborHex)
            }
    }

    /// `alice.stake.vkey` → `alice`
    static func keyName(_ path: FilePath) -> String? {
        guard let name = path.lastComponent?.string else { return nil }
        return name.split(separator: ".").first.map(String.init)
    }

    // Cold keys

    func coldVkey(for poolKeyHash: PoolKeyHash) -> FilePath? {
        files.first { file in
            file.type.hasPrefix("StakePoolVerificationKey")
                && (try? StakePoolVerificationKey.load(from: file.path.string).poolKeyHash())?.payload == poolKeyHash.payload
        }?.path
    }

    func coldSkey(for poolKeyHash: PoolKeyHash) -> FilePath? {
        if let match = files.first(where: { file in
            file.type.hasPrefix("StakePoolSigningKey")
                && Self.poolKeyHash(ofColdSkeyFile: file.path)?.payload == poolKeyHash.payload
        }) {
            return match.path
        }
        return coldVkey(for: poolKeyHash).flatMap(Self.siblingSigningKey)
    }

    // VRF keys

    func vrfVkey(for vrfKeyHash: VrfKeyHash) -> FilePath? {
        files.first { file in
            file.type.hasPrefix("VrfVerificationKey")
                && (try? VRFVerificationKey.load(from: file.path.string).hash())?.payload == vrfKeyHash.payload
        }?.path
    }

    // Stake keys

    /// The stake key hash of a stake verification key file (normal or extended).
    static func stakeKeyHash(ofVkeyFile path: FilePath) -> VerificationKeyHash? {
        guard let data = FileManager.default.contents(atPath: path.string),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        if type.contains("Extended") {
            guard let extended = try? StakeExtendedVerificationKey.load(from: path.string),
                  let vkey: StakeVerificationKey = try? extended.toNonExtended() else { return nil }
            return try? vkey.hash()
        }
        guard type.hasPrefix("StakeVerificationKey") else { return nil }
        return try? StakeVerificationKey.load(from: path.string).hash()
    }

    func stakeVkey(for keyHash: VerificationKeyHash) -> FilePath? {
        files.first { file in
            file.type.contains("VerificationKey") && file.type.hasPrefix("Stake")
                && Self.stakeKeyHash(ofVkeyFile: file.path)?.payload == keyHash.payload
        }?.path
    }

    /// The stake key hash of a stake signing key file (normal or extended), if it can be read.
    static func stakeKeyHash(ofSkeyFile path: FilePath) -> VerificationKeyHash? {
        guard let data = FileManager.default.contents(atPath: path.string),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return nil }
        let vkey: StakeVerificationKey?
        if type.hasPrefix("StakeExtendedSigningKey") {
            let extended: StakeExtendedVerificationKey? = (try? StakeExtendedSigningKey.load(from: path.string))
                .flatMap { try? $0.toVerificationKey() }
            vkey = extended.flatMap { try? $0.toNonExtended() }
        } else if type.hasPrefix("StakeSigningKey") {
            vkey = (try? StakeSigningKey.load(from: path.string)).flatMap { try? $0.toVerificationKey() }
        } else {
            return nil
        }
        return vkey.flatMap { try? $0.hash() }
    }

    /// The `type` of a key file's text envelope, or nil if the file isn't a readable envelope
    /// (e.g. encrypted or a hardware-wallet file).
    static func envelopeType(of path: FilePath) -> String? {
        guard let data = FileManager.default.contents(atPath: path.string),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["type"] as? String
    }

    /// The pool key hash of a cold signing key file, if it can be read.
    static func poolKeyHash(ofColdSkeyFile path: FilePath) -> PoolKeyHash? {
        guard let skey = try? StakePoolSigningKey.load(from: path.string),
              skey._type.hasPrefix("StakePoolSigningKey"),
              let vkey: StakePoolVerificationKey = try? skey.toVerificationKey() else { return nil }
        return try? vkey.poolKeyHash()
    }

    func stakeSkey(for keyHash: VerificationKeyHash) -> FilePath? {
        if let match = files.first(where: { file in
            file.type.hasPrefix("Stake") && file.type.contains("SigningKey")
                && Self.stakeKeyHash(ofSkeyFile: file.path)?.payload == keyHash.payload
        }) {
            return match.path
        }
        return stakeVkey(for: keyHash).flatMap(Self.siblingSigningKey)
    }

    /// `x.vkey` → `x.skey` or `x.hwsfile`, if one exists.
    static func siblingSigningKey(of vkey: FilePath) -> FilePath? {
        let base = String(vkey.string.dropLast(".vkey".count))
        for candidate in ["\(base).skey", "\(base).hwsfile"] where FileManager.default.fileExists(atPath: candidate) {
            return FilePath(candidate)
        }
        return nil
    }
}

// MARK: - Stake credential arguments

/// A stake key given on the command line as a stake address, 56-hex key hash, or a
/// stake verification key file (path or `<name>` for `<name>.stake.vkey`).
struct StakeKeyArgument: ExpressibleByArgument {
    let keyHash: VerificationKeyHash
    let vkeyFile: FilePath?

    init(keyHash: VerificationKeyHash, vkeyFile: FilePath? = nil) {
        self.keyHash = keyHash
        self.vkeyFile = vkeyFile
    }

    init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("stake") {
            guard let address = try? Address(from: .string(trimmed)),
                  case .verificationKeyHash(let hash) = address.stakingPart else { return nil }
            self.init(keyHash: hash)
            return
        }

        let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if trimmed.count == 56, trimmed.unicodeScalars.allSatisfy({ hexSet.contains($0) }) {
            self.init(keyHash: VerificationKeyHash(payload: trimmed.hexStringToData))
            return
        }

        for candidate in [trimmed, "\(trimmed).stake.vkey"] where FileManager.default.fileExists(atPath: candidate) {
            let path = FilePath(candidate)
            if let hash = PoolKeyFileMatcher.stakeKeyHash(ofVkeyFile: path) {
                self.init(keyHash: hash, vkeyFile: path)
                return
            }
        }
        return nil
    }

    func rewardAccount(network: NetworkId) throws -> RewardAccountHash {
        let address = try Address(stakingPart: .verificationKeyHash(keyHash), network: network)
        return RewardAccountHash(payload: address.toBytes())
    }
}

// MARK: - Pool JSON from on-chain params

extension Pool {
    /// Build a pool JSON from on-chain params, linking local key files that match
    /// the registered hashes. Missing files are left empty rather than failing.
    static func fromOnChain(
        draft: PoolParamsDraft,
        name: String,
        keys: PoolKeyFileMatcher = PoolKeyFileMatcher()
    ) throws -> Pool {
        let owners: [PoolOwner] = draft.owners.map { hash in
            let vkey = keys.stakeVkey(for: hash)
            return PoolOwner(
                name: vkey.flatMap(PoolKeyFileMatcher.keyName),
                witness: .local,
                stakeVkey: vkey,
                stakeSkey: keys.stakeSkey(for: hash),
                stakeKeyHash: hash.payload.toHex
            )
        }

        let rewardHash = draft.rewardStakeKeyHash
        let rewardVkey = rewardHash.flatMap { keys.stakeVkey(for: $0) }
        let rewardsOwner = RewardsOwner(
            name: rewardVkey.flatMap(PoolKeyFileMatcher.keyName),
            stakeVkey: rewardVkey,
            stakeSkey: rewardHash.flatMap { keys.stakeSkey(for: $0) },
            rewardAccount: draft.rewardAccount.payload.toHex,
            stakeKeyHash: rewardHash?.payload.toHex
        )

        let margin = Double(draft.margin.numerator) / Double(max(draft.margin.denominator, 1))
        var pool = try Pool(
            name: name,
            owners: owners,
            pledge: draft.pledge,
            cost: draft.cost,
            margin: margin,
            relays: draft.relays,
            metaName: draft.metadataName,
            metaDescription: draft.metadataDescription,
            metaTicker: draft.metadataTicker,
            metaHomepage: draft.metadataHomepage.flatMap { URL(string: $0) },
            metaUrl: draft.metadataUrl.flatMap { URL(string: $0) },
            vrfKeyHash: draft.vrfKeyHash.payload.toHex,
            rewardsOwner: rewardsOwner
        )

        let poolOperator = draft.poolOperator
        pool.idBech = try poolOperator.toBech32()
        pool.idHex = draft.poolKeyHash.payload.toHex
        pool.metadataHash = draft.metadataHash

        // Only reference key files that exist and match the registered hashes
        pool.coldVkey = keys.coldVkey(for: draft.poolKeyHash)
        pool.coldSkey = keys.coldSkey(for: draft.poolKeyHash)
        pool.vrfVkey = keys.vrfVkey(for: draft.vrfKeyHash)
        pool.vrfSkey = pool.vrfVkey.flatMap(PoolKeyFileMatcher.siblingSigningKey)
        for keyPath in [\Pool.nodeCounter, \Pool.kesCounter, \Pool.kesCounterNext, \Pool.kesExpireJson] {
            if let path = pool[keyPath: keyPath], !FileManager.default.fileExists(atPath: path.string) {
                pool[keyPath: keyPath] = nil
            }
        }
        return pool
    }

    /// Report which key files were linked, so the user knows what is still missing.
    func printKeyFileReport() {
        func status(_ label: String, _ path: FilePath?) -> String {
            let padded = label.padding(toLength: 24, withPad: " ", startingAt: 0)
            if let path, FileManager.default.fileExists(atPath: path.string) {
                return "  \(padded)\(noora.format("\(.success(path.lastComponent?.string ?? path.string))"))"
            }
            return "  \(padded)\(noora.format("\(.muted("not found"))"))"
        }
        var lines = [noora.format("\n\(.primary("━━━ Local Key Files ━━━"))")]
        lines.append(status("Cold verification key:", coldVkey))
        lines.append(status("Cold signing key:", coldSkey))
        lines.append(status("VRF verification key:", vrfVkey))
        lines.append(status("VRF signing key:", vrfSkey))
        lines.append(status("Reward stake vkey:", rewardsOwner?.stakeVkey))
        for (index, owner) in owners.enumerated() {
            lines.append(status("Owner \(index + 1) stake vkey:", owner.stakeVkey))
            lines.append(status("Owner \(index + 1) stake skey:", owner.stakeSkey))
        }
        print(lines.joined(separator: "\n"))
        spacedPrint("Missing files are only needed by the commands that use them (e.g. signing).")
    }
}
