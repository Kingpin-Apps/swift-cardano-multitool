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
        let data = Data(PackageResources.cz_json)
        guard let config = try? JSONDecoder().decode(CommitzenConfig.self, from: data) else {
            // Fallback to hardcoded version if cz.json is not available
            return Version("0.1.0")
        }
        
        return Version(config.commitizen.version)
    }
}
