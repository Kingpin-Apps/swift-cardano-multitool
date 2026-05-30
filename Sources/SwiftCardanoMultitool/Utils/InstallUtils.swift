import Foundation
import Dispatch
import SystemPackage
import ArgumentParser
import Noora

// MARK: - Install Method

enum InstallMethod: String, CaseIterable, AlignedChoiceDescribable {
    case binary
    case docker
    case appleContainer = "apple-container"

    var name: String {
        switch self {
            case .binary: return "Binary"
            case .docker: return "Docker"
            case .appleContainer: return "Apple Container"
        }
    }

    var details: String {
        switch self {
            case .binary: return "Download and install the pre-built binary for your platform."
            case .docker: return "Pull the official Docker image."
            case .appleContainer: return "Pull using Apple's container CLI (macOS only)."
        }
    }

    /// Available methods for the current platform
    static var available: [InstallMethod] {
        #if os(macOS)
        return allCases
        #else
        return [.binary, .docker]
        #endif
    }
}

// MARK: - GitHub API Types

struct GitHubRelease: Decodable, Sendable {
    let tagName: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

struct GitHubAsset: Decodable, Sendable {
    let name: String
    let browserDownloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
}

// MARK: - Platform Detection

enum CurrentPlatform {
    #if os(macOS)
    static let os = "macos"
    static let osAlternates = ["macos", "darwin", "apple"]
    #elseif os(Linux)
    static let os = "linux"
    static let osAlternates = ["linux"]
    #else
    static let os = "unknown"
    static let osAlternates: [String] = []
    #endif

    #if arch(arm64)
    static let arch = "arm64"
    static let archAlternates = ["arm64", "aarch64"]
    #elseif arch(x86_64)
    static let arch = "x86_64"
    static let archAlternates = ["x86_64", "amd64"]
    #else
    static let arch = "unknown"
    static let archAlternates: [String] = []
    #endif
}

// MARK: - Install Utilities

/// Fetch the latest GitHub release for a given owner/repo.
func fetchLatestRelease(owner: String, repo: String) async throws -> GitHubRelease {
    let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw SwiftCardanoMultitoolError.downloadFailed(url, "GitHub API returned HTTP \(code). Check rate limits or repo name.")
    }
    return try JSONDecoder().decode(GitHubRelease.self, from: data)
}

/// Find the best matching asset for the current platform and architecture.
/// Matches at least one OS keyword AND at least one arch keyword, and excludes unwanted keywords.
func findMatchingAsset(
    in release: GitHubRelease,
    osKeywords: [String] = CurrentPlatform.osAlternates,
    archKeywords: [String] = CurrentPlatform.archAlternates,
    excludeKeywords: [String] = ["sha256", "checksum", ".sig", ".asc", "source", "-src", "-debug", "windows", "-win"]
) -> GitHubAsset? {
    let lowerOs = osKeywords.map { $0.lowercased() }
    let lowerArch = archKeywords.map { $0.lowercased() }
    let lowerExclude = excludeKeywords.map { $0.lowercased() }

    return release.assets.first { asset in
        let name = asset.name.lowercased()
        let matchesOs = lowerOs.isEmpty || lowerOs.contains(where: { name.contains($0) })
        let matchesArch = lowerArch.isEmpty || lowerArch.contains(where: { name.contains($0) })
        let noExcluded = lowerExclude.allSatisfy { !name.contains($0) }
        return matchesOs && matchesArch && noExcluded
    }
}

/// Default install directory: ~/.local/bin
func defaultInstallDirectory() -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")
}

/// Download a remote file to a temp location, returning the local URL.
func downloadFile(from url: URL) async throws -> URL {
    let (downloadedURL, _) = try await URLSession.shared.download(from: url)
    let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent(url.lastPathComponent)
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.moveItem(at: downloadedURL, to: destination)
    return destination
}

/// Extract a .tar.gz, .tgz, .tar.bz2, or .zip archive into a destination directory.
func extractArchive(at archivePath: URL, to destinationDir: URL) throws {
    try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    let name = archivePath.lastPathComponent.lowercased()

    if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz") {
        process.arguments = ["tar", "xzf", archivePath.path, "-C", destinationDir.path]
    } else if name.hasSuffix(".tar.bz2") {
        process.arguments = ["tar", "xjf", archivePath.path, "-C", destinationDir.path]
    } else if name.hasSuffix(".zip") {
        process.arguments = ["unzip", "-o", "-q", archivePath.path, "-d", destinationDir.path]
    } else {
        throw SwiftCardanoMultitoolError.operationError("Unsupported archive format: \(archivePath.lastPathComponent)")
    }

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw SwiftCardanoMultitoolError.operationError(
            "Archive extraction failed (exit \(process.terminationStatus)): \(archivePath.lastPathComponent)"
        )
    }
}

