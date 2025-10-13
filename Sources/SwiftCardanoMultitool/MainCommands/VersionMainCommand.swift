import Foundation
import ArgumentParser
import Noora
import SwiftCardanoUtils

struct VersionMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show the application's version."
    )
    
    func run() async throws {
        let noora = try await Terminal.shared.noora()
        
        let config = try await MultitoolConfig.load()
    #if DEBUG
        let version = "development"
    #else
        let version = ProcessInfo.processInfo.environment["PACKAGE_VERSION"] ?? "unknown"
    #endif
        
        let cli = try await CardanoCLI(
            configuration: config.toSwiftCardanoUtilsConfig()
        )
        
        let node = try await CardanoNode(
            configuration: config.toSwiftCardanoUtilsConfig()
        )
        
        let text: TerminalText = """
        \(.raw("Cardano SPO Tools"))
        Version: \(.info(version))
        Platform: \(.info(ProcessInfo.processInfo.operatingSystemVersionString))
        cardano-cli version: \(await .info(try cli.version()))
        cardano-node version: \(await .info(try node.version()))
        """
        
        print(noora.format(text))
    }
}
