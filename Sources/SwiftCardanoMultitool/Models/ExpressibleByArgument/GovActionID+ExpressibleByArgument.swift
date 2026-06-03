import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage


extension GovActionID: @retroactive _SendableMetatype {}
extension GovActionID: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)

        // Bech32 form: gov_action1…
        if trimmed.hasPrefix("gov_action") {
            try? self.init(from: trimmed)
            return
        }

        // cardano-cli natural form: <64-hex-txhash>#<index>
        if let hashIndex = trimmed.firstIndex(of: "#") {
            let hashPart = String(trimmed[..<hashIndex])
            let indexPart = String(trimmed[trimmed.index(after: hashIndex)...])
            if let index = UInt16(indexPart), hashPart.count == 64 {
                let hashSet = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
                if hashPart.unicodeScalars.allSatisfy({ hashSet.contains($0) }) {
                    let txData = hashPart.hexStringToData
                    if !txData.isEmpty {
                        self.init(
                            transactionID: TransactionId(payload: txData),
                            govActionIndex: index
                        )
                        return
                    }
                }
            }
        }

        // Hex form (with optional 0x prefix) — txid + 1-2 byte index, parsed by init(from hex:).
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
                try? self.init(from: data)
                return
            }
        }

        // File lookup — read the file as either bech32 or hex and parse accordingly.
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath

        let variations = [
            trimmed,
            "\(trimmed).govaction.id",
            "\(trimmed).govaction",
            "\(trimmed).action.id",
        ]

        for fileName in variations {
            let filePath = currentDir.appending(fileName)
            if fileManager.fileExists(atPath: filePath) {
                if let raw = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if value.hasPrefix("gov_action"),
                       let parsed = try? GovActionID(from: value) {
                        self = parsed
                        return
                    }
                    if let parsed = try? GovActionID(from: value.hexStringToData),
                       !value.hexStringToData.isEmpty {
                        self = parsed
                        return
                    }
                }
            }
        }

        return nil
    }
}
