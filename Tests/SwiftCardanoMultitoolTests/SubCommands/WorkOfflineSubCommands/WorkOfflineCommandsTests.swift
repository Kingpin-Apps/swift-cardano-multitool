import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("WorkOfflineMainCommand parsing behavior")
struct WorkOfflineCommandsTests {

    @Test("New: parses --out-file")
    func newParsesOutFile() throws {
        let cmd = try WorkOfflineMainCommand.New.parse(["--out-file", "/tmp/offline.json"])
        #expect(cmd.outFile?.string == "/tmp/offline.json")
    }

    @Test("Info: parses --in-file")
    func infoParsesInFile() throws {
        let cmd = try WorkOfflineMainCommand.Info.parse(["--in-file", "/tmp/offline.json"])
        #expect(cmd.inFile?.string == "/tmp/offline.json")
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

    @Test("Extract: parses --in-file and --out-dir")
    func extractParses() throws {
        let cmd = try WorkOfflineMainCommand.Extract.parse([
            "--in-file", "/tmp/offline.json",
            "--out-dir", "/tmp/extract-here"
        ])
        #expect(cmd.inFile?.string == "/tmp/offline.json")
        #expect(cmd.outDir?.string == "/tmp/extract-here")
    }

    @Test("Execute: txIndex defaults to 0 and parses --tx-index")
    func executeTxIndex() throws {
        let zero = try WorkOfflineMainCommand.Execute.parse([])
        #expect(zero.txIndex == 0)
        let two = try WorkOfflineMainCommand.Execute.parse(["--tx-index", "2"])
        #expect(two.txIndex == 2)
    }

    @Test("Sync: --address-file is required and parses when provided")
    func syncAddressFile() throws {
        #expect(throws: (any Error).self) {
            _ = try WorkOfflineMainCommand.Sync.parse([])
        }
        let cmd = try WorkOfflineMainCommand.Sync.parse(["--address-file", "/tmp/x.stake.addr"])
        #expect(cmd.addressFile.string == "/tmp/x.stake.addr")
    }
}
