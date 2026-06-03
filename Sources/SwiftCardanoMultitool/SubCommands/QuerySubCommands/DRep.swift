import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoChain
import SwiftCardanoCore

extension QueryMainCommand {
    struct DRep: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "drep",
            abstract: "Query on-chain registration, anchor metadata, and CIP-100 signatures for a DRep."
        )

        @Argument(help: "DRep identifier: bech32 (drep1…, drep_script1…, drep_always_abstain, drep_always_no_confidence), hex hash, or .drep / .drep.id / .drep.vkey file.")
        var drep: SwiftCardanoCore.DRep? = nil

        mutating func wizard() async throws {
            drep = try await getDRep(title: "DRep to query")
        }

        mutating func run() async throws {
            if drep == nil {
                try await wizard()
            }

            guard let drep = drep else {
                noora.error(.alert(
                    "DRep is required.",
                    takeaways: [
                        "Provide a valid bech32 DRep ID, hex hash, or DRep file.",
                        "Run with no argument to enter interactive mode.",
                    ]
                ))
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            let context = try await getContext(config: config)

            try await printContextInfo(config: config, context: context)

            try drepIdSummary(drep: drep)
            print()

            // Constants don't have on-chain registration to query.
            switch drep.credential {
                case .alwaysAbstain, .alwaysNoConfidence:
                    return
                case .verificationKeyHash, .scriptHash:
                    break
            }

            let info = try await noora.progressStep(
                message: "Querying DRep info...",
                successMessage: "Successfully retrieved DRep info.",
                errorMessage: "Failed to retrieve DRep info.",
                showSpinner: true
            ) { _ in
                try await context.drepInfo(drep: drep)
            }
            print()

            let currentEpoch = try await noora.progressStep(
                message: "Querying current epoch...",
                successMessage: "Current epoch retrieved.",
                errorMessage: "Failed to retrieve current epoch.",
                showSpinner: true
            ) { _ in
                try await context.epoch()
            }
            print()

            try drepInfoSummary(
                drep: drep,
                info: info,
                currentEpoch: currentEpoch,
                context: context
            )

            // Anchor verification only runs when we're actually online (i.e. not pure offline mode)
            // and the DRep published an anchor.
            if config.mode != .offline, info.status == .registered, let anchor = info.anchor {
                print()
                try await verifyDRepAnchor(anchor: anchor, config: config)
            }

            // Explorer link — every concrete explorer currently throws notImplemented for viewDRep
            // (added in protocol but no per-explorer impls yet), so swallow that gracefully.
            let explorer = config.blockchainExplorer.explorer(network: cardanoConfig.network)
            if let url = try? explorer.viewDRep(drep: drep) {
                spacedPrint("\(.link(title: url.absoluteString, href: url.absoluteString))")
            }
        }
    }
}
