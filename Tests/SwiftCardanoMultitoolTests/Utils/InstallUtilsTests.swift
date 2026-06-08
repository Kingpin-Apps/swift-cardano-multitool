import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("CurrentPlatform")
struct CurrentPlatformTests {

    @Test("os is one of the known values")
    func osIsKnown() {
        let known: Set<String> = ["macos", "linux", "unknown"]
        #expect(known.contains(CurrentPlatform.os))
    }

    @Test("arch is one of the known values")
    func archIsKnown() {
        let known: Set<String> = ["arm64", "x86_64", "unknown"]
        #expect(known.contains(CurrentPlatform.arch))
    }

    @Test("os alternates include the canonical os string")
    func osAlternatesIncludeOs() {
        if CurrentPlatform.os != "unknown" {
            #expect(CurrentPlatform.osAlternates.contains(CurrentPlatform.os))
        }
    }

    @Test("arch alternates include the canonical arch string")
    func archAlternatesIncludeArch() {
        if CurrentPlatform.arch != "unknown" {
            #expect(CurrentPlatform.archAlternates.contains(CurrentPlatform.arch))
        }
    }
}

@Suite("defaultInstallDirectory")
struct DefaultInstallDirectoryTests {

    @Test("ends in .local/bin under the user's home directory")
    func endsInLocalBin() {
        let dir = defaultInstallDirectory()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(dir.path.hasPrefix(home))
        #expect(dir.path.hasSuffix(".local/bin"))
    }
}

@Suite("InstallMethod.available")
struct InstallMethodAvailableTests {

    @Test("binary and docker are always available")
    func binaryAndDockerAvailable() {
        #expect(InstallMethod.available.contains(.binary))
        #expect(InstallMethod.available.contains(.docker))
    }

    @Test("apple-container is included on macOS only")
    func appleContainerOnMacOnly() {
        #if os(macOS)
        #expect(InstallMethod.available.contains(.appleContainer))
        #else
        #expect(!InstallMethod.available.contains(.appleContainer))
        #endif
    }
}

@Suite("findMatchingAsset")
struct FindMatchingAssetTests {

    private func release(_ assets: [GitHubAsset]) -> GitHubRelease {
        GitHubRelease(tagName: "v1.0.0", assets: assets)
    }

    private func asset(_ name: String) -> GitHubAsset {
        GitHubAsset(name: name, browserDownloadUrl: "https://example.com/\(name)")
    }

    @Test("matches when an asset name contains both an OS and an arch keyword")
    func matchesOsAndArch() {
        let r = release([
            asset("scm-1.0.0-linux-x86_64.tar.gz"),
            asset("scm-1.0.0-macos-arm64.tar.gz")
        ])
        let match = findMatchingAsset(
            in: r,
            osKeywords: ["macos"],
            archKeywords: ["arm64"]
        )
        #expect(match?.name == "scm-1.0.0-macos-arm64.tar.gz")
    }

    @Test("keyword matching is case insensitive")
    func caseInsensitiveMatch() {
        let r = release([asset("SCM-1.0.0-MacOS-Arm64.TAR.GZ")])
        let match = findMatchingAsset(
            in: r,
            osKeywords: ["macos"],
            archKeywords: ["arm64"]
        )
        #expect(match != nil)
    }

    @Test("returns nil when no asset matches the OS")
    func noOsMatchReturnsNil() {
        let r = release([asset("scm-1.0.0-linux-x86_64.tar.gz")])
        let match = findMatchingAsset(
            in: r,
            osKeywords: ["macos"],
            archKeywords: ["x86_64"]
        )
        #expect(match == nil)
    }

    @Test("excludes assets matching the default excludeKeywords")
    func excludesDefaultBadKeywords() {
        let r = release([
            asset("scm-1.0.0-macos-arm64.tar.gz.sha256"),
            asset("scm-1.0.0-macos-arm64.sig"),
            asset("scm-1.0.0-windows-x86_64.zip"),
            asset("scm-1.0.0-macos-arm64.tar.gz")
        ])
        let match = findMatchingAsset(
            in: r,
            osKeywords: ["macos"],
            archKeywords: ["arm64"]
        )
        #expect(match?.name == "scm-1.0.0-macos-arm64.tar.gz")
    }

