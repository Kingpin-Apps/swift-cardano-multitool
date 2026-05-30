import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolOwner")
struct PoolOwnerTests {

    @Test("defaults witness to .local")
    func defaultsToLocalWitness() {
        let owner = PoolOwner(name: "alice")
        #expect(owner.witness == .local)
    }

    @Test("derives stake vkey and skey paths from name when none provided")
    func derivesStakeKeyPaths() {
        let owner = PoolOwner(name: "alice")
        #expect(owner.stakeVkey?.lastComponent?.string == "alice.stake.vkey")
        #expect(owner.stakeSkey?.lastComponent?.string == "alice.stake.skey")
    }

    @Test("preserves explicit stake key paths over name-derived defaults")
    func explicitPathsTakePrecedence() {
        let vkey = FilePath("/custom/alice.vkey")
        let skey = FilePath("/custom/alice.skey")
        let owner = PoolOwner(name: "alice", stakeVkey: vkey, stakeSkey: skey)
        #expect(owner.stakeVkey == vkey)
        #expect(owner.stakeSkey == skey)
    }

    @Test("does not derive paths when name is nil")
    func noNameMeansNilDerivedPaths() {
        let owner = PoolOwner()
        #expect(owner.stakeVkey == nil)
        #expect(owner.stakeSkey == nil)
    }

    @Test("JSON round-trip preserves snake-cased keys")
    func jsonRoundTrip() throws {
        let owner = PoolOwner(
            name: "bob",
            witness: .external,
            stakeVkey: FilePath("/keys/bob.stake.vkey"),
            stakeSkey: FilePath("/keys/bob.stake.skey"),
            delegationCertificate: FilePath("/certs/bob.cert")
        )
        let data = try JSONEncoder().encode(owner)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"stake_vkey\""))
        #expect(json.contains("\"stake_skey\""))
        #expect(json.contains("\"delegation_certificate\""))

        let decoded = try JSONDecoder().decode(PoolOwner.self, from: data)
        #expect(decoded.name == "bob")
        #expect(decoded.witness == .external)
    }
}
