import Foundation
import SystemPackage

public enum SwiftCardanoMultitoolError: Error, LocalizedError {
    case unsupportedNetwork(String)
    case fileAlreadyExists(FilePath)
    case fileNotFound(FilePath)
    case notSocket(FilePath)
    case downloadFailed(URL, String)
    case ioError(Error)
    case jsonError(String)
    case operationError(String)
    case gpgNotFound
    case notImplemented
    case gpgFailed(String)
    case invalidHex(String)
    case invalidConfiguration(String)
    case fileMissing(FilePath)
    case jsonDecodeError(String)
    case missingField(String)
    case encryptionError(String)
    case decryptionError(String)
    case adahandleOfflineMode
    case adahandleNetworkNotSupported(String)
    case adahandleNotFound(String)
    case adahandleInvalidFormat(String)
    case adahandleInvalidAddress(String)
    case adahandleAssetNotOnAddress(String, String)
    case adahandleAPIError(String, Int?)
    case adahandleAddressMismatch(String, String)
    
    public var errorDescription: String? {
        switch self {
            case .unsupportedNetwork(let network):
                return "Network not supported: \(network)"
            case .fileAlreadyExists(let path):
                return "File already exists at path: \(path)"
            case .fileNotFound(let path):
                return "File not found at path: \(path)"
            case .notSocket(let path):
                return "Path is not a socket: \(path)"
            case .downloadFailed(let url, let message):
                return "Download failed from URL: \(url). Error: \(message)"
            case .ioError(let error):
                return "I/O Error: \(error.localizedDescription)"
            case .jsonError(let message):
                return "JSON Error: \(message)"
            case .gpgNotFound:
                return "GPG binary not found in system PATH"
            case .gpgFailed(let message):
                return "GPG operation failed: \(message)"
            case .invalidConfiguration(let config):
                return "Invalid configuration: \(config)"
            case .invalidHex(let hex):
                return "Invalid hexadecimal string: \(hex)"
            case .fileMissing(let path):
                return "Required file is missing: \(path)"
            case .jsonDecodeError(let message):
                return "JSON Decoding Error: \(message)"
            case .missingField(let field):
                return "Missing required field: \(field)"
            case .encryptionError(let message):
                return "Encryption Error: \(message)"
            case .decryptionError(let message):
                return "Decryption Error: \(message)"
            case .notImplemented:
                return "This feature is not yet implemented"
            case .adahandleOfflineMode:
                return "AdaHandles are only supported in online or lite mode"
            case .adahandleNetworkNotSupported(let network):
                return "AdaHandles are not supported on network: \(network)"
            case .adahandleNotFound(let message):
                return "Could not resolve AdaHandle: \(message)"
            case .adahandleInvalidFormat(let handle):
                return "Invalid AdaHandle format: \(handle)"
            case .adahandleInvalidAddress(let address):
                return "Resolved address is not a valid payment address: \(address)"
            case .adahandleAssetNotOnAddress(let handle, let address):
                return "AdaHandle '\(handle)' asset not found on address: \(address)"
            case .adahandleAPIError(let message, let code):
                if let code = code {
                    return "AdaHandle API Error (HTTP \(code)): \(message)"
                }
                return "AdaHandle API Error: \(message)"
            case .adahandleAddressMismatch(let address1, let address2):
                return "AdaHandle address mismatch - API: \(address1), Datum: \(address2)"
            case .operationError(let message):
                return "Operation Error: \(message)"
        }
    }
}

// MARK: - CIP129Error

enum CIP129Error: Error, LocalizedError {
    case invalidFormat
    case invalidHex
    case bech32EncodingFailed
    
    var errorDescription: String? {
        switch self {
            case .invalidFormat:
                return "Please provide a valid Governance-Action-ID in the format like: 365042be18639f776520fca54e9cb2df04ab9ecd43bf50078045d8cc6ee491be#0"
            case .invalidHex:
                return "Invalid hex data."
            case .bech32EncodingFailed:
                return "Bech32 encoding failed."
        }
    }
}

// MARK: - AddressInfoError

/// Errors specific to AddressInfo operations
public enum AddressInfoError: Error, LocalizedError, Sendable {
    case missingIdentifier
    case invalidAddress(String)
    case unresolvedAdaHandle(String)
    case cliError(String)
    case decodeError(String)
    
    public var errorDescription: String? {
        switch self {
            case .missingIdentifier:
                return "AddressInfo requires at least one of: address, addressFile, or adaHandle"
            case .invalidAddress(let details):
                return "Invalid address: \(details)"
            case .unresolvedAdaHandle(let handle):
                return "Ada handle resolution not yet implemented for: \(handle)"
            case .cliError(let details):
                return "CLI error: \(details)"
            case .decodeError(let details):
                return "Decode error: \(details)"
        }
    }
}

