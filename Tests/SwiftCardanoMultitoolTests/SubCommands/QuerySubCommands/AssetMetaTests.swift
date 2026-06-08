import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.AssetMeta")
struct QueryAssetMetaTests {

    @Test("commandName is 'asset-meta'")
    func commandName() {
        #expect(QueryMainCommand.AssetMeta.configuration.commandName == "asset-meta")
    }

    @Test("alias 'assetmeta' is registered")
    func aliases() {
        #expect(QueryMainCommand.AssetMeta.configuration.aliases.contains("assetmeta"))
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.AssetMeta.parse([])
        #expect(cmd.asset == nil)
    }

    @Test("parses positional subject")
    func parsesSubject() throws {
        let subject = String(repeating: "a", count: 56)
        let cmd = try QueryMainCommand.AssetMeta.parse([subject])
        #expect(cmd.asset == subject)
    }
}
