import Foundation

/// Serialises tests that depend on the process working directory.
///
/// The working directory is process-wide, and Swift Testing runs tests in
/// parallel — including across suites, which `.serialized` does not cover. Any
/// test that chdirs, or reads the current directory, has to take this lock, or
/// one test's directory change lands in the middle of another's and both see
/// the wrong directory.
///
/// A semaphore rather than a lock: the async variant may resume on a different
/// thread than the one that acquired it, which a semaphore allows.
enum WorkingDirectory {
    private static let semaphore = DispatchSemaphore(value: 1)

    /// Run `body` with the current directory set to `path`, restoring it after.
    static func withCurrent<T>(_ path: String, _ body: () throws -> T) rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }

        let previous = FileManager.default.currentDirectoryPath
        defer { _ = FileManager.default.changeCurrentDirectoryPath(previous) }

        _ = FileManager.default.changeCurrentDirectoryPath(path)
        return try body()
    }

    /// Async variant of `withCurrent(_:_:)`, sharing the same lock.
    ///
    /// Waiting blocks a cooperative thread, but only while another working-directory
    /// test holds the lock, which is short and acceptable in tests.
    static func withCurrent<T>(_ path: String, _ body: () async throws -> T) async rethrows -> T {
        acquire()
        defer { semaphore.signal() }

        let previous = FileManager.default.currentDirectoryPath
        defer { _ = FileManager.default.changeCurrentDirectoryPath(previous) }

        _ = FileManager.default.changeCurrentDirectoryPath(path)
        return try await body()
    }

    private static func acquire() {
        semaphore.wait()
    }
}
