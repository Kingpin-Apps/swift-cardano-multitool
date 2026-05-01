import Foundation
import SystemPackage

/// Environment variables recognised by `scm`.
///
/// Set these in your shell or CI environment to configure runtime behaviour
/// without modifying the config file.
enum Environment: String {
    case blockfrostProjectId = "BLOCKFROST_PROJECT_ID"
    case config = "CARDANO_MULTITOOL_CONFIG"
    case configs = "CARDANO_MULTITOOL_CONFIGS"
    case decryptPassword = "CARDANO_MULTITOOL_DECRYPT_PASSWORD"
    case skipPrompt = "CARDANO_MULTITOOL_SKIP_PROMPT"
    case useCardanoCLI = "CARDANO_MULTITOOL_USE_CARDANO_CLI"
    case useSwiftCardano = "CARDANO_MULTITOOL_USE_SWIFT_CARDANO"
    
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
    
    static func getBool(_ name: Environment) -> Bool {
        if let value = get(name)?.lowercased() {
            return value == "1" || value.lowercased() == "true" || value.lowercased() == "yes"
        }
        return false
    }
    
    static func set(_ name: Environment, value: String?) {
        if value == nil {
            _ = unsetenv(name.rawValue)
        } else {
            setenv(name.rawValue, value!, 1)
        }
    }
}
