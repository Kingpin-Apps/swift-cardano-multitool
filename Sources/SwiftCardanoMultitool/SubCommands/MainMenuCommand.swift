import ArgumentParser
import SwiftCardanoUtils

struct MainMenuCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Show the main menu.")
    
    mutating func run() async throws {
        let selectedOption: MainCommands = noora.singleChoicePrompt(
            title: "Select Command",
            question: "Select the operation that you would like to perform.",
            description: "CSPO Tools can help you manage and optimize your Cardano Stake Pool Operations."
        )
        
        print(noora.format(
            "Runing \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main()
    }
}
