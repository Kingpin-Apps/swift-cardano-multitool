import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.AssetMeta")
struct QueryAssetMetaTests {

    @Test("parses positional subject")
    func parsesSubject() throws {
        let subject = String(repeating: "a", count: 56)
        let cmd = try QueryMainCommand.AssetMeta.parse([subject])
        #expect(cmd.asset == subject)
    }
}
