import Foundation
import ArgumentParser
import Noora

enum BuildCommands: String, CaseIterable, CustomStringConvertible {
    case paymentAddress
    case stakeAddress
    
    var description: String {
        switch self {
            case .paymentAddress:
                return "Build a Cardano payment address from the Cardano-cli address key files."
            case .stakeAddress:
                return "Build a Cardano stake address from the stake verification key file."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .paymentAddress:
                return BuildMainCommand.PaymentAddress.self
            case .stakeAddress:
                return BuildMainCommand.StakeAddress.self
        }
    }
}

struct BuildMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build operations",
        subcommands: BuildCommands.allCases.map { $0.command() },
    )
    
    func run() async throws {        
        let noora = try await Terminal.shared.noora()
        
        let selectedOption: BuildCommands = noora.singleChoicePrompt(
            title: "Select Build Command",
            question: "Select the operation that you would like to perform.",
            description: "Build Commands to build addresses.",
        )
        
        print(noora.format(
            "Runing \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main()
    }
}
