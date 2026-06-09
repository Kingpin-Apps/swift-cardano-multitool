import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.StakePool")
struct QueryStakePoolTests {

    @Test("--pool-name sets the pool name")
    func poolNameOption() throws {
        let cmd = try QueryMainCommand.StakePool.parse(["--pool-name", "alphapool"])
        #expect(cmd.poolName == "alphapool")
    }

    @Test("--pool-operator accepts a bech32 pool ID")
    func poolOperatorBech32() throws {
        let cmd = try QueryMainCommand.StakePool.parse([
            "--pool-operator", "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        ])
        #expect(cmd.poolOperator != nil)
    }
}
