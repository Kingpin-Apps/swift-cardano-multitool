import ArgumentParser
import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.ProtocolParameters")
struct QueryProtocolParametersTests {

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

    @Test("wizard defaults to 'protocol-parameters.json' in cwd when user enters empty filename")
    func wizardDefaultFilename() async throws {
        let scripted = ScriptedPromptProvider(texts: [""], yesOrNo: [true])
        try await Prompts.$current.withValue(scripted) {
            var cmd = try QueryMainCommand.ProtocolParameters.parse([])
            try await cmd.wizard()
            #expect(cmd.save == true)
            #expect(cmd.fileName?.lastComponent?.string == "protocol-parameters.json")
        }
    }

    @Test("run() with --no-save displays without writing a file")
    func runDoesNotWriteWhenSaveFalse() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "PPCtx", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { try TestFixtures.sampleProtocolParameters() }

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                var cmd = try QueryMainCommand.ProtocolParameters.parse(["--no-save"])
                try await cmd.run()
            }
        }
    }

    @Test("run() writes the protocol parameters to disk when --file-name is set")
    func runWritesToFile() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "PPCtx", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { try TestFixtures.sampleProtocolParameters() }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-pp-run-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("pp.json").path)

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                var cmd = try QueryMainCommand.ProtocolParameters.parse([
                    "--file-name", path.string
                ])
                try await cmd.run()
                #expect(FileManager.default.fileExists(atPath: path.string))
            }
        }
    }

    @Test("run() propagates the chain stub's error")
    func runPropagatesError() async throws {
        struct Boom: Error {}
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "PPCtx", type: .online, networkId: .mainnet)
        mock.stubProtocolParameters = { throw Boom() }

        await #expect(throws: (any Error).self) {
            try await Configs.$override.withValue(cfg) {
                try await Contexts.$override.withValue(mock) {
                    var cmd = try QueryMainCommand.ProtocolParameters.parse(["--no-save"])
                    try await cmd.run()
                }
            }
        }
    }
}
