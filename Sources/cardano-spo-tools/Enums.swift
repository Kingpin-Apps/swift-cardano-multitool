public enum LogLevel: String, CaseIterable, CodingKeyRepresentable, Codable, Hashable, Sendable {
    case info = "info"
    case debug = "debug"
    case warn = "warn"
    case error = "error"
}

public enum Mode: String, CaseIterable, CodingKeyRepresentable, Codable, Hashable , Sendable{
    case auto = "auto"
    case online = "online"
    case offline = "offline"
    case lite = "lite"
}

enum GetAddressBy: String, CaseIterable, CustomStringConvertible {
    case name
    case path
    
    var description: String {
        switch self {
            case .name:
                return "The name of the stem of the file."
            case .path:
                return "The path to the file."
        }
    }
}
