import Foundation
import SystemPackage
import Testing
import Configuration
@testable import SwiftCardanoMultitool

@Suite("Pool init")
struct PoolInitTests {

    @Test("accepts a valid margin under 1.00")
    func acceptsValidMargin() throws {
        let pool = try Pool(margin: 0.5)
        #expect(pool.margin == 0.5)
    }

    @Test("throws when margin is nil")
    func rejectsNilMargin() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Pool(margin: nil)
        }
    }

    @Test("accepts a margin of 1.00 (100%)")
    func acceptsMarginEqualToOne() throws {
        let pool = try Pool(margin: 1.0)
        #expect(pool.margin == 1.0)
    }

    @Test("throws when margin is greater than 1.00")
    func rejectsMarginAboveOne() {
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try Pool(margin: 1.5)
        }
    }

    @Test("when name is nil, key file defaults remain nil")
    func nilNameLeavesPathsNil() throws {
        let pool = try Pool(margin: 0.1)
        #expect(pool.coldVkey == nil)
        #expect(pool.vrfSkey == nil)
        #expect(pool.metadataFile == nil)
    }

    @Test("when name is set, key file defaults are derived from it")
    func nameDerivesFilePaths() throws {
        let pool = try Pool(name: "scm_pool_test_unique_xyz", margin: 0.1)
        #expect(pool.coldVkey?.lastComponent?.string == "scm_pool_test_unique_xyz.cold.vkey")
        #expect(pool.coldSkey?.lastComponent?.string == "scm_pool_test_unique_xyz.cold.skey")
        #expect(pool.vrfVkey?.lastComponent?.string == "scm_pool_test_unique_xyz.vrf.vkey")
        #expect(pool.metadataFile?.lastComponent?.string == "scm_pool_test_unique_xyz.metadata.json")
        #expect(pool.idHexFile?.lastComponent?.string == "scm_pool_test_unique_xyz.pool.id")
    }

    @Test("explicit file paths take precedence over name-derived defaults")
    func explicitPathsWin() throws {
        let custom = FilePath("/custom/cold.vkey")
        let pool = try Pool(name: "scm_pool_test_unique_xyz", margin: 0.1, coldVkey: custom)
        #expect(pool.coldVkey == custom)
    }
}

@Suite("Pool.validate")
struct PoolValidateTests {

    private func validPool(_ mutate: (inout Pool) -> Void = { _ in }) throws -> Pool {
        var p = try Pool(margin: 0.1)
        mutate(&p)
        return p
    }

    @Test("a minimal pool with only a valid margin passes validation")
    func minimalValid() throws {
        let p = try validPool()
        try p.validate()
    }

    @Test("rejects a name longer than 50 characters")
    func rejectsLongName() throws {
        let p = try validPool { $0.name = String(repeating: "a", count: 51) }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("rejects a meta_name longer than 50 characters")
    func rejectsLongMetaName() throws {
        let p = try validPool { $0.metaName = String(repeating: "x", count: 51) }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("rejects a meta_description longer than 255 characters")
    func rejectsLongMetaDescription() throws {
        let p = try validPool { $0.metaDescription = String(repeating: "d", count: 256) }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("rejects a meta_homepage URL longer than 128 characters")
    func rejectsLongHomepage() throws {
        let longURL = URL(string: "https://example.com/" + String(repeating: "x", count: 120))!
        let p = try validPool { $0.metaHomepage = longURL }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("rejects a meta_ticker shorter than 3 characters")
    func rejectsShortTicker() throws {
        let p = try validPool { $0.metaTicker = "AB" }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("rejects a meta_ticker longer than 5 characters")
    func rejectsLongTicker() throws {
        let p = try validPool { $0.metaTicker = "TICKER" }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }

    @Test("accepts a meta_ticker of length 3, 4, and 5")
    func acceptsValidTicker() throws {
        for t in ["ABC", "ABCD", "ABCDE"] {
            let p = try validPool { $0.metaTicker = t }
            try p.validate()
        }
    }

    @Test("rejects an extended_meta_url longer than 64 characters")
    func rejectsLongExtendedMetaUrl() throws {
        let longURL = URL(string: "https://example.com/" + String(repeating: "x", count: 60))!
        let p = try validPool { $0.extendedMetaUrl = longURL }
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try p.validate()
        }
    }
}

@Suite("Pool.toPoolOperator")
struct PoolToPoolOperatorTests {

    @Test("returns nil when no pool ID, files, or cold vkey are available")
    func nilForEmptyPool() throws {
        let pool = try Pool(margin: 0.1)
        #expect(pool.toPoolOperator() == nil)
    }

    @Test("succeeds for a valid bech32 idBech")
    func succeedsForBech32Id() throws {
        var pool = try Pool(margin: 0.1)
        pool.idBech = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        #expect(pool.toPoolOperator() != nil)
    }
}

@Suite("Pool.dummyPoolJson")
struct PoolDummyJsonTests {

    @Test("includes the pool name in the dummy JSON")
    func includesName() throws {
        let pool = try Pool(name: "scm_dummy_xyz", margin: 0.1)
        let dummy = pool.dummyPoolJson()
        #expect(dummy["name"] as? String == "scm_dummy_xyz")
    }

    @Test("includes top-level marker keys")
    func includesMarkers() throws {
        let pool = try Pool(margin: 0.1)
        let dummy = pool.dummyPoolJson()
        #expect(dummy["owners"] != nil)
        #expect(dummy["rewards_owner"] != nil)
        #expect(dummy["relays"] != nil)
        #expect(dummy["pledge"] as? Int == 100_000_000_000)
        #expect(dummy["cost"] as? Int == 10_000_000_000)
        #expect(dummy["margin"] as? Double == 0.10)
    }

    @Test("generateNewPoolJson writes a deserializable template with name and margin")
    func generateNewPoolJsonRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let stem = "scm_gen_pool_test"
        let path = FilePath(dir.appendingPathComponent("\(stem).pool.json").path)

        try Pool.generateNewPoolJson(at: path)

        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["name"] as? String == stem)
        #expect(parsed?["margin"] as? Double == 0.10)
    }
}

// MARK: - Pool.save / Pool.load

@Suite("Pool.save and Pool.load")
struct PoolSaveLoadTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-pool-saveload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("save writes a JSON file that can be read back via Pool.load")
    func saveLoadRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("round.pool.json").path)

