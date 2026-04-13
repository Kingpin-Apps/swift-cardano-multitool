import Foundation
import ArgumentParser
import Noora

enum ProtectCommands: String, Subcommandable {
    case encrypt
    case decrypt
    case back
    case exit
    
    var description: String {
        switch self {
            case .encrypt: return "Encrypt - Encrypt a file with a password."
            case .decrypt: return "Decrypt - Decrypt a file with a password."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
        }
    }
    
    static var subcommands: [any AsyncParsableCommand.Type] {
        return Self.allCases.compactMap {
            switch $0 {
                case .back, .exit:
                    return .none
                default:
                    return $0.command()
            }
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .encrypt: return ProtectMainCommand.Encrypt.self
            case .decrypt: return ProtectMainCommand.Decrypt.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct ProtectMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = ProtectCommands
    
    var name: String { "Protect" }
    
    static let configuration = CommandConfiguration(
        commandName: "protect",
        abstract: "Encrypt/Decrypt operations",
        discussion: """
        Encrypting files allows you to protect sensitive information by 
        requiring a password to access the contents. Decrypting files allows you 
        to access the contents of previously encrypted files by providing the 
        correct password. Select the desired operation to proceed with 
        encrypting or decrypting your files.
        """,
        subcommands: ProtectCommands.subcommands,
    )
}
