import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("AssetMainCommand")
struct AssetMainCommandTests {

    @Test("commandName is 'asset'")
    func commandName() {
        #expect(AssetMainCommand.configuration.commandName == "asset")
    }

    @Test("subcommands list contains mint and burn")
    func subcommandsRegistered() {
        let names = AssetMainCommand.configuration.subcommands.map { $0.configuration.commandName }
        #expect(names.contains("mint"))
        #expect(names.contains("burn"))
    }

    @Test("AssetCommands.command resolves to the expected type")
    func commandResolution() {
        #expect(AssetCommands.mint.command().configuration.commandName
            == AssetMainCommand.Mint.configuration.commandName)
        #expect(AssetCommands.burn.command().configuration.commandName
            == AssetMainCommand.Burn.configuration.commandName)
        #expect(AssetCommands.back.command().configuration.commandName
            == MainMenuCommand.configuration.commandName)
        #expect(AssetCommands.exit.command().configuration.commandName
            == ExitCommand.configuration.commandName)
    }

    @Test("AssetCommands name and details non-empty")
    func labels() {
        for c in AssetCommands.allCases {
            #expect(!c.name.isEmpty)
            #expect(!c.details.isEmpty)
        }
    }
}

@Suite("AssetMainCommand.Mint")
struct AssetMintTests {

    @Test("commandName is 'mint'")
    func commandName() {
        #expect(AssetMainCommand.Mint.configuration.commandName == "mint")
    }

    @Test("defaults: nothing set, ttl extra 500")
    func defaults() throws {
        let cmd = try AssetMainCommand.Mint.parse([])
        #expect(cmd.policyAsset == nil)
        #expect(cmd.policyName == nil)
        #expect(cmd.assetName == nil)
        #expect(cmd.amount == nil)
        #expect(cmd.ttlExtra == 500)
        #expect(cmd.ttlOverride == nil)
    }

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

    @Test("commandName is 'burn'")
    func commandName() {
        #expect(AssetMainCommand.Burn.configuration.commandName == "burn")
    }

    @Test("defaults: ttl extra 500")
    func defaults() throws {
        let cmd = try AssetMainCommand.Burn.parse([])
        #expect(cmd.policyAsset == nil)
        #expect(cmd.amount == nil)
        #expect(cmd.ttlExtra == 500)
    }

    @Test("parses combined positional")
    func parsesPositional() throws {
        let cmd = try AssetMainCommand.Burn.parse(["myPolicy.MYTOK", "--amount", "100"])
        #expect(cmd.policyAsset == "myPolicy.MYTOK")
        #expect(cmd.amount == 100)
    }
}
