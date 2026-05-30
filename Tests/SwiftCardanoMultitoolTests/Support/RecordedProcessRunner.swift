import Foundation
@testable import SwiftCardanoMultitool

/// Test-only `ProcessRunner` that returns canned `ProcessOutcome` values in order
/// and records every invocation for assertions.
///
/// Construct with a sequence of outcomes, install via `Processes.$current.withValue(...)`,
/// and the code under test will receive scripted results instead of spawning processes.
public final class RecordedProcessRunner: ProcessRunner, @unchecked Sendable {

    public struct Invocation: Sendable, Equatable {
        public let executable: URL
        public let arguments: [String]
        public let environment: [String: String]?
    }

    private let lock = NSLock()
    private var outcomes: [ProcessOutcome]
    public private(set) var invocations: [Invocation] = []

    public init(outcomes: [ProcessOutcome]) {
        self.outcomes = outcomes
    }

    /// Convenience initialiser for the common "always succeeds" case.
    public convenience init(alwaysExit exitCode: Int32 = 0, count: Int = 1) {
        self.init(outcomes: Array(repeating: ProcessOutcome(exitCode: exitCode), count: count))
    }

    public func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutcome {
        lock.withLock {
            invocations.append(
                Invocation(executable: executable, arguments: arguments, environment: environment)
            )
            precondition(
                !outcomes.isEmpty,
                "RecordedProcessRunner: no more scripted outcomes (call #\(invocations.count))"
            )
            return outcomes.removeFirst()
        }
    }
}
