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
    case gpgNotFound
    case notImplemented
    case gpgFailed(String)
    case invalidHex(String)
    case fileMissing(FilePath)
    case jsonDecodeError(String)
    case missingField(String)
    case encryptionError(String)
    case decryptionError(String)
    
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
        }
    }
}
