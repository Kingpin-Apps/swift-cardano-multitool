import Foundation
import ArgumentParser
import Noora

extension QueryMainCommand {
    struct AssetMeta: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "asset-meta",
            abstract: "Query off-chain metadata for a native asset from the Cardano Token Registry.",
            aliases: ["assetmeta"]
        )

        @Argument(help: "Asset subject (56-120 hex chars) OR path to a .asset JSON file.")
        var asset: String? = nil

        mutating func wizard() async throws {
            switch try await enterAssetMetaBy(title: "Asset") {
                case .hexSubject:
                    asset = noora.textPrompt(
                        title: "Asset Subject",
                        prompt: "Enter the asset subject (policyId || assetNameHex):",
                        description: "56-120 hex characters.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Asset subject cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    asset = noora.textPrompt(
                        title: "Asset File",
                        prompt: "Enter the path to a .asset JSON file:",
                        description: "JSON file with a top-level `subject` field.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Asset file path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        mutating func run() async throws {
            if asset == nil {
                try await wizard()
            }
            guard let asset else {
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            
            try await printContextInfo(config: config)

            guard config.mode != .offline else {
                noora.error(.alert(
                    "This command requires online mode.",
                    takeaways: ["Set mode to 'online', 'lite', or 'auto' in your config."]
                ))
                throw ExitCode.failure
            }

            guard let registryURL = config.tokenMetaServer.forNetwork(cardanoConfig.network) else {
                noora.error(.alert(
                    "No token metadata server configured for network \(.primary("\(cardanoConfig.network)"))."
                ))
                throw ExitCode.failure
            }

            let subject = try resolveAssetSubject(input: asset)

            spacedPrint("Checking Token-Registry (\(.link(title: registryURL.absoluteString, href: registryURL.absoluteString))) for Asset-Subject: \(.primary(subject))")

            let (metadata, _) = try await noora.progressStep(
                message: "Querying registry...",
                successMessage: "Metadata retrieved.",
                errorMessage: "Failed to retrieve metadata.",
                showSpinner: true
            ) { _ in
                try await fetchAssetMetadata(subject: subject, registryURL: registryURL)
            }

            guard let metadata else {
                noora.warning(.alert(
                    "No data found on the registry for \(.primary(subject))."
                ))
                return
            }

            try printAssetMetadata(metadata, subject: subject)
        }
    }
}
