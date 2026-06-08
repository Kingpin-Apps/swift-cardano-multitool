import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner

extension SignMainCommand {

    struct SignCIP36: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip36",
            abstract: "Build a CIP-36 Catalyst voting registration (or deregistration).",
            usage: """
            scm sign cip36 \\
                --payment-address addr1... \\
                --vote-public-key vote.vkey \\
                --secret-key stake.skey
            scm sign cip36 --deregister --secret-key stake.skey
            """
        )

        @Option(name: .customLong("payment-address"), help: "Rewards address (bech32 or path to .addr file). Required for registration.")
        var paymentAddress: String? = nil

        @Option(name: .customLong("vote-public-key"), parsing: .singleValue, help: "Voting public key — repeat for multi-delegation. Accepts a .vkey path or hex.")
        var votePublicKeys: [String] = []

        @Option(name: .customLong("vote-weight"), parsing: .singleValue, help: "Voting weight per --vote-public-key (must match the count of --vote-public-key when more than one).")
        var voteWeights: [UInt32] = []

        @Option(name: [.customShort("s"), .customLong("secret-key")], help: "Stake signing key — path to a .skey file or raw hex.")
        var secretKey: String? = nil

        @Option(name: .long, help: "Monotonic nonce. Defaults to the current mainnet slot height if omitted.")
        var nonce: UInt64? = nil

        @Option(name: .customLong("vote-purpose"), help: "Voting purpose discriminator. 0 = Catalyst (default).")
        var votePurpose: UInt64 = 0

        @Flag(name: .long, help: "Build a deregistration blob instead of a registration.")
        var deregister: Bool = false

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            deregister = noora.yesOrNoChoicePrompt(
                title: "Operation",
                question: "Build a deregistration (instead of registration)?",
                defaultAnswer: false
            )
            secretKey = SignerUtils.promptSecretKeyPath(
                title: "Stake Signing Key",
                prompt: "Enter the path to the stake .skey file:"
            )
            if !deregister {
                paymentAddress = SignerUtils.promptAddress(
                    title: "Rewards Address",
                    prompt: "Enter the rewards (payment) address:"
                )
                var addMore = true
                while addMore {
                    let v = noora.textPrompt(
                        title: "Voting Public Key",
                        prompt: "Enter a vote .vkey path or hex:",
                        validationRules: [NonEmptyValidationRule(error: "Vote key cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    votePublicKeys.append(v)
                    if votePublicKeys.count > 1 || noora.yesOrNoChoicePrompt(
                        title: "Vote Weight",
                        question: "Specify a weight for this vote key?",
                        defaultAnswer: false
                    ) {
                        let w = noora.textPrompt(
                            title: "Weight",
                            prompt: "Enter the weight (unsigned integer):",
                            validationRules: [NonEmptyValidationRule(error: "Weight cannot be empty.")]
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        voteWeights.append(UInt32(w) ?? 1)
                    }
                    addMore = noora.yesOrNoChoicePrompt(
                        title: "Add another vote key?",
                        question: "Add another voting key?",
                        defaultAnswer: false
                    )
                }
            }
            if noora.yesOrNoChoicePrompt(
                title: "Nonce",
                question: "Override the auto-computed mainnet-slot nonce?",
                defaultAnswer: false
            ) {
                nonce = UInt64(noora.textPrompt(
                    title: "Nonce",
                    prompt: "Enter the nonce:",
                    validationRules: [NonEmptyValidationRule(error: "Nonce cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        mutating func run() async throws {
            if secretKey == nil || (!deregister && (paymentAddress == nil || votePublicKeys.isEmpty)) {
                try await wizard()
            }

            let stakeKey = try SignerUtils.resolveSecretKey(secretKey!)
            let resolvedNonce = nonce ?? SignerUtils.currentMainnetSlotNonce()

            let aux: AuxiliaryData
            if deregister {
                aux = try Signer.CIP36.makeDeregistration(
                    stakeSigningKey: stakeKey,
                    nonce: resolvedNonce,
                    votingPurpose: votePurpose
                )
            } else {
                guard let addr = paymentAddress else {
                    throw ValidationError("--payment-address is required for registration.")
                }
                let rewardsAddress = try SignerUtils.resolveAddress(addr)
                guard !votePublicKeys.isEmpty else {
                    throw ValidationError("At least one --vote-public-key is required.")
                }
                if votePublicKeys.count > 1 && votePublicKeys.count != voteWeights.count {
                    throw ValidationError("--vote-weight must be supplied once per --vote-public-key when delegating to more than one.")
                }
                let weights: [UInt32] = voteWeights.isEmpty
                    ? Array(repeating: 1, count: votePublicKeys.count)
                    : voteWeights
                let delegations: [Signer.CIP36.Delegation] = try zip(votePublicKeys, weights).map { (key, weight) in
                    let bytes = try SignerUtils.resolveRawKey(key)
                    return Signer.CIP36.Delegation(votingKey: bytes, weight: weight)
                }
                aux = try Signer.CIP36.makeRegistration(
                    delegations: delegations,
                    stakeSigningKey: stakeKey,
                    rewardsAddress: rewardsAddress,
                    nonce: resolvedNonce,
                    votingPurpose: votePurpose
                )
            }

            let cborHex = try aux.toCBORHex()
            let rendered: String
            switch output.format {
            case .plain:
                rendered = cborHex
            case .json:
                rendered = try SignerUtils.jsonString([
                    "cborHex": cborHex,
                    "deregister": deregister ? "true" : "false",
                ])
            case .jsonExtended:
                rendered = try SignerUtils.jsonString([
                    "workMode": deregister ? "sign-cip36-deregister" : "sign-cip36",
                    "cborHex": cborHex,
                    "nonce": String(resolvedNonce),
                    "votingPurpose": String(votePurpose),
                ])
            }
            try await SignerUtils.emit(rendered, to: output.outFile)
        }
    }
}
