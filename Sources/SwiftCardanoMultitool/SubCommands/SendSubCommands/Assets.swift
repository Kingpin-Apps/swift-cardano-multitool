import Foundation
import ArgumentParser


extension SendMainCommand {
    struct Assets: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send ADA.")
        func run() async throws { print("Send ada command not yet implemented") }
    }
}
