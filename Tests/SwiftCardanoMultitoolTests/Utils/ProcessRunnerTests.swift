import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("ProcessOutcome")
struct ProcessOutcomeTests {

    @Test("defaults stdout and stderr to empty Data")
    func defaultsEmpty() {
        let o = ProcessOutcome(exitCode: 0)
        #expect(o.stdout.isEmpty)
        #expect(o.stderr.isEmpty)
    }

    @Test("preserves all init values")
    func preservesValues() {
        let o = ProcessOutcome(
            exitCode: 7,
            stdout: Data("hello".utf8),
            stderr: Data("oops".utf8)
        )
        #expect(o.exitCode == 7)
        #expect(String(data: o.stdout, encoding: .utf8) == "hello")
        #expect(String(data: o.stderr, encoding: .utf8) == "oops")
    }
}

@Suite("SystemProcessRunner")
struct SystemProcessRunnerTests {

    @Test("captures stdout from /bin/echo")
    func capturesStdout() async throws {
        let runner = SystemProcessRunner()
        let outcome = try await runner.run(
            URL(fileURLWithPath: "/bin/echo"),
            arguments: ["hello world"],
            environment: nil
        )
        #expect(outcome.exitCode == 0)
        let text = String(data: outcome.stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(text == "hello world")
    }

    @Test("returns the exit code of /usr/bin/false")
    func returnsNonZeroExitCode() async throws {
        let runner = SystemProcessRunner()
        let outcome = try await runner.run(
            URL(fileURLWithPath: "/usr/bin/false"),
            arguments: [],
            environment: nil
        )
        #expect(outcome.exitCode != 0)
    }
}

@Suite("Processes task-local override")
struct ProcessesOverrideTests {

    @Test("pullContainerImage uses the overridden runner and succeeds on exit code 0")
    func pullSucceedsViaStub() async throws {
        let runner = RecordedProcessRunner(alwaysExit: 0)
        try await Processes.$current.withValue(runner) {
            try await pullContainerImage(cli: "docker", image: "alpine:latest")
        }
        #expect(runner.invocations.count == 1)
        #expect(runner.invocations[0].arguments == ["docker", "pull", "alpine:latest"])
    }

    @Test("pullContainerImage throws operationError on non-zero exit")
    func pullFailsViaStub() async throws {
        let runner = RecordedProcessRunner(outcomes: [ProcessOutcome(exitCode: 125)])
        await #expect(throws: SwiftCardanoMultitoolError.self) {
            try await Processes.$current.withValue(runner) {
                try await pullContainerImage(cli: "docker", image: "alpine:nope")
            }
        }
    }
}
