import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.LeadershipSchedule")
struct QueryLeadershipScheduleTests {

    @Test("validate() defaults whichEpoch to .current when not supplied")
    func validateDefaultsWhichEpoch() throws {
        let cmd = try QueryMainCommand.LeadershipSchedule.parse([])
        #expect(cmd.whichEpoch == .current)
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
