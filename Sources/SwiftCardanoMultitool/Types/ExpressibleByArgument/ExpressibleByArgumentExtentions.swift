import Foundation
import ArgumentParser
import SwiftCardanoCore
import SwiftMnemonic
import SystemPackage


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

extension Language: @retroactive _SendableMetatype {}
extension Language: @retroactive ExpressibleByArgument, @retroactive CustomStringConvertible {
    public var description: String {
        self.rawValue
    }
    
    public init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }
}

extension WordCount: @retroactive _SendableMetatype {}
extension WordCount: @retroactive ExpressibleByArgument, @retroactive CustomStringConvertible {
    public var description: String {
        String(self.rawValue)
    }
    
    public init?(argument: String) {
        self.init(rawValue: Int(argument) ?? 24)
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
