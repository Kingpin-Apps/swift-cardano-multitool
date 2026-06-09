import ArgumentParser
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("ConfigMainCommand.Init parsing")
struct ConfigInitArgsTests {

    @Test("--network and --file-type accept their enum values")
    func parsesNetworkAndFileType() throws {
        let cmd = try ConfigMainCommand.Init.parse([
            "--network", "preview",
            "--file-type", "toml"
        ])
        #expect(cmd.network == .preview)
        #expect(cmd.fileType == .toml)
    }

    @Test("--config-path accepts a file path")
    func parsesConfigPath() throws {
        let cmd = try ConfigMainCommand.Init.parse(["--config-path", "/tmp/cfg.json"])
        #expect(cmd.configPath?.string == "/tmp/cfg.json")
    }

    @Test("--is-dry-run and --overwrite flags flip their bools")
    func parsesFlags() throws {
        let cmd = try ConfigMainCommand.Init.parse(["--is-dry-run", "--overwrite"])
        #expect(cmd.isDryRun == true)
        #expect(cmd.overwrite == true)
    }

    @Test("rejects an unknown network value")
    func rejectsUnknownNetwork() {
        #expect(throws: (any Error).self) {
            _ = try ConfigMainCommand.Init.parse(["--network", "testnet"])
        }
    }

    @Test("rejects an unknown file type")
    func rejectsUnknownFileType() {
        #expect(throws: (any Error).self) {
            _ = try ConfigMainCommand.Init.parse(["--file-type", "xml"])
        }
    }
}

@Suite("ConfigMainCommand.Init wizard (scripted prompts)")
struct ConfigInitWizardTests {

    @Test("wizard fills in network and fileType from scripted single-choice answers")
    func wizardFillsBothFromScript() async throws {
        let scripted = ScriptedPromptProvider(singleChoice: ["mainnet", "json"])
        try await Prompts.$current.withValue(scripted) {
            var cmd = try ConfigMainCommand.Init.parse([])
            try await cmd.wizard()
            #expect(cmd.network == .mainnet)
            #expect(cmd.fileType == .json)
        }
    }

    @Test("wizard skips fields already supplied via flags")
    func wizardSkipsPresetValues() async throws {
        let scripted = ScriptedPromptProvider(singleChoice: ["toml"])
        try await Prompts.$current.withValue(scripted) {
            var cmd = try ConfigMainCommand.Init.parse(["--network", "preview"])
            try await cmd.wizard()
            #expect(cmd.network == .preview)
            #expect(cmd.fileType == .toml)
        }
        // Exactly one prompt should have been issued (for fileType).
        #expect(scripted.prompts.count == 1)
    }
}
