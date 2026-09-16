import Foundation
import SystemPackage
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolRelay command-line parsing")
struct PoolRelayArgumentTests {

    @Test("parses ipv4, ipv6, dns and srv relays")
    func parsesRelayKinds() {
        #expect(PoolRelay(argument: "ipv4:10.0.0.2:6000") == PoolRelay(type: .ip, host: "10.0.0.2", port: "6000", hostType: .ipv4))
        #expect(PoolRelay(argument: "ipv6:[2001:db8::1]:3001") == PoolRelay(type: .ip, host: "2001:db8::1", port: "3001", hostType: .ipv6))
        #expect(PoolRelay(argument: "dns:relay.example.com:3001") == PoolRelay(type: .dns, host: "relay.example.com", port: "3001", hostType: .single))
        #expect(PoolRelay(argument: "srv:_cardano._tcp.example.com") == PoolRelay(type: .dns, host: "_cardano._tcp.example.com", port: nil, hostType: .multi))
    }

    @Test("rejects invalid relays")
    func rejectsInvalid() {
        #expect(PoolRelay(argument: "ipv4:999.1.1.1:3001") == nil)
        #expect(PoolRelay(argument: "dns:relay.example.com") == nil)
        #expect(PoolRelay(argument: "dns:relay.example.com:70000") == nil)
        #expect(PoolRelay(argument: "ftp:relay.example.com:21") == nil)
    }

    @Test("round-trips through ledger relays")
    func roundTrips() throws {
        for argument in ["ipv4:10.0.0.2:6000", "ipv6:[2001:db8::1]:3001", "dns:relay.example.com:3001", "srv:_cardano._tcp.example.com"] {
            let relay = try #require(PoolRelay(argument: argument))
            // IPv6 text may come back uncompressed, so compare the encoded relay
            #expect(try PoolRelay(relay: try relay.toRelay()).toRelay().toCBORData() == relay.toRelay().toCBORData())
        }
    }
}

@Suite("Pool margin parsing")
struct PoolMarginParsingTests {

    @Test("parses decimals, percentages and fractions exactly")
    func parsesExactly() throws {
        let decimal = try #require(PoolParamsFormat.parseMargin("0.015"))
        #expect(decimal.numerator == 3 && decimal.denominator == 200)
        let percent = try #require(PoolParamsFormat.parseMargin("1.5%"))
        #expect(percent.numerator == 3 && percent.denominator == 200)
        let fraction = try #require(PoolParamsFormat.parseMargin("1/3"))
        #expect(fraction.numerator == 1 && fraction.denominator == 3)
        let zero = try #require(PoolParamsFormat.parseMargin("0"))
        #expect(zero.numerator == 0)
    }

    @Test("rejects margins outside 0-100%")
    func rejectsOutOfRange() {
        #expect(PoolParamsFormat.parseMargin("150%") == nil)
        #expect(PoolParamsFormat.parseMargin("1.2") == nil)
        #expect(PoolParamsFormat.parseMargin("4/3") == nil)
        #expect(PoolParamsFormat.parseMargin("abc") == nil)
    }
}

@Suite("PoolParamsDraft")
struct PoolParamsDraftTests {

    static func sampleParams() throws -> PoolParams {
        let owner = VerificationKeyHash(payload: Data(repeating: 0x4f, count: 28))
        let reward = try Address(stakingPart: .verificationKeyHash(owner), network: .testnet)
        return PoolParams(
            poolOperator: PoolKeyHash(payload: Data(repeating: 0x77, count: 28)),
            vrfKeyHash: VrfKeyHash(payload: Data(repeating: 0x0d, count: 32)),
            pledge: 1_000_000_000,
            cost: 340_000_000,
            margin: UnitInterval(numerator: 1, denominator: 3),
            rewardAccount: RewardAccountHash(payload: reward.toBytes()),
            poolOwners: .orderedSet(try OrderedSet([owner])),
            relays: [.singleHostName(SingleHostName(port: 3001, dnsName: "relay.example.com"))],
            poolMetadata: try PoolMetadata(
                url: try Url("https://example.com/pool.json"),
                poolMetadataHash: PoolMetadataHash(payload: Data(repeating: 0xab, count: 32))
            )
        )
    }

