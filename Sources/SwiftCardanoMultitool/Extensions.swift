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

public struct PaymentAddressInfo: ExpressibleByArgument {
    let info: AddressInfo
    // MARK: ExpressibleByArgument
    
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
        else if trimmed.hasPrefix("addr") {
            // Case 2: Bech32 address (starts with addr or stake)
            guard let info = try? AddressInfo(fromAddressString: trimmed) else {
                return nil
            }
            self.init(info: info)
        } else {
            // Case 3: File path or name (e.g., owner.payment, owner, or /full/path/to/file.addr)
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
                "\(addressFileName).payment.addr",
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
            guard let info = try? AddressInfo(fromAdaHandle: trimmed) else {
                return nil
            }
            self = info
        }
        else if trimmed.hasPrefix("addr") || trimmed.hasPrefix("stake") {
            // Case 2: Bech32 address (starts with addr or stake)
            guard let info = try? AddressInfo(fromAddressString: trimmed) else {
                return nil
            }
            self = info
        } else {
            // Case 3: File path or name (e.g., owner.payment, owner, or /full/path/to/file.addr)
            let addressFileName = trimmed
            let fileManager = FileManager.default
            
            // Try direct file first (handles both absolute and relative paths)
            if fileManager.fileExists(atPath: addressFileName) {
                guard let info = try? AddressInfo(fromFile: FilePath(addressFileName)) else {
                    return nil
                }
                self = info
                return
            }
            
            // If not found as-is, try relative to current directory
            let currentDir = fileManager.currentDirectoryPath
            let filePath = currentDir.appending(addressFileName)
            
            if fileManager.fileExists(atPath: filePath) {
                guard let info = try? AddressInfo(fromFile: FilePath(filePath)) else {
                    return nil
                }
                self = info
                return
            }
            
            // Try common file name variations
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
                guard let info = try? AddressInfo(fromFile: FilePath(filePath)) else {
                    return nil
                }
                self = info
            } else {
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
    
    public func getSigningMethod() throws -> SigningMethod {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        
        // remove .payment.addr, .stake, or .addr suffixes if present
        let cleanedName: String
        if let name = self.name {
            if name.hasSuffix(".payment") {
                cleanedName = String(name.dropLast(".payment".count))
            } else if name.hasSuffix(".addr") {
                cleanedName = String(name.dropLast(".addr".count))
            } else if name.hasSuffix(".stake") {
                cleanedName = String(name.dropLast(".stake".count))
            } else {
                cleanedName = name
            }
        } else {
            noora.error(.alert(
                "Address name is missing; cannot determine signing key file.",
                takeaways: [
                    "Ensure the address was loaded from a file with a valid name."
                ]
            ))
            throw ExitCode.validationFailure
        }
        
        let fm = FileManager.default
        
        // Build ordered candidates based on address type
        let contextLabel: String
        let candidates: [(FilePath, (FilePath) -> SigningMethod)]
        switch self.type {
        case .payment?:
            contextLabel = "payment"
            candidates = [
                (cwd.appending("\(cleanedName).payment.hwsfile"), SigningMethod.hardwareWallet),
                (cwd.appending("\(cleanedName).payment.skey"), SigningMethod.softwareKey),
                (cwd.appending("\(cleanedName).hwsfile"), SigningMethod.hardwareWallet),
                (cwd.appending("\(cleanedName).skey"), SigningMethod.softwareKey)
            ]
        case .stake?:
            contextLabel = "stake"
            candidates = [
                (cwd.appending("\(cleanedName).stake.hwsfile"), SigningMethod.hardwareWallet),
                (cwd.appending("\(cleanedName).stake.skey"), SigningMethod.softwareKey),
                (cwd.appending("\(cleanedName).hwsfile"), SigningMethod.hardwareWallet),
                (cwd.appending("\(cleanedName).skey"), SigningMethod.softwareKey)
            ]
        default:
            contextLabel = "address"
            candidates = [
                (cwd.appending("\(cleanedName).hwsfile"), SigningMethod.hardwareWallet),
                (cwd.appending("\(cleanedName).skey"), SigningMethod.softwareKey)
            ]
        }
        
        // Resolve first existing candidate
        for (file, wrap) in candidates {
            if fm.fileExists(atPath: file.string) {
                return wrap(file)
            }
        }
        
        // Nothing found — report what we looked for
        let expectedList = candidates.map { $0.0.string }.joined(separator: ", ")
        noora.error(.alert(
            "No signing key found for \(contextLabel) address '\(cleanedName)'",
            takeaways: [
                "Searched (in order): \(expectedList)"
            ]
        ))
        throw ExitCode.validationFailure
    }
    
    public func getVerificationKey() throws -> FilePath {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        
        // remove .payment.addr, .stake, or .addr suffixes if present
        let cleanedName: String
        if let name = self.name {
            if name.hasSuffix(".payment") {
                cleanedName = String(name.dropLast(".payment".count))
            } else if name.hasSuffix(".addr") {
                cleanedName = String(name.dropLast(".addr".count))
            } else if name.hasSuffix(".stake") {
                cleanedName = String(name.dropLast(".stake".count))
            } else {
                cleanedName = name
            }
        } else {
            noora.error(.alert(
                "Address name is missing; cannot determine verification key file.",
                takeaways: [
                    "Ensure the address was loaded from a file with a valid name."
                ]
            ))
            throw ExitCode.validationFailure
        }
        
        let fm = FileManager.default
        
        // Build ordered candidates based on address type
        let contextLabel: String
        let candidates: [FilePath]
        switch self.type {
        case .payment?:
            contextLabel = "payment"
            candidates = [
                cwd.appending("\(cleanedName).payment.vkey"),
                cwd.appending("\(cleanedName).vkey")
            ]
        case .stake?:
            contextLabel = "stake"
            candidates = [
                cwd.appending("\(cleanedName).stake.vkey"),
                cwd.appending("\(cleanedName).vkey")
            ]
        default:
            contextLabel = "address"
            candidates = [
                cwd.appending("\(cleanedName).vkey")
            ]
        }
        
        // Resolve first existing candidate
        for file in candidates {
            if fm.fileExists(atPath: file.string) {
                return file
            }
        }
        
        // Nothing found — report what we looked for
        let expectedList = candidates.map { $0.string }.joined(separator: ", ")
        noora.error(.alert(
            "No verification key found for \(contextLabel) address '\(cleanedName)'",
            takeaways: [
                "Searched (in order): \(expectedList)"
            ]
        ))
        throw ExitCode.validationFailure
    }
}

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

extension MultiAsset: @retroactive _SendableMetatype {
    public func toAssetsOutString() -> String {
        var assetsOutString = ""
        
        for (scriptHash, assetsUnderPolicy) in self.data {
            // Convert policyId (scriptHash) to hex
            let policyIdHex = scriptHash.payload.hexEncodedString()
            
            // For each asset under that policy
            for (assetName, amount) in assetsUnderPolicy.data {
                // Convert asset name (bytes) to hex
                let assetNameHex = assetName.payload.hexEncodedString()
                
                // The asset identifier (policyId + "." + assetNameHex) or "+" if you prefer
                let assetHashName = "\(policyIdHex).\(assetNameHex)"
                
                // Append in the format: +<amount> <policyId.assetNameHex>
                assetsOutString += "+\(amount) \(assetHashName)"
            }
        }
        
        return assetsOutString
    }
}
