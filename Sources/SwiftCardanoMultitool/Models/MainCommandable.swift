import ArgumentParser

protocol Subcommandable: CaseIterable, CustomStringConvertible, Equatable, RawRepresentable where Self.RawValue == String {
    static var subcommands: [any AsyncParsableCommand.Type] { get }

    func command() -> any AsyncParsableCommand.Type
}


protocol MainCommandable {
    associatedtype E: Subcommandable
    
    var name: String { get }
    
    func run() async throws
}

extension MainCommandable {
    
    func run() async throws {
        let selectedOption: E = noora.singleChoicePrompt(
            title: "Select \(.command(self.name)) Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        spacedPrint(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        )
        
        await selectedOption.command().main([])
    }
}
