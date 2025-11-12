import Foundation
import ArgumentParser
import SwiftCardanoChain
import SystemPackage

/// A struct that represents stake address information and conforms to `ExpressibleByArgument`.
/// It can be initialized from various input formats including AdaHandle, Bech32 address, or file paths.
public struct StakeAddressInfo: ExpressibleByArgument {
    var info: AddressInfo
    
    public init (info: AddressInfo) {
        self.info = info
    }
    
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("$") {
            // Case 1: $adahandle
            guard let info = try? AddressInfo(fromAdaHandle: trimmed) else {
                return nil
            }
            self.init(info: info)
        }
        else if trimmed.hasPrefix("stake") {
            // Case 2: Bech32 address (starts with addr or stake)
            guard let info = try? AddressInfo(fromAddressString: trimmed) else {
                return nil
            }
            self.init(info: info)
        } else {
            // Case 3: File path or name (e.g., owner.stake, owner, or /full/path/to/file.addr)
            let addressFileName = trimmed
            let fileManager = FileManager.default
            
            // Try direct file first (handles both absolute and relative paths)
            if fileManager.fileExists(atPath: addressFileName) {
                guard let info = try? AddressInfo(fromFile: FilePath(addressFileName)) else {
                    return nil
                }
                self.init(info: info)
                return
            }
            
            // If not found as-is, try relative to current directory
            let currentDir = fileManager.currentDirectoryPath
            let filePath = currentDir.appending(addressFileName)
            
            if fileManager.fileExists(atPath: filePath) {
                guard let info = try? AddressInfo(fromFile: FilePath(filePath)) else {
                    return nil
                }
                self.init(info: info)
                return
            }
            
            // Try common file name variations
            let variations = [
                "\(addressFileName).stake.addr",
                "\(addressFileName).addr"
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
                guard let info = try? AddressInfo(fromFile: FilePath(filePath)) else {
                    return nil
                }
                self.init(info: info)
            } else {
                return nil
            }
        }
    }
    
}