    @Test("honours custom excludeKeywords")
    func customExcludeKeywords() {
        let r = release([
            asset("scm-1.0.0-macos-arm64-musl.tar.gz"),
            asset("scm-1.0.0-macos-arm64.tar.gz")
        ])
        let match = findMatchingAsset(
            in: r,
            osKeywords: ["macos"],
            archKeywords: ["arm64"],
            excludeKeywords: ["musl"]
        )
        #expect(match?.name == "scm-1.0.0-macos-arm64.tar.gz")
    }

    @Test("with an empty osKeywords list, matches purely on arch")
    func emptyOsKeywordsMatchesAnyOs() {
        let r = release([asset("only-arm64-no-os-info.tar.gz")])
        let match = findMatchingAsset(
            in: r,
            osKeywords: [],
            archKeywords: ["arm64"]
        )
        #expect(match != nil)
    }
}

// MARK: - findBinary

@Suite("InstallUtils.findBinary")
struct InstallUtilsFindBinaryTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-findbinary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("finds a binary directly under the given directory")
    func findsAtRoot() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let binary = dir.appendingPathComponent("kupo")
        try Data().write(to: binary)

        let found = findBinary(named: "kupo", in: dir)
        #expect(found?.lastPathComponent == "kupo")
    }

    @Test("finds a binary nested in a subdirectory")
    func findsNested() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let subdir = dir.appendingPathComponent("nested/release")
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        let binary = subdir.appendingPathComponent("ogmios")
        try Data().write(to: binary)

        let found = findBinary(named: "ogmios", in: dir)
        #expect(found?.lastPathComponent == "ogmios")
    }

    @Test("returns nil when no matching binary is present")
    func returnsNilWhenAbsent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let found = findBinary(named: "missing-binary", in: dir)
        #expect(found == nil)
    }
}

// MARK: - installBinary

@Suite("InstallUtils.installBinary")
struct InstallUtilsInstallBinaryTests {

    private func makeTempDir(_ prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("copies the binary into the install dir and sets 755 permissions")
    func copiesAndChmod() throws {
        let sourceDir = try makeTempDir("instbin-src")
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let installDir = try makeTempDir("instbin-dst")
        defer { try? FileManager.default.removeItem(at: installDir) }

        let source = sourceDir.appendingPathComponent("mybinary")
        try Data("hello".utf8).write(to: source)

        try installBinary(named: "mybinary", from: sourceDir, to: installDir)

        let dst = installDir.appendingPathComponent("mybinary")
        #expect(FileManager.default.fileExists(atPath: dst.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: dst.path)
        #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o755)
    }

    @Test("overwrites an existing file at the destination")
    func overwritesExistingFile() throws {
        let sourceDir = try makeTempDir("instbin-ovw-src")
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let installDir = try makeTempDir("instbin-ovw-dst")
        defer { try? FileManager.default.removeItem(at: installDir) }

        let source = sourceDir.appendingPathComponent("bin1")
        try Data("new-content".utf8).write(to: source)
        let dst = installDir.appendingPathComponent("bin1")
        try Data("old".utf8).write(to: dst)

        try installBinary(named: "bin1", from: sourceDir, to: installDir)
        let content = try String(contentsOf: dst, encoding: .utf8)
        #expect(content == "new-content")
    }

    @Test("creates the install directory if it does not exist")
    func createsInstallDir() throws {
        let sourceDir = try makeTempDir("instbin-mkdir-src")
        defer { try? FileManager.default.removeItem(at: sourceDir) }

        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-mkdir-\(UUID().uuidString)")
        let installDir = parent.appendingPathComponent("nested/install")
        defer { try? FileManager.default.removeItem(at: parent) }

        try Data().write(to: sourceDir.appendingPathComponent("mybin"))
        try installBinary(named: "mybin", from: sourceDir, to: installDir)

        #expect(FileManager.default.fileExists(atPath: installDir.appendingPathComponent("mybin").path))
    }

    @Test("throws when the binary is missing from the source dir")
    func throwsWhenSourceMissing() throws {
        let sourceDir = try makeTempDir("instbin-miss-src")
        defer { try? FileManager.default.removeItem(at: sourceDir) }
        let installDir = try makeTempDir("instbin-miss-dst")
        defer { try? FileManager.default.removeItem(at: installDir) }

        #expect(throws: (any Error).self) {
            try installBinary(named: "doesnotexist", from: sourceDir, to: installDir)
        }
    }
}