    @Test("unedited params encode to the same certificate")
    func roundTripsUnchanged() throws {
        let params = try Self.sampleParams()
        let draft = PoolParamsDraft(params: params)
        #expect(try draft.toPoolParams().toCBORData() == params.toCBORData())
        #expect(draft == PoolParamsDraft(params: params))
    }

    @Test("keeps a non-decimal margin exact")
    func keepsExactMargin() throws {
        let draft = PoolParamsDraft(params: try Self.sampleParams())
        let margin = try draft.toPoolParams().margin
        #expect(margin.numerator == 1 && margin.denominator == 3)
    }

    @Test("reduces unreduced on-chain margins")
    func reducesMargin() throws {
        let reduced = PoolParamsDraft.reduced(UnitInterval(numerator: 10_000_000, denominator: 100_000_000))
        #expect(reduced.numerator == 1 && reduced.denominator == 10)
        let zero = PoolParamsDraft.reduced(UnitInterval(numerator: 0, denominator: 100_000_000))
        #expect(zero.numerator == 0 && zero.denominator == 1)
    }

    @Test("reports the reward account's stake key hash")
    func rewardStakeKeyHash() throws {
        let draft = PoolParamsDraft(params: try Self.sampleParams())
        #expect(draft.rewardStakeKeyHash?.payload == Data(repeating: 0x4f, count: 28))
    }

    @Test("validation rejects low cost, no owners and half-set metadata")
    func validation() throws {
        var draft = PoolParamsDraft(params: try Self.sampleParams())
        #expect(throws: SwiftCardanoMultitoolError.self) { try draft.validate(minPoolCost: 500_000_000) }

        draft.owners = []
        #expect(throws: SwiftCardanoMultitoolError.self) { try draft.validate(minPoolCost: 170_000_000) }

        draft = PoolParamsDraft(params: try Self.sampleParams())
        draft.metadataHash = nil
        #expect(throws: SwiftCardanoMultitoolError.self) { try draft.validate(minPoolCost: 170_000_000) }

        draft = PoolParamsDraft(params: try Self.sampleParams())
        try draft.validate(minPoolCost: 170_000_000)
    }

    @Test("a pool JSON built from on-chain params produces the same certificate without key files")
    func poolJSONFromOnChain() throws {
        let params = try Self.sampleParams()
        let emptyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let keys = PoolKeyFileMatcher(directory: FilePath(emptyDir.path))
        var draft = PoolParamsDraft(params: params)
        draft.margin = UnitInterval(numerator: 1, denominator: 10)
        let pool = try Pool.fromOnChain(draft: draft, name: "scm_onchain_test_xyz", keys: keys)

        #expect(pool.coldVkey == nil)
        #expect(pool.vrfVkey == nil)
        #expect(pool.owners.first?.stakeKeyHash == Data(repeating: 0x4f, count: 28).toHex)
        #expect(try pool.toPoolParams(network: .testnet).toCBORData() == draft.toPoolParams().toCBORData())
    }
}

@Suite("Pool JSON key hash fallbacks")
struct PoolJSONHashFallbackTests {

    static func hashOnlyPool(dir: URL) throws -> (Pool, PoolParamsDraft) {
        let params = try PoolParamsDraftTests.sampleParams()
        var draft = PoolParamsDraft(params: params)
        draft.margin = UnitInterval(numerator: 1, denominator: 10)
        let keys = PoolKeyFileMatcher(directory: FilePath(dir.path))
        return (try Pool.fromOnChain(draft: draft, name: "scm_hash_only_test_xyz", keys: keys), draft)
    }

    static func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("rewards owner with only stake_key_hash builds the same reward account")
    func rewardsOwnerStakeKeyHashOnly() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (pool, draft) = try Self.hashOnlyPool(dir: dir)
        #expect(pool.rewardsOwner?.stakeKeyHash == Data(repeating: 0x4f, count: 28).toHex)

