import ArgumentParser
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("DownloadMainCommand")
struct DownloadCommandsTests {

    @Test("ConfigurationFiles: parses --network and all profile flags")
    func configurationFilesParsesAll() throws {
        let cmd = try DownloadMainCommand.ConfigurationFiles.parse([
            "--network", "preview",
            "--block-producer",
            "--db-sync",
            "--submit-api"
        ])
        #expect(cmd.network == .preview)
        #expect(cmd.blockProducer == true)
        #expect(cmd.dbSync == true)
        #expect(cmd.submitApi == true)
    }

    @Test("DatabaseSnapshot: parses --network")
    func databaseSnapshotParsesNetwork() throws {
        let cmd = try DownloadMainCommand.DatabaseSnapshot.parse(["--network", "mainnet"])
        #expect(cmd.network == .mainnet)
    }
}
