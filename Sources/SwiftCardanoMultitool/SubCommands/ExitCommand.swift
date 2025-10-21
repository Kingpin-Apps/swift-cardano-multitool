import ArgumentParser

struct ExitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Exit.")
    
    mutating func run() async throws {
        throw ExitCode.success
    }
}