// MARK: - processDownloadedAsset (direct-binary branch)

@Suite("InstallUtils.processDownloadedAsset")
struct InstallUtilsProcessDownloadedAssetTests {

    private func makeTempDir(_ prefix: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(prefix)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("a non-archive file is copied straight to installDir with 755 perms")
    func copiesBareBinary() throws {
        let workDir = try makeTempDir("pda-work")
        defer { try? FileManager.default.removeItem(at: workDir) }
        let installDir = try makeTempDir("pda-install")
        defer { try? FileManager.default.removeItem(at: installDir) }

        let downloaded = workDir.appendingPathComponent("kupo-linux-x86_64")
        try Data("binary-content".utf8).write(to: downloaded)

        try processDownloadedAsset(
            archivePath: downloaded, binaryName: "kupo", installDir: installDir
        )

        let installed = installDir.appendingPathComponent("kupo")
        #expect(FileManager.default.fileExists(atPath: installed.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: installed.path)
        #expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o755)
    }
}

// MARK: - extractArchive (sad path)

@Suite("InstallUtils.extractArchive")
struct InstallUtilsExtractArchiveTests {

    @Test("throws for an unsupported archive format")
    func unsupportedFormatThrows() throws {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let weird = workDir.appendingPathComponent("notanarchive.xyz")
        try Data().write(to: weird)
        let dest = workDir.appendingPathComponent("out")

        #expect(throws: (any Error).self) {
            try extractArchive(at: weird, to: dest)
        }
    }
}

// MARK: - pullContainerImage (via RecordedProcessRunner)

@Suite("InstallUtils.pullContainerImage")
struct InstallUtilsPullContainerImageTests {

    @Test("invokes the requested cli + image and succeeds on exit code 0")
    func successfulPull() async throws {
        let runner = RecordedProcessRunner(outcomes: [ProcessOutcome(exitCode: 0)])
        try await Processes.$current.withValue(runner) {
            try await pullContainerImage(cli: "docker", image: "ghcr.io/test/image:latest")
        }

        #expect(runner.invocations.count == 1)
        let call = runner.invocations.first!
        #expect(call.executable.path == "/usr/bin/env")
        #expect(call.arguments == ["docker", "pull", "ghcr.io/test/image:latest"])
    }

    @Test("propagates a non-zero exit code as an operation error")
    func nonZeroExitThrows() async throws {
        let runner = RecordedProcessRunner(outcomes: [ProcessOutcome(exitCode: 7)])
        await #expect(throws: (any Error).self) {
            try await Processes.$current.withValue(runner) {
                try await pullContainerImage(cli: "apple-container", image: "ghcr.io/test/x")
            }
        }
        #expect(runner.invocations.count == 1)
    }
}

// MARK: - GitHubRelease / GitHubAsset JSON decoding

@Suite("InstallUtils GitHub release decoding")
struct InstallUtilsGitHubReleaseDecodingTests {

    @Test("decodes a release with one asset using snake_case JSON keys")
    func decodesRelease() throws {
        let json = """
        {
            "tag_name": "v1.2.3",
            "assets": [
                {
                    "name": "kupo-linux-x86_64.tar.gz",
                    "browser_download_url": "https://example.com/kupo.tar.gz"
                }
            ]
        }
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.tagName == "v1.2.3")
        #expect(release.assets.count == 1)
        #expect(release.assets.first?.name == "kupo-linux-x86_64.tar.gz")
        #expect(release.assets.first?.browserDownloadUrl == "https://example.com/kupo.tar.gz")
    }

    @Test("decodes a release with no assets as an empty array")
    func decodesEmptyAssets() throws {
        let json = """
        {"tag_name": "v0.0.1", "assets": []}
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        #expect(release.assets.isEmpty)
    }
}
