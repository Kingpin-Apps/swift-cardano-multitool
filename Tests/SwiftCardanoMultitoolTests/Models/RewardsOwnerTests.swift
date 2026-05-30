import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("RewardsOwner")
struct RewardsOwnerTests {

    @Test("derives stake key paths from name")
    func derivesPathsFromName() {
        let owner = RewardsOwner(name: "rewards")
        #expect(owner.stakeVkey?.lastComponent?.string == "rewards.stake.vkey")
        #expect(owner.stakeSkey?.lastComponent?.string == "rewards.stake.skey")
    }

    @Test("does not derive paths when name is nil")
    func nilName() {
        let owner = RewardsOwner()
        #expect(owner.stakeVkey == nil)
        #expect(owner.stakeSkey == nil)
    }

    @Test("preserves explicit paths over defaults")
    func explicitPaths() {
        let vkey = FilePath("/custom/rewards.vkey")
        let owner = RewardsOwner(name: "rewards", stakeVkey: vkey)
        #expect(owner.stakeVkey == vkey)
        // skey still derived from name since not provided
        #expect(owner.stakeSkey?.lastComponent?.string == "rewards.stake.skey")
    }

    @Test("JSON round-trip preserves snake-cased keys")
    func jsonRoundTrip() throws {
        let owner = RewardsOwner(
            name: "alice",
            stakeVkey: FilePath("/k/alice.vkey"),
            stakeSkey: FilePath("/k/alice.skey")
        )
        let data = try JSONEncoder().encode(owner)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"stake_vkey\""))
        #expect(json.contains("\"stake_skey\""))

        let decoded = try JSONDecoder().decode(RewardsOwner.self, from: data)
        #expect(decoded.name == "alice")
    }
}
