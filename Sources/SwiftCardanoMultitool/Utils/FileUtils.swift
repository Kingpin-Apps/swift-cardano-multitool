/// FileUtils.swift
///
/// A collection of filesystem utilities.
///
/// This helper centralizes common operations such as:
/// - Existence checks for files and Unix sockets
/// - Reading and writing plain text and JSON
/// - Simple file permission changes (chmod)
/// - Cooperative "lock/unlock" flows that temporarily relax permissions
/// - Convenience display helpers and basic downloading
///
/// Conventions:
/// - "Lock" sets permissions to 0400 (owner read-only). "Unlock" sets 0600 (owner read/write).
/// - Functions that read or write a "locked" file call `fileUnlock` before I/O and `fileLock` afterward.
/// - Most throwing functions surface `SwiftCardanoMultitoolError` when an expected precondition fails, or
///   `ExitCode.validationFailure` when a user-facing validation message has already been emitted.
/// - Socket checks are supported on Apple platforms via Darwin constants and guarded elsewhere.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import SystemPackage
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import ArgumentParser
import Noora
import Path

/// Namespace for filesystem helpers used across commands.
///
/// All functions are static and designed for CLI-style workflows. Many helpers
/// assume `FilePath` from SystemPackage and interoperate with Foundation's FileManager.
public struct FileUtils {
    
