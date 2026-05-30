import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.KesPeriodInfo")
struct QueryKesPeriodInfoTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(QueryMainCommand.KesPeriodInfo.configuration.abstract == "Query KES period.")
    }

    @Test("default parse leaves identification options nil; validate defaults whichPeriod to .current")
    func defaults() throws {
        let cmd = try QueryMainCommand.KesPeriodInfo.parse([])
        #expect(cmd.poolName == nil)
        #expect(cmd.poolJSON == nil)
        #expect(cmd.poolOperator == nil)
        #expect(cmd.opCert == nil)
        // ArgumentParser invokes validate() during parse, which defaults whichPeriod
        // to .current when not supplied.
        #expect(cmd.whichPeriod == .current)
    }

    @Test("--pool-name sets the pool name")
    func poolNameOption() throws {
        let cmd = try QueryMainCommand.KesPeriodInfo.parse(["--pool-name", "mypool"])
        #expect(cmd.poolName == "mypool")
    }

    @Test("--which-period accepts 'current' and 'next'")
    func whichPeriodOption() throws {
        let cmdCurrent = try QueryMainCommand.KesPeriodInfo.parse(["--which-period", "current"])
        #expect(cmdCurrent.whichPeriod == .current)
        let cmdNext = try QueryMainCommand.KesPeriodInfo.parse(["--which-period", "next"])
        #expect(cmdNext.whichPeriod == .next)
    }

    @Test("--pool-operator accepts a bech32 pool ID")
    func poolOperatorOption() throws {
        let cmd = try QueryMainCommand.KesPeriodInfo.parse([
            "--pool-operator", "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        ])
        #expect(cmd.poolOperator != nil)
    }
}
