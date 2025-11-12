import Foundation
import ArgumentParser
import SwiftCardanoCore
import SystemPackage


extension DRep: @retroactive _SendableMetatype {}
extension DRep: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try Bech32 first
        if trimmed.hasPrefix("drep") {
            try? self.init(from: trimmed)
            return
        }
        
        // Try hex string format (supports optional 0x prefix)
        do {
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
        }
        
        // Otherwise treat as file name
        let drepFileName = trimmed
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let filePath = currentDir.appending(drepFileName)
        
        if fileManager.fileExists(atPath: filePath) {
            if let loaded = try? DRep.load(from: filePath) {
                self = loaded
                return
            }
        }
        
        let variations = [
            "\(drepFileName).drep.vkey",
            "\(drepFileName).drep.id",
            "\(drepFileName).drep"
        ]
        
        var foundFiles: [String] = []
        for fileName in variations {
            let filePath = currentDir.appending(fileName)
            if fileManager.fileExists(atPath: filePath) {
                foundFiles.append(fileName)
            }
        }
        
        // Handle results
        if !foundFiles.isEmpty, foundFiles.count == 1, let firstFile = foundFiles.first {
            let filePath = currentDir.appending(firstFile)
            if let loaded = try? DRep.load(from: filePath) {
                self = loaded
                return
            }
        }
        
        return nil
    }
}
