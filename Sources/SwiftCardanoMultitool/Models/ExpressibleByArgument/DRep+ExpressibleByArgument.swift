import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage


extension DRep: @retroactive _SendableMetatype {}
extension DRep: @retroactive ExpressibleByArgument {
    /// Byte length of a credential hash (blake2b-224).
    static let credentialHashSize = 28

    public init?(argument: String) {
        guard let resolved = Self.resolve(
            argument.trimmingCharacters(in: .whitespacesAndNewlines)
        ) else {
            return nil
        }
        self = resolved
    }

    /// Resolve any of the ways a DRep can be named on the command line.
    ///
    /// Each step falls through to the next rather than failing outright, so a
    /// string that merely *looks* like one form — a file whose name happens to
    /// start with "drep", say — still gets tried as the others.
    private static func resolve(_ trimmed: String) -> DRep? {
        // Predefined DReps (CIP-1694): vote-delegation to the always-abstain or
        // always-no-confidence options requires no on-chain DRep credential.
        switch trimmed.lowercased() {
            case "always-abstain", "alwaysabstain", "abstain",
                 "drep_always_abstain":
                return DRep(credential: .alwaysAbstain)
            case "always-no-confidence", "alwaysnoconfidence",
                 "no-confidence", "noconfidence", "drep_always_no_confidence":
                return DRep(credential: .alwaysNoConfidence)
            default:
                break
        }

        // Bech32. Covers CIP-105 (drep1…, drep_script1…, drep_vkh1…) and CIP-129
        // (drep1… carrying a header byte); SwiftCardanoCore tells them apart by
        // payload length and rejects a header naming a non-DRep key type.
        if trimmed.lowercased().hasPrefix("drep"),
           let drep = try? DRep(from: trimmed) {
            return drep
        }

        // Hex, with an optional 0x prefix.
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

            // CIP-129 prefixes the hash with a header byte naming the key type
            // (drep) and whether the credential is a key or a script hash.
            if data.count == credentialHashSize + 1, let drep = fromCIP129(data) {
                return drep
            }

            // A bare hash carries no such marker, so it is read as a key hash —
            // the same assumption cardano-cli makes for `--drep-key-hash`.
            if data.count == credentialHashSize,
               let drep = try? DRep(from: data, as: .keyHash) {
                return drep
            }
        }

        // Otherwise a file path, or a base name to look up in the current directory.
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        func path(_ name: String) -> String {
            name.hasPrefix("/") ? name : (currentDir as NSString).appendingPathComponent(name)
        }

        if fileManager.fileExists(atPath: path(trimmed)) {
            return fromFile(path(trimmed))
        }

        // Ordered cheapest first: the ID files hold the identifier outright, the
        // key files have to be hashed. Every candidate that exists is tried, so a
        // directory holding both an ID file and a key file still resolves.
        let variations = [
            "\(trimmed).drep.id",
            "\(trimmed).drep",
            "\(trimmed).drep.vkey",
            "\(trimmed).drep.extended.vkey",
            "\(trimmed).drep.skey",
        ]
        for fileName in variations where fileManager.fileExists(atPath: path(fileName)) {
            if let loaded = fromFile(path(fileName)) {
                return loaded
            }
        }

        return nil
    }

    /// Decode a CIP-129 identifier: one header byte, then the 28-byte hash.
    ///
    /// Returns nil when the header names a key type other than `drep`, so a
    /// committee credential is rejected rather than silently read as a DRep.
    private static func fromCIP129(_ data: Data) -> DRep? {
        let header = Int(data[data.startIndex])
        guard header >> 4 == GovernanceKeyType.drep.rawValue,
              let credentialType = GovernanceCredentialType(rawValue: header & 0x0f) else {
            return nil
        }
        return try? DRep(from: Data(data.dropFirst()), as: credentialType)
    }

    /// Load a DRep from a key file or an ID file.
    ///
    /// `DRep.load` only understands a file holding a bare bech32/hex ID, so a key
    /// envelope has to be hashed here instead. Key files are dispatched on their
    /// envelope type: key loading doesn't check the type, so reading a signing key
    /// as a verification key would silently yield the wrong hash.
    private static func fromFile(_ filePath: String) -> DRep? {
        if let vkey = try? DRepVerificationKey.load(from: filePath) {
            if vkey._type.contains("SigningKey") {
                guard let skey = try? DRepSigningKey.load(from: filePath),
                      let derived: DRepVerificationKey = try? skey.toVerificationKey(),
                      let hash = try? derived.hash() else {
                    return nil
                }
                return DRep(credential: .verificationKeyHash(hash))
            }
            if vkey._type.contains("VerificationKey") {
                guard let hash = try? vkey.hash() else { return nil }
                return DRep(credential: .verificationKeyHash(hash))
            }
        }

        return try? DRep.load(from: filePath)
    }
}
