import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Argument-parsing smoke tests for WorkOfflineMainCommand subcommands.
@Suite("WorkOfflineMainCommand smoke tests")
struct WorkOfflineCommandsTests {

    @Test("New: commandName is 'new'")
    func newCommandName() {
        #expect(WorkOfflineMainCommand.New.configuration.commandName == "new")
    }

    @Test("New: parses --out-file")
    func newParsesOutFile() throws {
        let cmd = try WorkOfflineMainCommand.New.parse(["--out-file", "/tmp/offline.json"])
        #expect(cmd.outFile?.string == "/tmp/offline.json")
    }

    @Test("Info: commandName is 'info'")
    func infoCommandName() {
        #expect(WorkOfflineMainCommand.Info.configuration.commandName == "info")
    }

    @Test("Info: parses --in-file")
    func infoParsesInFile() throws {
        let cmd = try WorkOfflineMainCommand.Info.parse(["--in-file", "/tmp/offline.json"])
        #expect(cmd.inFile?.string == "/tmp/offline.json")
    }

    @Test("Attach: commandName is 'attach'")
    func attachCommandName() {
        #expect(WorkOfflineMainCommand.Attach.configuration.commandName == "attach")
    }

    @Test("Attach: --file is required")
    func attachFileRequired() {
        #expect(throws: (any Error).self) {
            _ = try WorkOfflineMainCommand.Attach.parse([])
        }
    }

    @Test("Attach: parses --file and --in-file")
    func attachParses() throws {
        let cmd = try WorkOfflineMainCommand.Attach.parse([
            "--file", "/tmp/attach.bin",
            "--in-file", "/tmp/offline.json"
        ])
        #expect(cmd.file.string == "/tmp/attach.bin")
        #expect(cmd.inFile?.string == "/tmp/offline.json")
    }

    @Test("Extract: commandName is 'extract'")
    func extractCommandName() {
        #expect(WorkOfflineMainCommand.Extract.configuration.commandName == "extract")
    }

    @Test("Extract: parses --in-file and --out-dir")
    func extractParses() throws {
        let cmd = try WorkOfflineMainCommand.Extract.parse([
            "--in-file", "/tmp/offline.json",
            "--out-dir", "/tmp/extract-here"
        ])
        #expect(cmd.inFile?.string == "/tmp/offline.json")
        #expect(cmd.outDir?.string == "/tmp/extract-here")
    }

    @Test("Execute: commandName is 'execute'")
    func executeCommandName() {
        #expect(WorkOfflineMainCommand.Execute.configuration.commandName == "execute")
    }

    @Test("Execute: txIndex defaults to 0")
    func executeTxIndexDefault() throws {
        let cmd = try WorkOfflineMainCommand.Execute.parse([])
        #expect(cmd.txIndex == 0)
    }

    @Test("Execute: parses --tx-index")
    func executeParsesTxIndex() throws {
        let cmd = try WorkOfflineMainCommand.Execute.parse(["--tx-index", "2"])
        #expect(cmd.txIndex == 2)
    }

    @Test("Sync: commandName is 'sync'")
    func syncCommandName() {
        #expect(WorkOfflineMainCommand.Sync.configuration.commandName == "sync")
    }

    @Test("Sync: --address-file is required")
    func syncAddressFileRequired() {
        #expect(throws: (any Error).self) {
            _ = try WorkOfflineMainCommand.Sync.parse([])
        }
    }

    @Test("Sync: parses --address-file")
    func syncParsesAddressFile() throws {
        let cmd = try WorkOfflineMainCommand.Sync.parse(["--address-file", "/tmp/x.stake.addr"])
        #expect(cmd.addressFile.string == "/tmp/x.stake.addr")
    }

    @Test("ClearTx: commandName is 'clear-tx'")
    func clearTxCommandName() {
        #expect(WorkOfflineMainCommand.ClearTx.configuration.commandName == "clear-tx")
    }

    @Test("ClearFiles: commandName is 'clear-files'")
    func clearFilesCommandName() {
        #expect(WorkOfflineMainCommand.ClearFiles.configuration.commandName == "clear-files")
    }

    @Test("ClearHistory: commandName is 'clear-history'")
    func clearHistoryCommandName() {
        #expect(WorkOfflineMainCommand.ClearHistory.configuration.commandName == "clear-history")
    }
}
