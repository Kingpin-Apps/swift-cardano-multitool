import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("AssetMainCommand.Mint")
struct AssetMintTests {

    @Test("parses combined positional policyAsset")
    func parsesPositional() throws {
        let cmd = try AssetMainCommand.Mint.parse(["myPolicy.MYTOK", "--amount", "1000"])
        #expect(cmd.policyAsset == "myPolicy.MYTOK")
        #expect(cmd.amount == 1000)
    }

    @Test("parses --policy-name + --asset-name + --amount")
    func parsesFlags() throws {
        let cmd = try AssetMainCommand.Mint.parse([
            "--policy-name", "myPolicy",
            "--asset-name", "MYTOK",
            "--amount", "500"
        ])
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.assetName == "MYTOK")
        #expect(cmd.amount == 500)
    }

    @Test("validate splits combined positional into policy/asset")
    func validateSplitsPositional() throws {
        var cmd = try AssetMainCommand.Mint.parse([
            "myPolicy.MYTOK",
            "--amount", "1000"
        ])
        // validateForTransaction may throw because of missing required transaction options,
        // so we ignore that and just check the positional split happened.
        _ = try? cmd.validate()
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.assetName == "MYTOK")
    }

    @Test("validate rejects amount of zero (parse calls validate() automatically)")
    func rejectsZeroAmount() throws {
        #expect(throws: (any Error).self) {
            _ = try AssetMainCommand.Mint.parse([
                "myPolicy.MYTOK",
                "--amount", "0"
            ])
        }
    }
}

@Suite("AssetMainCommand.Burn")
struct AssetBurnTests {

    @Test("parses combined positional")
    func parsesPositional() throws {
        let cmd = try AssetMainCommand.Burn.parse(["myPolicy.MYTOK", "--amount", "100"])
        #expect(cmd.policyAsset == "myPolicy.MYTOK")
        #expect(cmd.amount == 100)
    }
}
