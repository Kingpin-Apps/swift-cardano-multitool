import Configuration
import SystemPackage

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
