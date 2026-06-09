import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SharedCertificateOptions defaults")
struct SharedCertificateOptionsTests {

    @Test("default parse leaves outFile nil and generateTransaction false")
    func defaults() throws {
        let opts = try SharedCertificateOptions.parse([])
        #expect(opts.outFile == nil)
        #expect(opts.generateTransaction == false)
    }

    @Test("--generate-transaction flag flips the bool")
    func generateTransactionFlag() throws {
        let opts = try SharedCertificateOptions.parse(["--generate-transaction"])
        #expect(opts.generateTransaction == true)
    }

    @Test("--out-file sets the output file path")
    func outFileShort() throws {
        let opts = try SharedCertificateOptions.parse(["-o", "/tmp/x.cert"])
        #expect(opts.outFile?.string == "/tmp/x.cert")
    }
}

@Suite("SharedTransactionOptions defaults")
struct SharedTransactionOptionsTests {

    @Test("default parse populates documented defaults")
    func defaults() throws {
        let opts = try SharedTransactionOptions.parse([])
        #expect(opts.messages.isEmpty)
        #expect(opts.passphrase == "cardano")
        #expect(opts.encryption == nil)
        #expect(opts.metadataJson.isEmpty)
        #expect(opts.metadataCbor.isEmpty)
        #expect(opts.utxoFilter.isEmpty)
        #expect(opts.utxoLimit == nil)
        #expect(opts.skipUtxoWithAsset.isEmpty)
        #expect(opts.onlyUtxoWithAsset.isEmpty)
        #expect(opts.useCardanoCLI == false)
        #expect(opts.save == true)
        #expect(opts.submit == false)
    }

    @Test("--no-save inverts the save flag")
    func noSaveInversion() throws {
        let opts = try SharedTransactionOptions.parse(["--no-save"])
        #expect(opts.save == false)
    }

    @Test("--submit and --use-cardano-cli set their flags")
    func submitAndCardanoCLI() throws {
        let opts = try SharedTransactionOptions.parse(["--submit", "--use-cardano-cli"])
        #expect(opts.submit == true)
        #expect(opts.useCardanoCLI == true)
    }

    @Test("messages can be supplied multiple times")
    func multipleMessages() throws {
        let opts = try SharedTransactionOptions.parse([
            "--message", "hello", "world"
        ])
        #expect(opts.messages == ["hello", "world"])
    }

    @Test("passphrase can be overridden")
    func customPassphrase() throws {
        let opts = try SharedTransactionOptions.parse(["--passphrase", "super-secret"])
        #expect(opts.passphrase == "super-secret")
    }
}
