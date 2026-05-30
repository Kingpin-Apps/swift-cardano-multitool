import Foundation
@preconcurrency import Noora
@testable import SwiftCardanoMultitool

/// Test-only `PromptProvider` that returns canned answers in the order they were queued.
///
/// Construct one with a sequence of answers per prompt method, install it via
/// `Prompts.$current.withValue(...) { ... }`, and the wizard under test will receive the
/// scripted responses instead of trying to read from a terminal.
///
/// Each method pops one answer from its queue. If a prompt is invoked more times than
/// answers were provided, the provider triggers a test failure via `fatalError` (caught
/// in the running test as an explicit "ran out of scripted answers" message).
public final class ScriptedPromptProvider: PromptProvider, @unchecked Sendable {

    private let lock = NSLock()

    private var caseIterableSingleChoiceAnswers: [String] = []
    private var optionsSingleChoiceAnswers: [String] = []
    private var textAnswers: [String] = []
    private var yesNoAnswers: [Bool] = []

    public private(set) var prompts: [String] = []

    public init(
        singleChoice: [String] = [],
        options: [String] = [],
        texts: [String] = [],
        yesOrNo: [Bool] = []
    ) {
        self.caseIterableSingleChoiceAnswers = singleChoice
        self.optionsSingleChoiceAnswers = options
        self.textAnswers = texts
        self.yesNoAnswers = yesOrNo
    }

    public func singleChoicePrompt<T>(
        title: TerminalText?,
        question: TerminalText,
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T where T: CaseIterable, T: CustomStringConvertible, T: Equatable, T: Sendable, T.AllCases: Sendable {
        let pick = lock.withLock { () -> String in
            prompts.append("singleChoice<\(T.self)>")
            precondition(
                !caseIterableSingleChoiceAnswers.isEmpty,
                "ScriptedPromptProvider: no more scripted singleChoice<\(T.self)> answers"
            )
            return caseIterableSingleChoiceAnswers.removeFirst()
        }
        for case_ in T.allCases {
            if String(describing: case_) == pick || case_.description == pick {
                return case_
            }
        }
        fatalError("ScriptedPromptProvider: '\(pick)' is not a case of \(T.self)")
    }

    public func singleChoicePrompt<T>(
        title: TerminalText?,
        question: TerminalText,
        options: [T],
        description: TerminalText?,
        filterMode: SingleChoicePromptFilterMode
    ) -> T where T: CustomStringConvertible, T: Equatable, T: Sendable {
        let pick = lock.withLock { () -> String in
            prompts.append("singleChoiceOptions(count=\(options.count))")
            precondition(
                !optionsSingleChoiceAnswers.isEmpty,
                "ScriptedPromptProvider: no more scripted options-singleChoice answers"
            )
            return optionsSingleChoiceAnswers.removeFirst()
        }
        for option in options where option.description == pick {
            return option
        }
        fatalError("ScriptedPromptProvider: '\(pick)' is not in options \(options.map(\.description))")
    }

    public func textPrompt(
        title: TerminalText?,
        prompt: TerminalText,
        description: TerminalText?,
        collapseOnAnswer: Bool
    ) -> String {
        lock.withLock {
            prompts.append("text")
            precondition(
                !textAnswers.isEmpty,
                "ScriptedPromptProvider: no more scripted text answers"
            )
            return textAnswers.removeFirst()
        }
    }

    public func yesOrNoChoicePrompt(
        title: TerminalText?,
        question: TerminalText,
        defaultAnswer: Bool,
        description: TerminalText?
    ) -> Bool {
        lock.withLock {
            prompts.append("yesOrNo")
            precondition(
                !yesNoAnswers.isEmpty,
                "ScriptedPromptProvider: no more scripted yes/no answers"
            )
            return yesNoAnswers.removeFirst()
        }
    }
}
