import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

// MARK: - Policy

@Suite("GenerateMainCommand.Policy")
struct GeneratePolicyTests {

    @Test("commandName is 'policy'")
    func commandName() {
        #expect(GenerateMainCommand.Policy.configuration.commandName == "policy")
    }

    @Test("abstract is populated")
    func abstract() {
        #expect(!GenerateMainCommand.Policy.configuration.abstract.isEmpty)
    }

    @Test("defaults: nothing set, language English, wordCount 24")
    func defaults() throws {
        let cmd = try GenerateMainCommand.Policy.parse([])
        #expect(cmd.policyName == nil)
        #expect(cmd.keyGenMethod == nil)
        #expect(cmd.subAccount == nil)
        #expect(cmd.mnemonics == nil)
        #expect(cmd.language == .english)
        #expect(cmd.wordCount == .twentyFour)
        #expect(cmd.tool == nil)
        #expect(cmd.slotLimit == nil)
    }

    @Test("parses --policy-name and --key-gen-method")
    func parsesNameAndMethod() throws {
        let cmd = try GenerateMainCommand.Policy.parse([
            "--policy-name", "myPolicy",
            "--key-gen-method", "cli"
        ])
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("validate defaults subAccount to 0 for .hw / .mnemonics methods")
    func validateDefaultsSubAccount() throws {
        var cmd = try GenerateMainCommand.Policy.parse([
            "--key-gen-method", "hw"
        ])
        try cmd.validate()
        #expect(cmd.subAccount == 0)
    }

    @Test("validate rejects unsupported key gen methods (hwMulti, hybrid, etc.)")
    func validateRejectsUnsupported() throws {
        for method in ["hw_multi", "hybrid", "hybrid_multi", "hybrid_enc", "hybrid_multi_enc"] {
            #expect(throws: (any Error).self) {
                _ = try GenerateMainCommand.Policy.parse([
                    "--key-gen-method", method
                ])
            }
        }
    }

    @Test("parses --slot-limit value")
    func parsesSlotLimit() throws {
        let cmd = try GenerateMainCommand.Policy.parse(["--slot-limit", "12345"])
        #expect(cmd.slotLimit == 12345)
    }

    @Test("parses --tool option")
    func parsesTool() throws {
        let cmd = try GenerateMainCommand.Policy.parse(["--tool", "swiftcardano"])
        #expect(cmd.tool == .swiftCardano)
    }
}

// MARK: - DRepKeys

@Suite("GenerateMainCommand.DRepKeys")
struct GenerateDRepKeysTests {

    @Test("commandName is 'drep'")
    func commandName() {
        #expect(GenerateMainCommand.DRepKeys.configuration.commandName == "drep")
    }

    @Test("defaults: nothing set, language English, wordCount 24")
    func defaults() throws {
        let cmd = try GenerateMainCommand.DRepKeys.parse([])
        #expect(cmd.drepName == nil)
        #expect(cmd.keyGenMethod == nil)
        #expect(cmd.subAccount == nil)
        #expect(cmd.index == nil)
        #expect(cmd.mnemonics == nil)
        #expect(cmd.language == .english)
        #expect(cmd.wordCount == .twentyFour)
        #expect(cmd.tool == nil)
    }

    @Test("parses --drep-name option")
    func parsesDrepName() throws {
        let cmd = try GenerateMainCommand.DRepKeys.parse(["--drep-name", "myDRep"])
        #expect(cmd.drepName == "myDRep")
    }

    @Test("validate defaults subAccount and index to 0 for .hw / .mnemonics")
    func validateDefaultsAccountIndex() throws {
        var cmd = try GenerateMainCommand.DRepKeys.parse([
            "--key-gen-method", "mnemonics"
        ])
        try cmd.validate()
        #expect(cmd.subAccount == 0)
        #expect(cmd.index == 0)
    }

    @Test("validate rejects unsupported key gen methods")
    func validateRejectsUnsupported() {
        for method in ["hw_multi", "hybrid", "hybrid_multi", "hybrid_enc", "hybrid_multi_enc"] {
            #expect(throws: (any Error).self) {
                _ = try GenerateMainCommand.DRepKeys.parse([
                    "--key-gen-method", method
                ])
            }
        }
    }

    @Test("validate rejects sub-account above 2_147_483_647 (parse() auto-validates)")
    func validateRejectsLargeSubAccount() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DRepKeys.parse([
                "--sub-account", "2147483648"
            ])
        }
    }

    @Test("validate rejects negative index")
    func validateRejectsNegativeIndex() {
        // ArgumentParser may surface negative ints differently; just confirm the
        // boundary is enforced when the value is parseable.
        #expect(throws: (any Error).self) {
            var cmd = try GenerateMainCommand.DRepKeys.parse([])
            cmd.index = -1
            try cmd.validate()
        }
    }
}

// MARK: - AssetMetadata

@Suite("GenerateMainCommand.AssetMeta")
struct GenerateAssetMetaTests {

    @Test("commandName is 'asset-meta'")
    func commandName() {
        #expect(GenerateMainCommand.AssetMeta.configuration.commandName == "asset-meta")
    }

    @Test("defaults: every option nil")
    func defaults() throws {
        let cmd = try GenerateMainCommand.AssetMeta.parse([])
        #expect(cmd.policyName == nil)
        #expect(cmd.assetName == nil)
        #expect(cmd.metaName == nil)
        #expect(cmd.metaDescription == nil)
        #expect(cmd.metaTicker == nil)
        #expect(cmd.metaUrl == nil)
        #expect(cmd.metaDecimals == nil)
        #expect(cmd.metaLogoPath == nil)
        #expect(cmd.outputDir == nil)
    }

    @Test("parses --policy-name + --asset-name + --meta-name")
    func parsesBasicFields() throws {
        let cmd = try GenerateMainCommand.AssetMeta.parse([
            "--policy-name", "myPolicy",
            "--asset-name", "MYTOK",
            "--meta-name", "My Token"
        ])
        #expect(cmd.policyName == "myPolicy")
        #expect(cmd.assetName == "MYTOK")
        #expect(cmd.metaName == "My Token")
    }

    @Test("validate accepts --meta-decimals in [0, 255]")
    func validateDecimalsInRange() throws {
        for value in [0, 6, 255] {
            var cmd = try GenerateMainCommand.AssetMeta.parse(["--meta-decimals", "\(value)"])
            try cmd.validate()
            #expect(cmd.metaDecimals == value)
        }
    }

    @Test("validate rejects --meta-decimals = 256 (above range)")
    func validateRejectsAbove255() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.AssetMeta.parse(["--meta-decimals", "256"])
        }
    }

    @Test("parses --meta-ticker and --meta-url")
    func parsesTickerAndUrl() throws {
        let cmd = try GenerateMainCommand.AssetMeta.parse([
            "--meta-ticker", "MTK",
            "--meta-url", "https://example.com"
        ])
        #expect(cmd.metaTicker == "MTK")
        #expect(cmd.metaUrl == "https://example.com")
    }
}
