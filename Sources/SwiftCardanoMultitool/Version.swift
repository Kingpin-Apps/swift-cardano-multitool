import Foundation
import Version

struct CommitzenConfig: Codable {
    let commitizen: CommitzenInfo
    
    struct CommitzenInfo: Codable {
        let version: String
    }
}

extension SwiftCardanoMultitool {
    static var version: Version? {
        // Try to read version from cz.json in bundle resources
        guard let resourceURL = Bundle.module.url(forResource: "cz", withExtension: "json"),
              let data = try? Data(contentsOf: resourceURL),
              let config = try? JSONDecoder().decode(CommitzenConfig.self, from: data) else {
            // Fallback to hardcoded version if cz.json is not available
            return Version("0.1.0")
        }
        
        return Version(config.commitizen.version)
    }
}
