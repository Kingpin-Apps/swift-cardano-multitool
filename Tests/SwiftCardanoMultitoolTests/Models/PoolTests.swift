import Foundation
import SystemPackage
import Testing
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
