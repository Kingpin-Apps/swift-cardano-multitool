import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

// MARK: - WorkOffline.Sync

@Suite("WorkOfflineMainCommand.Sync")
struct WorkOfflineSyncTests {

    @Test("commandName is 'sync'")
    func commandName() {
        #expect(WorkOfflineMainCommand.Sync.configuration.commandName == "sync")
    }

    @Test("parses --address-file")
    func parsesAddressFile() throws {
        let cmd = try WorkOfflineMainCommand.Sync.parse([
            "--address-file", "/tmp/foo.addr"
        ])
        #expect(cmd.addressFile.string == "/tmp/foo.addr")
        #expect(cmd.inFile == nil)
    }
}

// MARK: - Query.StakePool

@Suite("QueryMainCommand.StakePool (extended)")
struct QueryStakePoolExtendedTests {

    @Test("commandName is 'stake-pool'")
    func commandName() {
        #expect(QueryMainCommand.StakePool.configuration.commandName == "stake-pool")
    }

    @Test("alias 'pool' is registered")
    func aliasPool() {
        #expect(QueryMainCommand.StakePool.configuration.aliases.contains("pool"))
    }

    @Test("parses with no args")
    func defaults() throws {
        let cmd = try QueryMainCommand.StakePool.parse([])
        #expect(cmd.poolName == nil)
        #expect(cmd.poolOperator == nil)
        #expect(cmd.poolJSON == nil)
    }

    @Test("parses --pool-name option")
    func parsesPoolName() throws {
        let cmd = try QueryMainCommand.StakePool.parse(["--pool-name", "myPool"])
        #expect(cmd.poolName == "myPool")
    }
}

// MARK: - Transaction.RewardsWithdraw

@Suite("TransactionMainCommand.RewardsWithdraw (extended)")
struct TransactionRewardsWithdrawExtendedTests {

    @Test("abstract is populated")
    func abstract() {
        #expect(!TransactionMainCommand.RewardsWithdraw.configuration.abstract.isEmpty)
    }

    @Test("parses with no args")
    func defaults() throws {
        let cmd = try TransactionMainCommand.RewardsWithdraw.parse([])
        #expect(cmd.stakeAddress == nil)
    }
}

// MARK: - Run.SubmitApi

@Suite("RunMainCommand.SubmitApi")
struct RunSubmitApiTests {

    @Test("commandName is 'submit-api'")
    func commandName() {
        #expect(RunMainCommand.SubmitApi.configuration.commandName == "submit-api")
    }

    @Test("parses with no args")
    func defaults() throws {
        _ = try RunMainCommand.SubmitApi.parse([])
    }
}

// MARK: - Run.Wallet

@Suite("RunMainCommand.Wallet")
struct RunWalletTests {

    @Test("commandName is 'cardano-wallet'")
    func commandName() {
        #expect(RunMainCommand.Wallet.configuration.commandName == "cardano-wallet")
    }

    @Test("parses with no args; mainnet flag defaults to false")
    func defaults() throws {
        let cmd = try RunMainCommand.Wallet.parse([])
        #expect(cmd.nodeSocket == nil)
        #expect(cmd.database == nil)
        #expect(cmd.port == nil)
        #expect(cmd.testnet == nil)
        #expect(cmd.mainnet == false)
    }

    @Test("--mainnet flag flips the bool")
    func parsesMainnetFlag() throws {
        let cmd = try RunMainCommand.Wallet.parse(["--mainnet"])
        #expect(cmd.mainnet == true)
    }
}

// MARK: - Run.DbSync

@Suite("RunMainCommand.DbSync")
struct RunDbSyncTests {

    @Test("commandName is 'db-sync'")
    func commandName() {
        #expect(RunMainCommand.DbSync.configuration.commandName == "db-sync")
    }

    @Test("parses with no args")
    func defaults() throws {
        _ = try RunMainCommand.DbSync.parse([])
    }
}
