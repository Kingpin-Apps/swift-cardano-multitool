import Foundation
import SystemPackage

/// Environment variables
enum Environment: String {
    case config = "CARDANO_MULTITOOL_CONFIG"
    case configs = "CARDANO_MULTITOOL_CONFIGS"
    case decryptPassword = "CARDANO_MULTITOOL_DECRYPT_PASSWORD"
    case blockfrostProjectId = "BLOCKFROST_PROJECT_ID"
    
    static func get(_ name: Environment) -> String? {
        guard let cString = getenv(name.rawValue) else {
            return nil
        }
        return String(cString: cString)
    }
    
    static func getFilePath(_ name: Environment) -> FilePath? {
        if let path = get(name) {
            return FilePath(path)
        }
        return nil
    }
    
    static func set(_ name: Environment, value: String?) {
        if value == nil {
            _ = unsetenv(name.rawValue)
        } else {
            setenv(name.rawValue, value!, 1)
        }
    }
}
