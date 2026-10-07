import Foundation
import Noora

/// How a transaction's time to live (`invalid-hereafter`) is chosen.
enum TTLChoice: Equatable, Sendable {
    /// Chain tip plus this many slots, queried when the transaction is built.
    case tipPlus(UInt64)
    /// An absolute slot after which the transaction is invalid.
    case absolute(UInt64)
    /// No TTL: the transaction never expires.
    case never
}

/// Ask how the transaction should expire. `defaultExtra` is offered as the default number
/// of slots for the chain-tip option.
func promptTTLChoice(defaultExtra: UInt64) -> TTLChoice {
    spacedPrint("\n\(.primary("━━━ Time To Live ━━━"))\n")
    let tipPlusExtra = "Chain tip + extra slots (default: \(defaultExtra))"
    let absoluteSlot = "Absolute slot"
    let noTTL = "None (the transaction never expires)"
    let choice = noora.singleChoicePrompt(
        title: "Time To Live",
        question: "When should the transaction expire (invalid-hereafter)?",
        options: [tipPlusExtra, absoluteSlot, noTTL],
        description: "The chain tip is queried when the transaction is built. A TTL limits how long an unsubmitted transaction stays valid."
    )
    switch choice {
    case tipPlusExtra:
        let extra = noora.textPrompt(
            title: "Extra Slots",
            prompt: "Enter the number of slots to add to the chain tip:",
            description: "One slot is one second on mainnet and the public testnets, so 3600 slots is one hour.",
            defaultValue: "\(defaultExtra)",
            collapseOnAnswer: true,
            validationRules: [
                NonEmptyValidationRule(error: "Extra slots cannot be empty."),
                IntegerValidationRule(min: 1, error: "Extra slots must be a positive integer.")
            ]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return .tipPlus(UInt64(extra) ?? defaultExtra)
    case absoluteSlot:
        let slot = noora.textPrompt(
            title: "Invalid Hereafter",
            prompt: "Enter the absolute slot after which the transaction is invalid:",
            collapseOnAnswer: true,
            validationRules: [
                NonEmptyValidationRule(error: "Slot cannot be empty."),
                IntegerValidationRule(error: "Slot must be a non-negative integer.")
            ]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return .absolute(UInt64(slot) ?? 0)
    default:
        return .never
    }
}
