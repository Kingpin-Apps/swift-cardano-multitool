import Foundation
import ArgumentParser
import SwiftCardanoChain
import SystemPackage

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

            // Try the path as given (handles absolute and cwd-relative paths)
            if fileManager.fileExists(atPath: addressFileName) {
                guard let info = try? AddressInfo(fromFile: FilePath(addressFileName)) else {
                    return nil
                }
                self = info
                return
            }

            // Try common file name variations in the current directory
            let variations = [
                "\(addressFileName).payment.addr",
                "\(addressFileName).stake.addr",
                "\(addressFileName).addr"
            ]

            guard let firstFile = variations.first(where: { fileManager.fileExists(atPath: $0) }),
                  let info = try? AddressInfo(fromFile: FilePath(firstFile))
            else {
                return nil
            }
            self = info
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
    
    /// Directory that holds this address's key files: the folder the address file was loaded
    /// from, or the current working directory when the address did not come from a file.
    private var keyDirectory: FilePath {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        guard let addressFile = self.addressFile else { return cwd }
        let dir = addressFile.removingLastComponent()
        return dir.string.isEmpty ? cwd : FileUtils.absolutePath(dir).lexicallyNormalized()
    }

    /// The address name without a `.payment` / `.stake` / `.addr` suffix, used as the key file stem.
    private func keyStem(purpose: String) throws -> String {
        guard let name = self.name else {
            noora.error(.alert(
                "Address name is missing; cannot determine \(purpose) file.",
                takeaways: [
                    "Ensure the address was loaded from a file with a valid name."
                ]
            ))
            throw ExitCode.validationFailure
        }
        // remove .payment.addr, .stake, or .addr suffixes if present
        if name.hasSuffix(".payment") {
            return String(name.dropLast(".payment".count))
        } else if name.hasSuffix(".addr") {
            return String(name.dropLast(".addr".count))
        } else if name.hasSuffix(".stake") {
            return String(name.dropLast(".stake".count))
        }
        return name
    }

    private var keyContextLabel: String {
        switch self.type {
            case .payment?: return "payment"
            case .stake?: return "stake"
            default: return "address"
        }
    }

    /// Signing file candidates next to the address file, in lookup priority order.
    private func signingMethodCandidates() throws -> [(FilePath, (FilePath) -> SigningMethod)] {
        let dir = keyDirectory
        let stem = try keyStem(purpose: "signing key")
        switch self.type {
            case .payment?:
                return [
                    (dir.appending("\(stem).payment.hwsfile"), SigningMethod.hardwareWallet),
                    (dir.appending("\(stem).payment.skey"), SigningMethod.softwareKey),
                    (dir.appending("\(stem).hwsfile"), SigningMethod.hardwareWallet),
                    (dir.appending("\(stem).skey"), SigningMethod.softwareKey)
                ]
            case .stake?:
                return [
                    (dir.appending("\(stem).stake.hwsfile"), SigningMethod.hardwareWallet),
                    (dir.appending("\(stem).stake.skey"), SigningMethod.softwareKey),
                    (dir.appending("\(stem).hwsfile"), SigningMethod.hardwareWallet),
                    (dir.appending("\(stem).skey"), SigningMethod.softwareKey)
                ]
            default:
                return [
                    (dir.appending("\(stem).hwsfile"), SigningMethod.hardwareWallet),
                    (dir.appending("\(stem).skey"), SigningMethod.softwareKey)
                ]
        }
    }

    /// Verification key candidates next to the address file, in lookup priority order.
    private func verificationKeyCandidates() throws -> [FilePath] {
        let dir = keyDirectory
        let stem = try keyStem(purpose: "verification key")
        switch self.type {
            case .payment?:
                return [dir.appending("\(stem).payment.vkey"), dir.appending("\(stem).vkey")]
            case .stake?:
                return [dir.appending("\(stem).stake.vkey"), dir.appending("\(stem).vkey")]
            default:
                return [dir.appending("\(stem).vkey")]
        }
    }

    /// The signing method for this address, or nil when no signing file exists next to it.
    public func findSigningMethod() -> SigningMethod? {
        guard let candidates = try? signingMethodCandidates() else { return nil }
        let fm = FileManager.default
        return candidates.first { fm.fileExists(atPath: $0.0.string) }.map { $0.1($0.0) }
    }

    /// The verification key file for this address, or nil when none exists next to it.
    public func findVerificationKey() -> FilePath? {
        guard let candidates = try? verificationKeyCandidates() else { return nil }
        let fm = FileManager.default
        return candidates.first { fm.fileExists(atPath: $0.string) }
    }

    public func getSigningMethod() throws -> SigningMethod {
        let candidates = try signingMethodCandidates()
        if let method = findSigningMethod() {
            return method
        }

        // Nothing found — report what we looked for
        let expectedList = candidates.map { $0.0.string }.joined(separator: ", ")
        noora.error(.alert(
            "No signing key found for \(keyContextLabel) address '\(try keyStem(purpose: "signing key"))'",
            takeaways: [
                "Searched (in order): \(expectedList)"
            ]
        ))
        throw ExitCode.validationFailure
    }
    
    public func getVerificationKey() throws -> FilePath {
        let candidates = try verificationKeyCandidates()
        if let file = findVerificationKey() {
            return file
        }

        // Nothing found — report what we looked for
        let expectedList = candidates.map { $0.string }.joined(separator: ", ")
        noora.error(.alert(
            "No verification key found for \(keyContextLabel) address '\(try keyStem(purpose: "verification key"))'",
            takeaways: [
                "Searched (in order): \(expectedList)"
            ]
        ))
        throw ExitCode.validationFailure
    }
}
