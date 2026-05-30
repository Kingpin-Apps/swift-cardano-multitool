import ArgumentParser
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("DownloadMainCommand.ConfigurationFiles")
struct DownloadConfigurationFilesTests {

    @Test("default parse leaves network nil and flags false")
    func defaults() throws {
        let cmd = try DownloadMainCommand.ConfigurationFiles.parse([])
        #expect(cmd.network == nil)
        #expect(cmd.blockPoducer == false)
        #expect(cmd.dbSync == false)
        #expect(cmd.submitApi == false)
    }

    @Test("parses --network and flags")
    func parsesNetworkAndFlags() throws {
        let cmd = try DownloadMainCommand.ConfigurationFiles.parse([
            "--network", "preview",
            "--block-poducer",
            "--db-sync",
            "--submit-api"
        ])
        #expect(cmd.network == .preview)
        #expect(cmd.blockPoducer == true)
        #expect(cmd.dbSync == true)
        #expect(cmd.submitApi == true)
    }
}

@Suite("DownloadMainCommand.DatabaseSnapshot")
struct DownloadDatabaseSnapshotTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(DownloadMainCommand.DatabaseSnapshot.configuration.abstract == "Download blockchain snapshot.")
    }

    @Test("default network is nil")
    func defaultNetworkNil() throws {
        let cmd = try DownloadMainCommand.DatabaseSnapshot.parse([])
        #expect(cmd.network == nil)
    }

    @Test("parses --network")
    func parsesNetwork() throws {
        let cmd = try DownloadMainCommand.DatabaseSnapshot.parse(["--network", "mainnet"])
        #expect(cmd.network == .mainnet)
    }
}
