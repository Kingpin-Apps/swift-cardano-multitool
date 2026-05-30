import Foundation

/// Outcome of a single process invocation.
public struct ProcessOutcome: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data

    public init(exitCode: Int32, stdout: Data = Data(), stderr: Data = Data()) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Abstraction over `Foundation.Process` invocations.
///
/// Production code uses `SystemProcessRunner`, which spawns a real subprocess. Tests
/// override `Processes.$current` with a `RecordedProcessRunner` (defined in the test
/// target) that returns canned `ProcessOutcome` values and records each invocation
/// for assertions.
///
/// Functions whose `Process()` use does not yet route through this protocol (notably
/// `runForegroundProcess` with its signal-forwarding loop) remain hard-coded against
/// `Foundation.Process`. Migrate them on demand.
public protocol ProcessRunner: Sendable {
    /// Spawn `executable` with the given arguments, wait for it to complete, and
    /// return its outcome. Throws if the process cannot be launched.
    ///
    /// - Parameters:
    ///   - executable: Absolute URL of the binary to run.
    ///   - arguments: Argument list (excluding argv[0]).
    ///   - environment: Override environment, or `nil` to inherit the parent's.
    func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutcome
}

extension ProcessRunner {
    /// Convenience overload that inherits the parent's environment.
    public func run(
        _ executable: URL,
        arguments: [String]
    ) async throws -> ProcessOutcome {
        try await run(executable, arguments: arguments, environment: nil)
    }
}

/// Production `ProcessRunner` that spawns a real `Foundation.Process`.
public struct SystemProcessRunner: ProcessRunner {

    public init() {}

    public func run(
        _ executable: URL,
        arguments: [String],
        environment: [String: String]?
    ) async throws -> ProcessOutcome {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessOutcome, Error>) in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(
                    returning: ProcessOutcome(
                        exitCode: proc.terminationStatus,
                        stdout: stdoutData,
                        stderr: stderrData
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Task-local override hook for the process runner.
public enum Processes {
    @TaskLocal public static var current: any ProcessRunner = SystemProcessRunner()
}
