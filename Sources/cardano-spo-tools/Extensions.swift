import Foundation
import SystemPackage
import ArgumentParser
import CardanoCLITools
import Configuration
import Noora

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
