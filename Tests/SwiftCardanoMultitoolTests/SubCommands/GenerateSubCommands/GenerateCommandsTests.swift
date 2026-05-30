import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand smoke tests")
struct GenerateCommandsTests {

    @Test("KeyRotation: abstract is set")
    func keyRotationAbstract() {
        #expect(GenerateMainCommand.KeyRotation.configuration.abstract == "Rotate KES Keys and Node Operational Certificate.")
    }

    @Test("NodeColdKeys: abstract is set")
    func nodeColdKeysAbstract() {
        #expect(GenerateMainCommand.NodeColdKeys.configuration.abstract == "Generate the node cold keys.")
    }

    @Test("NodeKESKeys: abstract is set")
    func nodeKESKeysAbstract() {
        #expect(GenerateMainCommand.NodeKESKeys.configuration.abstract == "Generate the node KES keys.")
    }

    @Test("NodeVRFKeys: abstract is set")
    func nodeVRFKeysAbstract() {
        #expect(GenerateMainCommand.NodeVRFKeys.configuration.abstract == "Generate the node VRF keys.")
    }

    @Test("NodeOperationalCertificate: abstract is set")
    func nodeOpCertAbstract() {
        #expect(GenerateMainCommand.NodeOperationalCertificate.configuration.abstract == "Generate the node operational certificate.")
    }

    @Test("PaymentAddressOnly: abstract is set")
    func paymentAddressOnlyAbstract() {
        #expect(GenerateMainCommand.PaymentAddressOnly.configuration.abstract == "Generate a payment address only.")
    }

    @Test("PaymentAndStakeAddress: abstract is set")
    func paymentAndStakeAbstract() {
        #expect(GenerateMainCommand.PaymentAndStakeAddress.configuration.abstract == "Generate a payment and stake address.")
    }

    @Test("PoolJSON: commandName is 'pool-json'")
    func poolJSONCommandName() {
        #expect(GenerateMainCommand.PoolJSON.configuration.commandName == "pool-json")
    }

    @Test("each Generate subcommand parses with no arguments")
    func eachParsesEmpty() throws {
        _ = try GenerateMainCommand.KeyRotation.parse([])
        _ = try GenerateMainCommand.NodeColdKeys.parse([])
        _ = try GenerateMainCommand.NodeKESKeys.parse([])
        _ = try GenerateMainCommand.NodeVRFKeys.parse([])
        _ = try GenerateMainCommand.NodeOperationalCertificate.parse([])
        _ = try GenerateMainCommand.PaymentAddressOnly.parse([])
        _ = try GenerateMainCommand.PaymentAndStakeAddress.parse([])
        _ = try GenerateMainCommand.PoolJSON.parse([])
    }
}
