import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("PromptProvider")
struct PromptProviderTests {

    @Test("default Prompts.current is a NooraPromptProvider")
    func defaultIsNoora() {
        let current = Prompts.current
        #expect(current is NooraPromptProvider)
    }

    @Test("Prompts.$current override scopes to the closure body")
    func taskLocalOverride() {
        let scripted = ScriptedPromptProvider(texts: ["one"])
        Prompts.$current.withValue(scripted) {
            #expect(Prompts.current is ScriptedPromptProvider)
        }
        // Outside the closure, we revert to the default.
        #expect(Prompts.current is NooraPromptProvider)
    }

    @Test("ScriptedPromptProvider returns the next queued text")
    func scriptedTextReturnsNext() {
        let scripted = ScriptedPromptProvider(texts: ["alpha", "beta"])
        Prompts.$current.withValue(scripted) {
            let first = Prompts.current.textPrompt(
                title: nil,
                prompt: "?",
                description: nil,
                collapseOnAnswer: false
            )
            let second = Prompts.current.textPrompt(
                title: nil,
                prompt: "?",
                description: nil,
                collapseOnAnswer: false
            )
            #expect(first == "alpha")
            #expect(second == "beta")
        }
    }

    @Test("ScriptedPromptProvider returns the next yes/no answer")
    func scriptedYesNo() {
        let scripted = ScriptedPromptProvider(yesOrNo: [true, false])
        Prompts.$current.withValue(scripted) {
            let first = Prompts.current.yesOrNoChoicePrompt(
                title: nil,
                question: "go?",
                defaultAnswer: false,
                description: nil
            )
            let second = Prompts.current.yesOrNoChoicePrompt(
                title: nil,
                question: "again?",
                defaultAnswer: false,
                description: nil
            )
            #expect(first == true)
            #expect(second == false)
        }
    }

    @Test("ScriptedPromptProvider tracks invoked prompt kinds")
    func scriptedTracksPrompts() {
        let scripted = ScriptedPromptProvider(texts: ["x"], yesOrNo: [true])
        Prompts.$current.withValue(scripted) {
            _ = Prompts.current.textPrompt(title: nil, prompt: "?", description: nil, collapseOnAnswer: false)
            _ = Prompts.current.yesOrNoChoicePrompt(title: nil, question: "?", defaultAnswer: false, description: nil)
        }
        #expect(scripted.prompts == ["text", "yesOrNo"])
    }
}
