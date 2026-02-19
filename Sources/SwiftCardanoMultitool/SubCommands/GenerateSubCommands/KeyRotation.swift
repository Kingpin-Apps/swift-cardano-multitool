import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore


extension GenerateMainCommand {
    struct KeyRotation: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rotate KES Keys and Node Operational Certificate."
        )
        
        func run() async throws {
            print("Key rotation command not yet implemented")
        }
    }
}