        var pool = try Pool(margin: 0.05)
        pool.name = "my_pool"
        pool.metaTicker = "ABC"
        try pool.save(to: path)

        #expect(FileManager.default.fileExists(atPath: path.string))

        let loaded = try Pool.load(from: path)
        #expect(loaded.name == "my_pool")
        #expect(loaded.metaTicker == "ABC")
        #expect(loaded.margin == 0.05)
    }

    @Test("save with overwrite: false throws when the file already exists")
    func saveRejectsExistingWithoutOverwrite() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("existing.pool.json").path)

        let pool = try Pool(margin: 0.05)
        try pool.save(to: path)

        #expect(throws: SwiftCardanoMultitoolError.self) {
            try pool.save(to: path, overwrite: false)
        }
    }

    @Test("save with overwrite: true replaces an existing file")
    func saveOverwriteReplaces() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("overwrite.pool.json").path)

        var first = try Pool(margin: 0.05)
        first.metaTicker = "AAA"
        try first.save(to: path)

        var second = try Pool(margin: 0.10)
        second.metaTicker = "ZZZ"
        try second.save(to: path, overwrite: true)

        let reloaded = try Pool.load(from: path)
        #expect(reloaded.metaTicker == "ZZZ")
        #expect(reloaded.margin == 0.10)
    }

    @Test("load throws on a missing file")
    func loadThrowsOnMissingFile() {
        let bogusPath = FilePath("/tmp/scm-pool-load-missing-\(UUID().uuidString).pool.json")
        #expect(throws: (any Error).self) {
            _ = try Pool.load(from: bogusPath)
        }
    }

    @Test("load throws on malformed JSON")
    func loadThrowsOnMalformedJSON() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("bad.pool.json")
        try Data("{ this is not json".utf8).write(to: path)

        #expect(throws: (any Error).self) {
            _ = try Pool.load(from: FilePath(path.path))
        }
    }
}

// MARK: - Pool.init(config:)

@Suite("Pool.init(config:)")
struct PoolInitFromConfigTests {

    @Test("populates representative string + int + double fields from the provider")
    func populatesRepresentativeKeys() {
        let provider = InMemoryProvider(
            name: "pool-test",
            values: [
                "name": "test_pool",
                "pledge": 1_000_000,
                "cost": 340_000_000,
                "margin": 0.05,
                "meta_ticker": "TEST"
            ]
        )
        let reader = ConfigReader(provider: provider)
        let pool = Pool(config: reader)

        #expect(pool.name == "test_pool")
        #expect(pool.pledge == 1_000_000)
        #expect(pool.cost == 340_000_000)
        #expect(pool.margin == 0.05)
        #expect(pool.metaTicker == "TEST")
    }

    @Test("unset config keys leave the property nil")
    func unsetKeysAreNil() {
        let provider = InMemoryProvider(
            name: "pool-test",
            values: ["name": "x"]
        )
        let reader = ConfigReader(provider: provider)
        let pool = Pool(config: reader)

        #expect(pool.metaTicker == nil)
        #expect(pool.metaDescription == nil)
        #expect(pool.pledge == nil)
    }
}

// MARK: - Pool.toPoolMetadata

@Suite("Pool.toPoolMetadata")
struct PoolToPoolMetadataTests {

    @Test("happy path builds a PoolMetadata with homepage URL")
    func happyPath() throws {
        var pool = try Pool(margin: 0.05)
        pool.metaName = "Test Pool"
        pool.metaDescription = "For unit tests"
        pool.metaTicker = "TEST"
        pool.metaHomepage = URL(string: "https://example.com")
        let meta = try pool.toPoolMetadata()
        #expect(meta.homepage?.absoluteString == "https://example.com")
        #expect(meta.name == "Test Pool")
        #expect(meta.desc == "For unit tests")
        #expect(meta.ticker == "TEST")
    }

    @Test("builds metadata when only homepage is set (other meta fields are optional)")
    func minimalWithJustHomepage() throws {
        var pool = try Pool(margin: 0.05)
        pool.metaHomepage = URL(string: "https://example.com/min")
        let meta = try pool.toPoolMetadata()
        #expect(meta.homepage?.absoluteString == "https://example.com/min")
        #expect(meta.url == nil)
    }

    @Test("includes optional metadata URL when meta_url is set")
    func includesOptionalUrl() throws {
        var pool = try Pool(margin: 0.05)
        pool.metaHomepage = URL(string: "https://example.com")
        pool.metaUrl = URL(string: "https://example.com/meta.json")
        let meta = try pool.toPoolMetadata()
        #expect(meta.url?.absoluteString == "https://example.com/meta.json")
    }
}