    /// Verifies that a regular file exists at `path`.
    /// - Parameter path: Absolute or relative `FilePath` to check.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound` if the file is missing or is a directory.
    public static func checkFileExists(_ path: FilePath) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(
            atPath: path.string,
            isDirectory: &isDir
        ) || isDir.boolValue {
            throw SwiftCardanoMultitoolError.fileNotFound(path)
        }
    }
    
    /// Verifies that no file exists at `path`.
    /// - Parameter path: Absolute or relative `FilePath` to check.
    /// - Throws: `SwiftCardanoMultitoolError.fileAlreadyExists` if a file or directory exists.
    public static func checkFileNotExists(_ path: FilePath) throws {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(
            atPath: path.string,
            isDirectory: &isDir
        ) {
            throw SwiftCardanoMultitoolError.fileAlreadyExists(path)
        }
    }
    
    /// Ensures a target path is free before creating a file, emitting a user-facing alert if not.
    ///
    /// If the file already exists, an alert is printed and `ExitCode.validationFailure` is thrown.
    /// - Parameter path: Target file path that must not exist.
    /// - Throws: `ExitCode.validationFailure` when the path is already taken.
    public static func checkFile(_ path: FilePath) async throws -> Void {
        do {
            try checkFileNotExists(path)
        } catch {
            noora.error(
                .alert(
                    "File already exists at path: \(.path(try .init(validating: path.string)))",
                    takeaways: [
                        "Delete the file and try again.",
                        "Use a different name for the file."
                    ]
                )
            )
            throw ExitCode.validationFailure
        }
    }
    
    /// Changes file permissions using an octal string (e.g. "600", "400").
    /// - Parameters:
    ///   - path: The file to modify.
    ///   - perms: Octal permission string.
    /// - Throws: `SwiftCardanoMultitoolError.ioError` if conversion fails or `chmod` returns an error.
    public static func chmodFile(_ path: FilePath, perms: String) throws {
        try checkFileExists(path)
        guard let mode = UInt32(perms, radix: 8) else {
            throw SwiftCardanoMultitoolError.ioError(NSError(domain: "Invalid permission", code: 0))
        }
        if chmod(path.string, mode_t(mode)) != 0 {
            throw SwiftCardanoMultitoolError.ioError(NSError(domain: "chmod failed", code: Int(errno)))
        }
    }
    
    /// Attempts to lock a file by setting permissions to 0400 (owner read-only).
    /// Emits a warning if locking fails but does not throw.
    /// - Parameter path: The file to lock.
    public static func fileLock(_ path: FilePath) async throws {
        do {
            try chmodFile(path, perms: "400")
        } catch {
            noora.warning(.alert("Could not lock file: \(.path(try .init(validating: path.string)))"))
        }
    }
    
    /// Unlocks a file by setting permissions to 0600 (owner read/write).
    /// Emits a detailed error and throws `ExitCode.validationFailure` if unlocking fails.
    /// - Parameter path: The file to unlock.
    public static func fileUnlock(_ path: FilePath) async throws {
        if FileManager.default.fileExists(atPath: path.string) {
            do {
                try chmodFile(path, perms: "600")
            } catch {
                noora.error(
                    .alert(
                        "Could not unlock file: \(.path(try .init(validating: path.string)))",
                        takeaways: [
                            "Check the file permissions and try again.",
                            "Make sure you have the necessary permissions to modify the file."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
        }
    }
    
    /// Best-effort cleanup routine that unlocks and removes a list of files, then terminates.
    /// Displays progress and throws `ExitCode.failure` after attempting cleanup.
    /// - Parameter files: Files to unlock and remove.
    /// - Throws: Always throws `ExitCode.failure` after completion.
    public static func terminate(_ files: [FilePath]) async throws -> Never {
        try await noora.progressStep(
            message: "Cleaning up files...",
            successMessage: "Files removed.",
            errorMessage: "Failed to remove files.",
            showSpinner: true
        ) { updateProgress in
            for (index, file) in files.enumerated() {
                try await fileUnlock(file)
                try? FileManager.default.removeItem(atPath: file.string)
                updateProgress(String(index / files.count))
            }
        }
        throw ExitCode.failure
    }
    
    /// Validates that a path exists and is a Unix domain socket on Apple platforms.
    /// - Parameter path: Path to the socket file.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound`, `.ioError`, or `.notSocket`.
    public static func checkSocket(_ path: FilePath) throws {
        guard FileManager.default.fileExists(atPath: path.string) else {
            throw SwiftCardanoMultitoolError.fileNotFound(path)
        }
        var st = stat()
        if stat(path.string, &st) != 0 {
            throw SwiftCardanoMultitoolError.ioError(NSError(domain: "stat failed", code: Int(errno)))
        }
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let type = st.st_mode & S_IFMT
        if type != S_IFSOCK {
            throw SwiftCardanoMultitoolError.notSocket(path)
        }
    #else
        // Fallback: treat as not socket
        throw SwiftCardanoMultitoolError.notSocket(path)
    #endif
    }
    
    /// Loads a UTF-8 text file and trims surrounding whitespace/newlines.
    /// - Parameter path: File to read.
    /// - Returns: The trimmed string contents.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound` or I/O errors from Foundation.
    public static func loadFile(_ path: FilePath) throws -> String {
        try checkFileExists(path)
        let s = try String(contentsOfFile: path.string, encoding: .utf8)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Temporarily unlocks a file, reads it as UTF-8 text, then relocks it.
    /// - Parameter path: File to read.
    /// - Returns: The trimmed string contents.
    public static func loadLockedFile(_ path: FilePath) async throws -> String {
        try await fileUnlock(path)
        let s = try String(contentsOfFile: path.string, encoding: .utf8)
        try await fileLock(path)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Loads and deserializes a JSON file into a `[String: Any]` dictionary.
    /// - Parameter path: JSON file to read.
    /// - Returns: A dictionary of JSON values.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound` or `SwiftCardanoMultitoolError.jsonError` if the top-level is not a dictionary.
    public static func loadJSONFile(_ path: FilePath) throws -> [String: Any] {
        try checkFileExists(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw SwiftCardanoMultitoolError.jsonError("Top-level JSON is not a dictionary")
        }
        return dict
    }
    
    /// Temporarily unlocks a file, loads JSON, then relocks it.
    /// - Parameter path: JSON file to read.
    /// - Returns: A dictionary keyed by `String` with `Any` values.
    /// - Throws: `SwiftCardanoMultitoolError.jsonError` if the top-level is not a dictionary.
    public static func loadLockedJSONFile(_ path: FilePath) async throws -> [String: Any] {
        try await fileUnlock(path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        try await fileLock(path)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            throw SwiftCardanoMultitoolError.jsonError("Top-level JSON is not a dictionary")
        }
        return dict
    }
    
    /// Writes a UTF-8 string to `path` atomically.
    /// - Parameters:
    ///   - path: Destination file path.
    ///   - data: String contents to write.
    public static func dumpFile(_ path: FilePath, data: String) throws {
        let d = Data(data.utf8)
        try d.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }
    
    /// Unlocks if needed, writes a UTF-8 string atomically, then locks again.
    /// - Parameters:
    ///   - path: Destination file path.
    ///   - data: String contents to write.
    public static func dumpLockedFile(_ path: FilePath, data: String) async throws {
        do {
            try await fileUnlock(path)
        } catch {
            // ignore if file didn't exist
        }
        try dumpFile(path, data: data)
        try await fileLock(path)
    }
    
    /// Serializes a dictionary to pretty-printed JSON and writes it atomically.
    /// - Parameters:
    ///   - path: Destination JSON file.
    ///   - data: Dictionary to encode.
    public static func dumpJSONFile(_ path: FilePath, data: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted])
        try jsonData.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }
    
    /// Unlocks if needed, writes pretty-printed JSON, then locks again.
    /// - Parameters:
    ///   - path: Destination JSON file.
    ///   - data: Dictionary to encode.
    public static func dumpLockedJSONFile(_ path: FilePath, data: [String: Any]) async throws {
        try await  dumpLockedFile(path, data: String(data: try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted]), encoding: .utf8) ?? "{}")
    }
    
    /// Downloads data from a URL and saves it atomically to `path`.
    /// - Parameters:
    ///   - url: Source URL.
    ///   - path: Destination file path.
    /// - Throws: Network or I/O errors; `URLError.badServerResponse` for non-2xx HTTP codes.
    public static func downloadFile(_ url: URL, to path: FilePath) async throws {
        // Download the data using URLSession's modern async API
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Verify the response is successful
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Write the data to the file path
        try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }
    
    /// Removes a file at `path` if it exists.
    /// - Parameter path: File to delete.
    /// - Throws: Errors from `FileManager.removeItem`.
    public static func cleanupFile(_ path: FilePath) throws {
        try FileManager.default.removeItem(atPath: path.string)
    }
    
    /// Reads a file and returns its Base64-encoded data.
    /// - Parameter path: File to encode.
    /// - Returns: Base64-encoded `Data`.
    public static func base64EncodedFile(_ path: FilePath) throws -> Data {
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        return data.base64EncodedData()
    }
    
    /// Prints the contents of a locked file to the terminal, optionally truncated.
    /// - Parameters:
    ///   - path: File to display.
    ///   - maxChars: If provided, prints only the leading prefix followed by an indicator.
    public static func displayFile(_ path: FilePath, maxChars: Int? = nil) async throws {
        do {
            let s = try await loadLockedFile(path)
            printFileMetadata(path)
            printDivider("─")
            if let max = maxChars, s.count > max {
                spacedPrint("\(String(s.prefix(max))) ... (cropped)")
            } else {
                spacedPrint("\(s)")
            }
            printDivider("─")
        } catch {
            noora.warning(.alert("Error reading file: \(error)"))
        }
    }

    /// Pretty-prints a locked JSON file to the terminal.
    /// - Parameter path: JSON file to display.
    public static func displayJSONFile(_ path: FilePath) async throws -> Void {
        do {
            let obj = try await loadLockedJSONFile(path)

            let jsonData = try JSONSerialization.data(
                withJSONObject: obj,
                options: [.prettyPrinted, .withoutEscapingSlashes]
            )

            if let jsonString = String(data: jsonData, encoding: .utf8) {
                printFileMetadata(path)
                printDivider("─")
                print(jsonString)
                printDivider("─")
            }
        } catch {
            noora.warning(.alert("Error reading JSON file: \(error)"))
        }
    }

    /// Prints a `noora.info` alert summarizing a file's name, path, size, permissions,
    /// and modification time. Best-effort: any attribute that can't be read is skipped.
    /// - Parameter path: The file to describe.
    public static func printFileMetadata(_ path: FilePath) {
        let fileName = path.lastComponent?.string ?? path.string

        var takeaways: [TerminalText] = []

        let absolutePath: String
        if path.string.hasPrefix("/") {
            absolutePath = path.string
        } else {
            absolutePath = FilePath(FileManager.default.currentDirectoryPath)
                .appending(path.string).string
        }
        if let validatedPath = try? AbsolutePath(validating: absolutePath) {
            takeaways.append("Path: \(.path(validatedPath))")
        } else {
            takeaways.append("Path: \(.primary(path.string))")
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: path.string) {
            if let size = attrs[.size] as? NSNumber {
                takeaways.append("Size: \(.primary(formatByteSize(size.int64Value)))")
            }
            if let perms = attrs[.posixPermissions] as? NSNumber {
                takeaways.append("Permissions: \(.primary(formatPosixPermissions(perms.intValue)))")
            }
            if let modified = attrs[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                takeaways.append("Modified: \(.primary(formatter.string(from: modified)))")
            }
        }
        
        printDivider()
        noora.info(.alert("File: \(.primary(fileName))", takeaways: takeaways))
    }

    /// Formats a byte count as a human-readable string (e.g. `"1.2 KB"`).
    private static func formatByteSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Formats POSIX permission bits as an `rwxrwxrwx`-style string.
    /// - Parameter mode: The integer permission bits (e.g. `0o644`).
    private static func formatPosixPermissions(_ mode: Int) -> String {
        let triplets: [(Int, Int, Int)] = [
            (0o400, 0o200, 0o100), // owner
            (0o040, 0o020, 0o010), // group
            (0o004, 0o002, 0o001), // other
        ]
        var result = ""
        for (r, w, x) in triplets {
            result += (mode & r) != 0 ? "r" : "-"
            result += (mode & w) != 0 ? "w" : "-"
            result += (mode & x) != 0 ? "x" : "-"
        }
        return result
    }
    
    /// Searches the current directory for files matching a pattern and returns the lexicographically latest.
    /// Pattern: `"{startswith}."` prefix, contains `contains`, and suffix `".{endswith}"`.
    /// - Returns: The latest matching `FilePath`, or `nil` after emitting a warning.
    public static func searchLatestFile(startswith: String, contains: String, endswith: String) throws -> FilePath? {
        let cwdPathString = FileManager.default.currentDirectoryPath
        let cwdPath = FilePath(cwdPathString)
        
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: cwdPathString) else {
            return nil
        }
        
        let candidates = items.compactMap { name -> FilePath? in
            let filePath = cwdPath.appending(name)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath.string, isDirectory: &isDir), !isDir.boolValue else { return nil }
            if name.hasPrefix("\(startswith).") && name.contains(contains) && name.hasSuffix(".\(endswith)") {
                return filePath
            }
            return nil
        }.sorted { lhs, rhs in
            lhs.lastComponent?.string ?? "" < rhs.lastComponent?.string ?? ""
        }
        
        guard let latest = candidates.last else {
            noora.warning(.alert("Could not find \(startswith).\(contains)-*.\(endswith) in \(cwdPathString)"))
            return nil
        }
        
        try checkFileExists(latest)
        return latest
    }
    
    /// Unlocks a file only if it already exists.
    /// - Parameter path: File to conditionally unlock.
    public static func unlockIfExists(_ path: FilePath) async throws -> Void {
        if FileManager.default.fileExists(atPath: path.string) {
            try await fileUnlock(path)
        }
    }
    
    /// Returns the file size in bytes, or `nil` if unavailable.
    /// - Parameter path: File whose size is requested.
    public static func fileSize(_ path: FilePath) -> Int? {
        do {
            try checkFileExists(path)
            let attrs = try FileManager.default.attributesOfItem(atPath: path.string)
            if let size = attrs[.size] as? NSNumber {
                return size.intValue
            }
        } catch {
            return nil
        }
        return nil
    }
}

