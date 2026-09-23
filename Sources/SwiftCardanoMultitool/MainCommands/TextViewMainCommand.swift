import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

/// Decode text envelope files into a readable view — a friendlier
/// `cardano-cli text-view decode-cbor`.
struct TextViewMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "text-view",
        abstract: "Decode text envelope files into a readable view.",
        usage: """
        scm text-view pool.cert
        scm text-view --in-file node.opcert --output-cbor
        scm text-view --in-file tx.signed --json --out-file tx.json
        """,
        discussion: """
        Reads keys, certificates, operational certificates and issue counters, votes,
        governance proposals, transactions, witnesses, Plutus scripts and native script
        JSON, and shows their fields with derived identifiers (key hashes, pool IDs,
        DRep IDs, addresses). Other text envelopes are shown as a generic CBOR tree.
        Signing key material stays hidden unless --show-secret is given.
        """,
        aliases: ["view"]
    )

    @Argument(help: "The text envelope file to decode.")
    var file: FilePath? = nil

    @Option(name: [.short, .long], help: "The text envelope file to decode.")
    var inFile: FilePath? = nil

    @Flag(name: .customLong("output-cbor"), help: "Also show the CBOR hex and CBOR diagnostic notation.")
    var outputCBOR = false

    @Flag(name: .long, help: "Output JSON instead of formatted text.")
    var json = false

    @Flag(name: .customLong("show-secret"), help: "Show signing key material instead of hiding it.")
    var showSecret = false

    @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
    var outFile: FilePath? = nil

    func validate() throws {
        if file != nil && inFile != nil {
            throw ValidationError("Provide the file either as an argument or with --in-file, not both.")
        }
    }

    mutating func wizard() async throws {
        inFile = try promptFilePath(
            title: "Text Envelope File",
            question: "Select the file to decode:",
            matching: { name in
                [".vkey", ".skey", ".cert", ".opcert", ".counter", ".vote", ".action", ".tx", ".raw",
                 ".signed", ".witness", ".plutus", ".script", ".json"].contains(where: name.hasSuffix)
            }
        )
        outputCBOR = noora.yesOrNoChoicePrompt(
            title: "CBOR",
            question: "Also show the CBOR hex and diagnostic notation?",
            defaultAnswer: false,
            description: "The raw CBOR is useful for comparing with cardano-cli text-view decode-cbor."
        )
    }

    mutating func run() async throws {
        if file == nil && inFile == nil {
            guard isInteractiveSession() else {
                noora.error(.alert("Missing file to decode.", takeaways: ["Pass the file as an argument or use --in-file."]))
                throw ExitCode.validationFailure
            }
            try await wizard()
        }
        guard let path = (file ?? inFile).map(FileUtils.absolutePath) else {
            throw ExitCode.validationFailure
        }
        guard let data = FileManager.default.contents(atPath: path.string) else {
            noora.error(.alert("File not found: \(path.string)", takeaways: ["Check the path and try again."]))
            throw ExitCode.failure
        }

        let decoder = TextViewDecoder(
            network: await Self.configuredNetwork(),
            showSecret: showSecret,
            includeCBOR: outputCBOR
        )

        let view: TextView
        do {
            view = try decoder.view(fileData: data, source: path.lastComponent?.string ?? path.string)
        } catch {
            noora.error(.alert("Could not decode \(path.string).", takeaways: ["\(error.localizedDescription)"]))
            throw ExitCode.failure
        }

        if let outFile {
            let rendered = json ? view.json() : view.text(colored: false)
            try (rendered + "\n").write(toFile: FileUtils.absolutePath(outFile).string, atomically: true, encoding: .utf8)
            if isatty(FileHandle.standardOutput.fileDescriptor) != 0 {
                noora.success(.alert("Saved to \(pathComponent(outFile.string))"))
            }
            return
        }

        let colored = isatty(FileHandle.standardOutput.fileDescriptor) != 0
        print(json ? view.json() : view.text(colored: colored))
    }

    /// The configured network for derived addresses, or nil when no configuration is available.
    private static func configuredNetwork() async -> NetworkId? {
        // Loading reports a missing configuration as an error; decoding doesn't need one.
        if Configs.override == nil {
            guard let path = Environment.getFilePath(.config),
                  FileManager.default.fileExists(atPath: path.string) else { return nil }
        }
        guard let config = try? await MultitoolConfig.load(quiet: true),
              let cardanoConfig = try? getCardanoConfig(config: config) else {
            return nil
        }
        return cardanoConfig.network.networkId
    }
}