/// Recursively search a directory for a regular file with the given name.
func findBinary(named binaryName: String, in directory: URL) -> URL? {
    guard let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey]
    ) else { return nil }

    for case let url as URL in enumerator {
        guard url.lastPathComponent == binaryName else { continue }
        let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
        if isRegular { return url }
    }
    return nil
}

/// Copy a binary to the install directory and make it executable.
func installBinary(named binaryName: String, from sourceDir: URL, to installDir: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: installDir, withIntermediateDirectories: true)

    guard let source = findBinary(named: binaryName, in: sourceDir) else {
        throw SwiftCardanoMultitoolError.fileNotFound(FilePath(sourceDir.appendingPathComponent(binaryName).path))
    }

    let destination = installDir.appendingPathComponent(binaryName)
    if fm.fileExists(atPath: destination.path) {
        try fm.removeItem(at: destination)
    }
    try fm.copyItem(at: source, to: destination)
    try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
}

/// Process a downloaded asset: extract if it's an archive, otherwise treat it as a direct binary.
func processDownloadedAsset(archivePath: URL, binaryName: String, installDir: URL) throws {
    let fm = FileManager.default
    let name = archivePath.lastPathComponent.lowercased()

    if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz")
        || name.hasSuffix(".tar.bz2") || name.hasSuffix(".zip") {
        let extractDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: extractDir) }
        try extractArchive(at: archivePath, to: extractDir)
        try installBinary(named: binaryName, from: extractDir, to: installDir)
    } else {
        // Treat as a bare binary file
        try fm.createDirectory(at: installDir, withIntermediateDirectories: true)
        let destination = installDir.appendingPathComponent(binaryName)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: archivePath, to: destination)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    }
}

/// Pull a Docker or Apple Container image using the specified CLI command.
///
/// Routes through `Processes.current` so tests can stub the invocation via
/// `RecordedProcessRunner`.
func pullContainerImage(cli: String, image: String) async throws {
    let outcome = try await Processes.current.run(
        URL(fileURLWithPath: "/usr/bin/env"),
        arguments: [cli, "pull", image],
        environment: nil
    )
    guard outcome.exitCode == 0 else {
        throw SwiftCardanoMultitoolError.operationError(
            "\(cli) pull failed (exit \(outcome.exitCode)) for image: \(image)"
        )
    }
}

/// Run a foreground binary process, forwarding SIGINT/SIGTERM for graceful shutdown.
/// Resolves a bare binary name via `which`; absolute paths are used as-is.
func runForegroundProcess(
    binary: String,
    arguments: [String],
    environment: [String: String]? = nil
) async throws {
    // Resolve executable URL
    let execURL: URL
    if binary.hasPrefix("/") {
        execURL = URL(fileURLWithPath: binary)
    } else {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = [binary]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        try which.run()
        which.waitUntilExit()
        guard which.terminationStatus == 0 else {
            throw SwiftCardanoMultitoolError.operationError(
                "'\(binary)' not found in PATH. Install it first with: scm install \(binary)"
            )
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !path.isEmpty else {
            throw SwiftCardanoMultitoolError.operationError("Could not resolve path for '\(binary)'")
        }
        execURL = URL(fileURLWithPath: path)
    }

    let process = Process()
    process.executableURL = execURL
    process.arguments = arguments
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    if let env = environment {
        var merged = ProcessInfo.processInfo.environment
        for (k, v) in env { merged[k] = v }
        process.environment = merged
    }

    signal(SIGINT,  SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    let sigintSource  = DispatchSource.makeSignalSource(signal: SIGINT,  queue: .global())
    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())

    var runError: Error?

    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        process.terminationHandler = { _ in continuation.resume() }

        do {
            try process.run()
            let pid = process.processIdentifier
            sigintSource.setEventHandler  { _ = kill(pid, SIGINT)  }
            sigtermSource.setEventHandler { _ = kill(pid, SIGTERM) }
            sigintSource.resume()
            sigtermSource.resume()
        } catch {
            runError = error
            continuation.resume()
        }
    }

    sigintSource.cancel()
    sigtermSource.cancel()
    signal(SIGINT,  SIG_DFL)
    signal(SIGTERM, SIG_DFL)

    if let error = runError {
        throw SwiftCardanoMultitoolError.operationError(
            "Failed to start '\(binary)': \(error.localizedDescription)"
        )
    }
    guard process.terminationStatus == 0 else {
        throw SwiftCardanoMultitoolError.operationError(
            "'\(binary)' exited with status \(process.terminationStatus)"
        )
    }
}

/// Warn if the install directory is not present in the user's PATH.
func warnIfNotInPath(_ installDir: URL) {
    let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
    let homeExpanded = installDir.path.replacingOccurrences(
        of: FileManager.default.homeDirectoryForCurrentUser.path,
        with: "~"
    )
    if !pathEnv.split(separator: ":").map(String.init).contains(installDir.path) {
        noora.warning(.alert(
            "\(homeExpanded) is not in your PATH.",
            takeaway: "Add this to your shell profile: export PATH=\"\(installDir.path):$PATH\""
        ))
    }
}
