import Foundation

/// Serialises tests that depend on the process working directory.
///
/// The working directory is process-wide, and Swift Testing runs tests in
/// parallel — including across suites, which `.serialized` does not cover. Any
/// test that chdirs has to take this lock, or one test's directory change lands
/// in the middle of another's and both see the wrong directory.
enum WorkingDirectory {
    private static let lock = NSLock()

    /// Run `body` with the current directory set to `path`, restoring it after.
    static func withCurrent<T>(_ path: String, _ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        let previous = FileManager.default.currentDirectoryPath
        defer { _ = FileManager.default.changeCurrentDirectoryPath(previous) }

        _ = FileManager.default.changeCurrentDirectoryPath(path)
        return try body()
    }
}
