import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage

/// Either a cold or hot committee credential, or a bare hex hash that could be either.
///
/// `query committee-member` accepts both cold and hot identifiers (mirroring
/// `gitmachtl/scripts/23d_checkComOnChain.sh`). The bech32 prefix tells us which is which
/// deterministically. A bare 28-byte hex string is ambiguous — the subcommand tries cold
/// first, then falls back to hot.
public enum CommitteeMemberCredential: Sendable {
    case cold(CommitteeColdCredential)
    case hot(CommitteeHotCredential)
    /// 28-byte hash with no surrounding bech32/file context — caller should attempt cold
    /// lookup first, then hot.
    case ambiguousHash(Data)
}

extension CommitteeMemberCredential: ExpressibleByArgument {
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)

        // Bech32 prefix routes deterministically.
        if trimmed.hasPrefix("cc_cold") {
            if let cold = CommitteeColdCredential(argument: trimmed) {
                self = .cold(cold)
                return
            }
            return nil
        }
        if trimmed.hasPrefix("cc_hot") {
            if let hot = CommitteeHotCredential(argument: trimmed) {
                self = .hot(hot)
                return
            }
            return nil
        }

        // File-suffix routing — check before treating the string as raw hex.
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        let coldFileSuffixes = [".cc-cold.vkey", ".cc-cold.id", ".cc-cold.hash"]
        let hotFileSuffixes = [".cc-hot.vkey", ".cc-hot.id", ".cc-hot.hash"]

        for suffix in coldFileSuffixes where trimmed.hasSuffix(suffix) || fileManager.fileExists(atPath: currentDir.appending(trimmed + suffix)) {
            if let cold = CommitteeColdCredential(argument: trimmed) {
                self = .cold(cold)
                return
            }
        }
        for suffix in hotFileSuffixes where trimmed.hasSuffix(suffix) || fileManager.fileExists(atPath: currentDir.appending(trimmed + suffix)) {
            if let hot = CommitteeHotCredential(argument: trimmed) {
                self = .hot(hot)
                return
            }
        }

        // Hex (with optional 0x prefix) → ambiguous; the subcommand will try cold then hot.
        let hexCandidate: String
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            hexCandidate = String(trimmed.dropFirst(2))
        } else {
            hexCandidate = trimmed
        }

        let hexSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        let isValidHex = !hexCandidate.isEmpty
            && hexCandidate.count % 2 == 0
            && hexCandidate.unicodeScalars.allSatisfy { hexSet.contains($0) }

        if isValidHex {
            let data = hexCandidate.hexStringToData
            if !data.isEmpty {
                self = .ambiguousHash(data)
                return
            }
        }

        return nil
    }
}
