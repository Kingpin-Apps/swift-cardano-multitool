import Foundation
import SystemPackage
import ArgumentParser
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils
import Configuration
import Noora
import SwiftMnemonic

extension URL: @retroactive _SendableMetatype {}
extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(string: argument)!
    }
}

extension FilePath: @retroactive _SendableMetatype {}
extension FilePath: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}

extension Language: @retroactive _SendableMetatype {}
extension Language: @retroactive ExpressibleByArgument, @retroactive CustomStringConvertible {
    public var description: String {
        self.rawValue
    }

    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

extension WordCount: @retroactive _SendableMetatype {}
extension WordCount: @retroactive ExpressibleByArgument, @retroactive CustomStringConvertible {
    public var description: String {
        String(self.rawValue)
    }

    public init?(argument: String) {
        self.init(rawValue: Int(argument) ?? 24)
    }
}

extension Dictionary: @retroactive ExpressibleByConfigString where Key == String, Value == FilePath {
    public init?(configString: String) {
        var result: [String: FilePath] = [:]
        // Allow empty string to mean an empty dictionary
        let trimmed = configString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self = [:]
            return
        }
        // Split on commas to get pairs
        let pairs = trimmed.split(separator: ",")
        for rawPair in pairs {
            let pair = rawPair.trimmingCharacters(in: .whitespacesAndNewlines)
            // Expect key=path
            guard let eqIndex = pair.firstIndex(of: "=") else { return nil }
            let key = String(pair[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStr = String(pair[pair.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return nil }
            let path = FilePath(valueStr)
            result[key] = path
        }
        self = result
    }
    
}

extension Network: @retroactive _SendableMetatype {}
extension Network: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        switch argument.lowercased() {
            case "mainnet":
                self = .mainnet
            case "preview":
                self = .preview
            case "preprod":
                self = .preprod
            case "guildnet":
                self = .guildnet
            case "sanchonet":
                self = .sanchonet
            default:
                return nil
        }
    }
}

extension Noora {
    func secureTextPrompt(
        title: TerminalText? = nil,
        prompt: TerminalText,
        description: TerminalText? = nil
    ) -> String? {
        // Display Noora-styled prompt elements
        if let title = title {
            print(self.format(title))
        }
        print(self.format(prompt))
        if let description = description {
            print(self.format(description))
        }
        
        // Use secure input
        var buf = [CChar](repeating: 0, count: 8192)
        guard let password = readpassphrase("", &buf, buf.count, 0),
              let passwordStr = String(validatingCString: password) else {
            return nil
        }
        
        return passwordStr
    }
}

// MARK: - AddressInfo Struct

/// Address information model for Cardano addresses
/// Supports payment and stake addresses with metadata, UTxOs, and rewards
extension AddressInfo: @retroactive _SendableMetatype {}
extension AddressInfo: @retroactive ExpressibleByArgument {
    
    // MARK: ExpressibleByArgument
    
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.hasPrefix("$") {
            // Case 1: $adahandle
            try? self.init(fromAdaHandle: trimmed)
        }
        else if trimmed.hasPrefix("addr") || trimmed.hasPrefix("stake") {
            // Case 2: Bech32 address (starts with addr or stake)
            try? self.init(fromAddressString: trimmed)
        } else {
            // Case 3: File name (e.g., owner.payment or owner)
            var addressFileName = trimmed
            let fileManager = FileManager.default
            let currentDir = fileManager.currentDirectoryPath
            let filePath = currentDir.appending(addressFileName)
            
            if fileManager.fileExists(atPath: filePath) {
                try? self.init(fromFile: FilePath(filePath))
            }
            
            let variations = [
                "\(addressFileName).payment.addr",
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
                try? self.init(fromFile: FilePath(filePath))
            } else  {
                return nil
            }
        }
    }
    
    /// Address type and era formatted string
    public func addressTypeEra() -> Void {
        guard let type = self.type,
              let era = self.era else {
            print("\nAddress-Type / Era: UNKNOWN")
            return
        }
        
        let typeStr = type.description.capitalized
        let eraStr = era.description.capitalized
        spacedPrint(
            "\nAddress-Type / Era: \(.primary("\(typeStr)")) / \(.primary("\(eraStr)"))"
        )
    }
    
    mutating func updateUTxOs(context: any ChainContext) async throws -> Void {
        
        guard let address = self.address else {
            throw AddressInfoError.invalidAddress("Address is missing; cannot fetch UTxOs.")
        }
        
        self.utxos = try await noora.progressStep(
            message: "Fetching UTXOs for payment address via \(context.name)...",
            successMessage: "Successfully retrieved UTXOs.",
            errorMessage: "Failed to retrieve UTXOs.",
            showSpinner: true
        ) { updateMessage in
            return try await context.utxos(address: address)
        }
    }
    
    mutating func updateStakeAddressInfo(context: any ChainContext) async throws -> Void {
        
        guard let address = self.address else {
            throw AddressInfoError.invalidAddress("Address is missing; cannot fetch stake address info.")
        }
        
        self.stakeAddressInfo = try await noora.progressStep(
            message: "Fetching info for stake address via \(context.name)...",
            successMessage: "Successfully retrieved stake address info.",
            errorMessage: "Failed to retrieve stake address info.",
            showSpinner: true
        ) { updateMessage in
            return try await context.stakeAddressInfo(address: address)
        }
    }
}

