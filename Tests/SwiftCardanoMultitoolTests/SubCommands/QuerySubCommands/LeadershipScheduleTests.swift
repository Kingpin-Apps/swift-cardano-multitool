import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.LeadershipSchedule")
struct QueryLeadershipScheduleTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(
            QueryMainCommand.LeadershipSchedule.configuration.abstract
                == "Query leadership schedule for a stake pool."
        )
    }

    @Test("default parse: identification options nil, validate defaults whichEpoch to .current")
    func defaults() throws {
        let cmd = try QueryMainCommand.LeadershipSchedule.parse([])
        #expect(cmd.poolName == nil)
        #expect(cmd.poolJSON == nil)
        #expect(cmd.poolOperator == nil)
        #expect(cmd.vrfSkey == nil)
        // ArgumentParser invokes validate() during parse, which defaults whichEpoch
        // to .current when not supplied.
        #expect(cmd.whichEpoch == .current)
        #expect(cmd.exportIcs == false)
        #expect(cmd.maintenanceSchedule == false)
        #expect(cmd.outputFile == nil)
    }

    @Test("--which-epoch=next is preserved through parse+validate")
    func explicitWhichEpoch() throws {
        let cmd = try QueryMainCommand.LeadershipSchedule.parse(["--which-epoch", "next"])
        #expect(cmd.whichEpoch == .next)
    }

    @Test("--export-ics and --maintenance-schedule flags flip their bools")
    func flags() throws {
        let cmd = try QueryMainCommand.LeadershipSchedule.parse([
            "--export-ics",
            "--maintenance-schedule"
        ])
        #expect(cmd.exportIcs == true)
        #expect(cmd.maintenanceSchedule == true)
    }
}
