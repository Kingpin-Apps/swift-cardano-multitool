import Foundation
@preconcurrency import Noora

/// Abstraction over the subset of `Noora` prompt methods used by SubCommand wizards.
///
/// Production code uses `NooraPromptProvider`, which delegates to the global `noora`
/// instance. Tests override `Prompts.$current` with a `ScriptedPromptProvider` (defined
/// in the test target) that returns canned responses.
///
/// Only the variants we actually call are included — covering every Noora overload
/// would balloon this protocol without test value. Add more methods here when a new
/// SubCommand prompt pattern needs coverage.
public protocol PromptProvider: Sendable {
    /// Single-choice prompt over a `CaseIterable` enum.
    func singleChoicePrompt<T: CaseIterable & CustomStringConvertible & Equatable & Sendable>(
        title: TerminalText?,
        question: TerminalText,
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T where T.AllCases: Sendable

    /// Single-choice prompt over an explicit list of options.
    func singleChoicePrompt<T: CustomStringConvertible & Equatable & Sendable>(
        title: TerminalText?,
        question: TerminalText,
        options: [T],
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T

    /// Free-text prompt returning the user's typed input.
    func textPrompt(
        title: TerminalText?,
        prompt: TerminalText,
        description: TerminalText?,
        collapseOnAnswer: Bool
    ) -> String

    /// Yes/no prompt with a documented default answer.
    func yesOrNoChoicePrompt(
        title: TerminalText?,
        question: TerminalText,
        defaultAnswer: Bool,
        description: TerminalText?
    ) -> Bool
}

/// Production `PromptProvider` that delegates to the global `noora` instance.
public struct NooraPromptProvider: PromptProvider {

    public init() {}

    public func singleChoicePrompt<T: CaseIterable & CustomStringConvertible & Equatable & Sendable>(
        title: TerminalText?,
        question: TerminalText,
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T where T.AllCases: Sendable {
        noora.singleChoicePrompt(
            title: title,
            question: question,
            description: description,
            filterMode: filterMode
        )
    }

    public func singleChoicePrompt<T: CustomStringConvertible & Equatable & Sendable>(
        title: TerminalText?,
        question: TerminalText,
        options: [T],
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T {
        noora.singleChoicePrompt(
            title: title,
            question: question,
            options: options,
            description: description,
            filterMode: filterMode
        )
    }

    public func textPrompt(
        title: TerminalText?,
        prompt: TerminalText,
        description: TerminalText?,
        collapseOnAnswer: Bool
    ) -> String {
        noora.textPrompt(
            title: title,
            prompt: prompt,
            description: description,
            collapseOnAnswer: collapseOnAnswer
        )
    }

    public func yesOrNoChoicePrompt(
        title: TerminalText?,
        question: TerminalText,
        defaultAnswer: Bool,
        description: TerminalText?
    ) -> Bool {
        noora.yesOrNoChoicePrompt(
            title: title,
            question: question,
            defaultAnswer: defaultAnswer,
            description: description
        )
    }
}

/// Task-local override hook for the prompt provider.
///
/// Production callsites use `Prompts.current.singleChoicePrompt(...)`. Tests inject a
/// `ScriptedPromptProvider` via `Prompts.$current.withValue(...)`.
public enum Prompts {
    @TaskLocal public static var current: any PromptProvider = NooraPromptProvider()
}
