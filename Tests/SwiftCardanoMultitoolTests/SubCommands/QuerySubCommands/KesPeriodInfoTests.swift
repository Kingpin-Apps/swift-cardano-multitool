import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.KesPeriodInfo")
struct QueryKesPeriodInfoTests {

    @Test("validate() defaults whichPeriod to .current when not supplied")
    func validateDefaultsWhichPeriod() throws {
        let cmd = try QueryMainCommand.KesPeriodInfo.parse([])
        #expect(cmd.whichPeriod == .current)
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
