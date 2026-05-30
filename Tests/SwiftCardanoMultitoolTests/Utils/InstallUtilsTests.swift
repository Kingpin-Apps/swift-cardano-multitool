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
