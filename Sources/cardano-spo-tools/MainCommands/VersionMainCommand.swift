import Foundation
import ArgumentParser
import Noora

struct VersionMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show the application's version."
    )
    
    func run() async throws {
        let noora = try await Terminal.shared.noora()
    #if DEBUG
        let version = "development"
    #else
        let version = ProcessInfo.processInfo.environment["PACKAGE_VERSION"] ?? "unknown"
    #endif
        
        let text: TerminalText = """
        \(.raw("Cardano SPO Tools"))
        Version: \(.muted(version))
        Platform: \(.muted(ProcessInfo.processInfo.operatingSystemVersionString))
        """
        
        print(noora.format(text))
    }
}
