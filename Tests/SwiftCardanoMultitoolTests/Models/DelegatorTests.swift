import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("Delegator")
struct DelegatorTests {

    @Test("defaults witness to .local")
    func defaultsToLocalWitness() {
        let d = Delegator(name: "carol")
        #expect(d.witness == .local)
    }

    @Test("derives .staking. (not .stake.) suffixed key paths from name")
    func derivesStakingPaths() {
        let d = Delegator(name: "carol")
        #expect(d.stakeVkey?.lastComponent?.string == "carol.staking.vkey")
        #expect(d.stakeSkey?.lastComponent?.string == "carol.staking.skey")
    }

    @Test("does not derive paths when name is nil")
    func noNameMeansNilDerivedPaths() {
        let d = Delegator()
        #expect(d.stakeVkey == nil)
        #expect(d.stakeSkey == nil)
    }

    @Test("JSON round-trip preserves snake-cased keys")
    func jsonRoundTrip() throws {
        let d = Delegator(
            name: "carol",
            witness: .external,
            stakeVkey: FilePath("/k/carol.vkey"),
            stakeSkey: FilePath("/k/carol.skey"),
            delegationCertificate: FilePath("/c/carol.cert")
        )
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(Delegator.self, from: data)
        #expect(decoded.name == "carol")
        #expect(decoded.witness == .external)
    }
}
