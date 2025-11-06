import Foundation
import ArgumentParser
import Noora

enum ProtectCommands: String, CaseIterable, CustomStringConvertible {
    case encrypt
    case decrypt
    case back
    case exit
    
    var description: String {
        switch self {
            case .encrypt:
                return "Encrypt a file with a password."
            case .decrypt:
                return "Decrypt a file with a password."
            case .back:
                return "Go back to the main menu."
            case .exit:
                return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .encrypt:
                return ProtectMainCommand.Encrypt.self
            case .decrypt:
                return ProtectMainCommand.Decrypt.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct ProtectMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "protect",
        abstract: "Encrypt/Decrypt operations",
        subcommands: ProtectCommands.allCases.map { $0.command() },
    )
    
    func run() async throws {                
        let selectedOption: ProtectCommands = noora.singleChoicePrompt(
            title: "Select Protect Command",
            question: "Select the operation that you would like to perform.",
            description: "Protect your files by encrypting or decrypting them using password-based encryption."
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}
