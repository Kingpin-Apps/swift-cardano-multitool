import ArgumentParser
import Foundation
import Testing
@testable import SwiftCardanoMultitool

/// Subcommand-level tests for `query committee-member`.
///
/// The credential parser itself (cold/hot/ambiguous routing, hex/bech32 validation) is
/// covered by `CommitteeMemberCredentialExpressibleByArgumentTests`. These tests cover the
/// subcommand wiring that suite can't reach: its registered name/aliases and that the
/// positional `@Argument` is bound to the credential parser.
///
/// The wizard is intentionally not exercised here: its prompts call the global `noora`
/// directly (and via `getCommittee{Cold,Hot}Credential`, which use a validation-rules text
/// prompt not modeled by `PromptProvider`), so it cannot be driven by `ScriptedPromptProvider`
/// without a production refactor to route those calls through `Prompts.current`.
@Suite("QueryMainCommand.CommitteeMember")
struct QueryCommitteeMemberTests {

    @Test("configuration: committee-member with committee/cc aliases")
    func configuration() {
        let cfg = QueryMainCommand.CommitteeMember.configuration
        #expect(cfg.commandName == "committee-member")
        #expect(cfg.aliases.contains("committee"))
        #expect(cfg.aliases.contains("cc"))
    }

    @Test("the positional argument is bound to the credential parser")
    func argumentBindsToCredentialParser() throws {
        // A bare 28-byte hex hash routes through CommitteeMemberCredential to .ambiguousHash,
        // confirming the @Argument is wired to that ExpressibleByArgument type.
        let hexHash = String(repeating: "ab", count: 28)
        let cmd = try QueryMainCommand.CommitteeMember.parse([hexHash])
        guard case .ambiguousHash(let data)? = cmd.credential else {
            Issue.record("expected .ambiguousHash, got \(String(describing: cmd.credential))")
            return
        }
        #expect(data.count == 28)
    }

    @Test("garbage that doesn't resolve to a credential is rejected")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.CommitteeMember.parse(["not-a-credential-xyz"])
        }
    }
}
