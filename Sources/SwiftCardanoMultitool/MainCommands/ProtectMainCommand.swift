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

/// Password-based encryption and decryption of sensitive files.
///
/// Use to protect private key files (`.skey`) and other sensitive material
/// at rest. See <doc:ProtectCommand> for full documentation.
struct ProtectMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = ProtectCommands

    var name: String { "Protect" }

    static let configuration = CommandConfiguration(
        commandName: "protect",
        abstract: "Encrypt or decrypt sensitive files with a password.",
        discussion: """
        Protect private key files and other sensitive material using
        password-based encryption. Decrypt files on demand using the password
        or the CARDANO_MULTITOOL_DECRYPT_PASSWORD environment variable.
        """,
        subcommands: ProtectCommands.subcommands,
    )
}
