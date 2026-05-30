import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.ProtocolParameters")
struct QueryProtocolParametersTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(QueryMainCommand.ProtocolParameters.configuration.abstract == "Query protocol parameters.")
    }

    @Test("defaults have nil fileName and save=true")
    func defaults() throws {
        let cmd = try QueryMainCommand.ProtocolParameters.parse([])
        #expect(cmd.fileName == nil)
        #expect(cmd.save == true)
    }

    @Test("--no-save inverts the save flag")
    func noSaveInversion() throws {
        let cmd = try QueryMainCommand.ProtocolParameters.parse(["--no-save"])
        #expect(cmd.save == false)
    }

    @Test("--file-name sets the output path")
    func fileNameOption() throws {
        let cmd = try QueryMainCommand.ProtocolParameters.parse(["--file-name", "/tmp/pp.json"])
        #expect(cmd.fileName?.string == "/tmp/pp.json")
    }

    @Test("wizard with scripted prompts populates fileName when save is true")
    func wizardScripted() async throws {
        let scripted = ScriptedPromptProvider(texts: ["custom.json"], yesOrNo: [true])
        try await Prompts.$current.withValue(scripted) {
            var cmd = try QueryMainCommand.ProtocolParameters.parse([])
            try await cmd.wizard()
            #expect(cmd.save == true)
            #expect(cmd.fileName?.lastComponent?.string == "custom.json")
        }
    }

    @Test("wizard skips file prompt when user opts not to save")
    func wizardSkipsFileWhenNotSaving() async throws {
        let scripted = ScriptedPromptProvider(yesOrNo: [false])
        try await Prompts.$current.withValue(scripted) {
            var cmd = try QueryMainCommand.ProtocolParameters.parse([])
            try await cmd.wizard()
            #expect(cmd.save == false)
            #expect(cmd.fileName == nil)
        }
        // Only the yes/no prompt should have been issued.
        #expect(scripted.prompts.count == 1)
    }
}