        pool.rewardsOwner?.rewardAccount = nil
        #expect(try pool.toPoolParams(network: .testnet).toCBORData() == draft.toPoolParams().toCBORData())
    }

    @Test("falls back to the first owner's stake_key_hash when the rewards owner has nothing")
    func firstOwnerHashFallback() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (pool, draft) = try Self.hashOnlyPool(dir: dir)
        pool.rewardsOwner = nil
        #expect(try pool.toPoolParams(network: .testnet).toCBORData() == draft.toPoolParams().toCBORData())
    }

    @Test("stale key file paths fall back to the stored hashes")
    func staleFilePathsFallBack() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        var (pool, draft) = try Self.hashOnlyPool(dir: dir)
        pool.vrfVkey = FilePath(dir.appendingPathComponent("missing.vrf.vkey").path)
        pool.coldVkey = FilePath(dir.appendingPathComponent("missing.cold.vkey").path)
        pool.owners[0].stakeVkey = FilePath(dir.appendingPathComponent("missing.stake.vkey").path)
        pool.rewardsOwner?.stakeVkey = FilePath(dir.appendingPathComponent("missing.stake.vkey").path)
        #expect(try pool.toPoolParams(network: .testnet).toCBORData() == draft.toPoolParams().toCBORData())
    }

    @Test("pool.json is saved with sorted keys and unescaped slashes")
    func savesSortedJSON() throws {
        let dir = try Self.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (pool, _) = try Self.hashOnlyPool(dir: dir)
        let path = FilePath(dir.appendingPathComponent("sorted.pool.json").path)
        try pool.save(to: path)

        let text = try String(contentsOfFile: path.string, encoding: .utf8)
        #expect(!text.contains("\\/"))
        let topLevelKeys = text.split(separator: "\n")
            .filter { $0.hasPrefix("  \"") }
            .compactMap { $0.split(separator: "\"").dropFirst().first.map(String.init) }
        #expect(!topLevelKeys.isEmpty)
        #expect(topLevelKeys == topLevelKeys.sorted())

        let reloaded = try Pool.load(from: path)
        #expect(try reloaded.toPoolParams(network: .testnet).toCBORData() == pool.toPoolParams(network: .testnet).toCBORData())
    }
}

@Suite("StakeKeyArgument")
struct StakeKeyArgumentTests {

    @Test("accepts a stake key hash and a stake address")
    func acceptsHashAndAddress() throws {
        let hashHex = String(repeating: "4f", count: 28)
        let fromHash = try #require(StakeKeyArgument(argument: hashHex))
        #expect(fromHash.keyHash.payload.toHex == hashHex)

        let address = try Address(stakingPart: .verificationKeyHash(fromHash.keyHash), network: .testnet)
        let fromAddress = try #require(StakeKeyArgument(argument: try address.toBech32()))
        #expect(fromAddress.keyHash.payload.toHex == hashHex)
        #expect(try fromAddress.rewardAccount(network: .testnet).payload == address.toBytes())
    }

    @Test("reads a stake verification key file")
    func readsVkeyFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try StakeKeyPair.generate()
        let vkeyPath = dir.appendingPathComponent("owner.stake.vkey").path
        let skeyPath = dir.appendingPathComponent("owner.stake.skey").path
        try pair.verificationKey.save(to: vkeyPath)
        try pair.signingKey.save(to: skeyPath)

        let expected = try pair.verificationKey.hash()
        #expect(StakeKeyArgument(argument: vkeyPath)?.keyHash == expected)

        let keys = PoolKeyFileMatcher(directory: FilePath(dir.path))
        #expect(keys.stakeVkey(for: expected)?.lastComponent?.string == "owner.stake.vkey")
        #expect(keys.stakeSkey(for: expected)?.lastComponent?.string == "owner.stake.skey")
    }

    @Test("rejects garbage")
    func rejectsGarbage() {
        #expect(StakeKeyArgument(argument: "not-a-stake-key") == nil)
        #expect(StakeKeyArgument(argument: "abcd") == nil)
    }
}
