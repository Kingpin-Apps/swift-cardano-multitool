import Foundation

public enum CardanoSPOToolsError: Error, LocalizedError {
    case unsupportedNetwork(String)
    case fileAlreadyExists(String)
    
    public var errorDescription: String? {
        switch self {
            case .unsupportedNetwork(let network):
                return "Network not supported: \(network)"
            case .fileAlreadyExists(let path):
                return "File already exists at path: \(path)"
        }
    }
}
