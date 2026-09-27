import Foundation
import ArgumentParser
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftMnemonic
import SystemPackage


extension URL: @retroactive _SendableMetatype {}
extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(string: argument)
    }
}

extension FilePath: @retroactive _SendableMetatype {}
extension FilePath: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }

    /// Every `FilePath` option completes paths unless it names something narrower.
    public static var defaultCompletionKind: CompletionKind {
        .file()
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
    
    /// Every wordlist except the `unsupported` placeholder.
    public static var allValueStrings: [String] {
        allCases.filter { $0 != .unsupported }.map(\.rawValue)
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
    
    /// The networks `init(argument:)` accepts; `CaseIterable` also lists `custom(_)`.
    public static var allValueStrings: [String] {
        ["mainnet", "preprod", "preview", "guildnet", "sanchonet"]
    }
}

extension SwiftCardanoCIPs.CIP129.Prefix: @retroactive _SendableMetatype {}
extension SwiftCardanoCIPs.CIP129.Prefix: @retroactive ExpressibleByArgument {}
