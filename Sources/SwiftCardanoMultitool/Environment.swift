import Foundation
import SystemPackage

/// Environment variables
enum Environment: String {
    case config = "CSPO_TOOLS_CONFIG"
    case configs = "CSPO_TOOLS_CONFIGS"
    case decryptPassword = "CSPO_DECRYPT_PASSWORD"
    
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
