import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage


extension CommitteeHotCredential: @retroactive _SendableMetatype {}
extension CommitteeHotCredential: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try Bech32 first (cc_hot...)
        if trimmed.hasPrefix("cc_hot") {
            try? self.init(from: trimmed)
            return
        }

        // Try hex string format (supports optional 0x prefix)
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
                try? self.init(from: data, as: .keyHash)
                return
            }
        }

        // Otherwise treat as file name
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        let variations = [
            trimmed,
            "\(trimmed).cc-hot.vkey",
            "\(trimmed).cc-hot.id"
        ]

        for fileName in variations {
            let filePath = currentDir.appending(fileName)
            if fileManager.fileExists(atPath: filePath) {
                if let vkey = try? CommitteeHotVerificationKey.load(from: filePath) {
                    if let hash = try? vkey.hash() {
                        self.init(credential: .verificationKeyHash(hash))
                        return
                    }
                }
            }
        }

        return nil
    }
}
