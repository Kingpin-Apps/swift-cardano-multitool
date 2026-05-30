import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// Smoke tests for all MainCommands.
///
/// Each MainCommand pairs an `AsyncParsableCommand & MainCommandable` struct with a
/// `<Name>Commands` enum conforming to `Subcommandable`. These tests verify the
/// argument-parser configuration is well-formed and that the subcommand list lines
/// up with the enum. `VersionMainCommand` is excluded because it has a different
/// shape (no subcommands; `run()` hits the chain).
@Suite("MainCommands smoke tests")
struct MainCommandsTests {

    @Test("BuildMainCommand has commandName 'build' and matching subcommands")
    func buildCommand() {
        #expect(BuildMainCommand.configuration.commandName == "build")
        #expect(BuildMainCommand.configuration.subcommands.count == BuildCommands.subcommands.count)
        #expect(BuildMainCommand.configuration.subcommands.count > 0)
    }

    @Test("CertificateMainCommand has commandName 'certificate' and matching subcommands")
    func certificateCommand() {
        #expect(CertificateMainCommand.configuration.commandName == "certificate")
        #expect(CertificateMainCommand.configuration.subcommands.count == CertificateCommands.subcommands.count)
        #expect(CertificateMainCommand.configuration.subcommands.count > 0)
    }

    @Test("ConfigMainCommand has commandName 'config' and matching subcommands")
    func configCommand() {
        #expect(ConfigMainCommand.configuration.commandName == "config")
        #expect(ConfigMainCommand.configuration.subcommands.count == ConfigCommands.subcommands.count)
        #expect(ConfigMainCommand.configuration.subcommands.count > 0)
    }

    @Test("DownloadMainCommand has commandName 'download' and matching subcommands")
    func downloadCommand() {
        #expect(DownloadMainCommand.configuration.commandName == "download")
        #expect(DownloadMainCommand.configuration.subcommands.count == DownloadCommands.subcommands.count)
        #expect(DownloadMainCommand.configuration.subcommands.count > 0)
    }

    @Test("GenerateMainCommand has commandName 'generate' and matching subcommands")
    func generateCommand() {
        #expect(GenerateMainCommand.configuration.commandName == "generate")
        #expect(GenerateMainCommand.configuration.subcommands.count == GenerateCommands.subcommands.count)
        #expect(GenerateMainCommand.configuration.subcommands.count > 0)
    }

    @Test("InstallMainCommand has commandName 'install' and matching subcommands")
    func installCommand() {
        #expect(InstallMainCommand.configuration.commandName == "install")
        #expect(InstallMainCommand.configuration.subcommands.count == InstallCommands.subcommands.count)
        #expect(InstallMainCommand.configuration.subcommands.count > 0)
    }

    @Test("ProtectMainCommand has commandName 'protect' and matching subcommands")
    func protectCommand() {
        #expect(ProtectMainCommand.configuration.commandName == "protect")
        #expect(ProtectMainCommand.configuration.subcommands.count == ProtectCommands.subcommands.count)
        #expect(ProtectMainCommand.configuration.subcommands.count > 0)
    }

    @Test("QueryMainCommand has commandName 'query' and matching subcommands")
    func queryCommand() {
        #expect(QueryMainCommand.configuration.commandName == "query")
        #expect(QueryMainCommand.configuration.subcommands.count == QueryCommands.subcommands.count)
        #expect(QueryMainCommand.configuration.subcommands.count > 0)
    }

    @Test("RunMainCommand has commandName 'run' and matching subcommands")
    func runCommand() {
        #expect(RunMainCommand.configuration.commandName == "run")
        #expect(RunMainCommand.configuration.subcommands.count == RunCommands.subcommands.count)
        #expect(RunMainCommand.configuration.subcommands.count > 0)
    }

    @Test("SendMainCommand has commandName 'send' and matching subcommands")
    func sendCommand() {
        #expect(SendMainCommand.configuration.commandName == "send")
        #expect(SendMainCommand.configuration.subcommands.count == SendCommands.subcommands.count)
        #expect(SendMainCommand.configuration.subcommands.count > 0)
    }

    @Test("TransactionMainCommand has commandName 'transaction' and matching subcommands")
    func transactionCommand() {
        #expect(TransactionMainCommand.configuration.commandName == "transaction")
        #expect(TransactionMainCommand.configuration.subcommands.count == TransactionCommands.subcommands.count)
        #expect(TransactionMainCommand.configuration.subcommands.count > 0)
    }

    @Test("WorkOfflineMainCommand has commandName 'work-offline' and matching subcommands")
    func workOfflineCommand() {
        #expect(WorkOfflineMainCommand.configuration.commandName == "work-offline")
        #expect(WorkOfflineMainCommand.configuration.subcommands.count == WorkOfflineCommands.subcommands.count)
        #expect(WorkOfflineMainCommand.configuration.subcommands.count > 0)
    }

    // MARK: - Subcommandable enums

    @Test("every Subcommandable enum's subcommands excludes back and exit cases")
    func subcommandsListExcludesBackAndExit() {
        // Each enum keeps `.back` and `.exit` cases for the interactive menu but excludes them
        // from the static subcommands list. Verify the filter for a representative subset.
        #expect(BuildCommands.subcommands.count == BuildCommands.allCases.count - 2)
        #expect(ConfigCommands.subcommands.count == ConfigCommands.allCases.count - 2)
        #expect(GenerateCommands.subcommands.count == GenerateCommands.allCases.count - 2)
        #expect(QueryCommands.subcommands.count == QueryCommands.allCases.count - 2)
        #expect(TransactionCommands.subcommands.count == TransactionCommands.allCases.count - 2)
    }
}

@Suite("VersionMainCommand")
struct VersionMainCommandTests {

    @Test("commandName is 'version'")
    func commandName() {
        #expect(VersionMainCommand.configuration.commandName == "version")
    }

    @Test("has no subcommands (direct command, not a dispatcher)")
    func noSubcommands() {
        #expect(VersionMainCommand.configuration.subcommands.isEmpty)
    }
}
