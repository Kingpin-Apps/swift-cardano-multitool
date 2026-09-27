import ArgumentParser

struct ExitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Exit.", shouldDisplay: false)
    
    mutating func run() async throws {
        throw ExitCode.success
    }
}
