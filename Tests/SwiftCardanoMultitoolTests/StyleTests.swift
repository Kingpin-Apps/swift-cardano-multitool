import Testing
@preconcurrency import Noora
@testable import SwiftCardanoMultitool

@Suite("Style")
struct StyleTests {

    @Test("theme is defined (Noora theme fields are internal — smoke-check the constant exists)")
    func themeIsDefined() {
        _ = Style.theme
    }

    @Test("content sets non-empty titles for every alert variant")
    func contentAlertTitles() {
        let content = Style.content
        #expect(!content.errorAlertTitle.isEmpty)
        #expect(!content.warningAlertTitle.isEmpty)
        #expect(!content.successAlertTitle.isEmpty)
        #expect(!content.infoAlertTitle.isEmpty)
    }

    @Test("content yes/no prompt uses 'y' and 'n' shortcuts")
    func contentYesNoShortcuts() {
        let content = Style.content
        #expect(content.yesOrNoChoicePromptPositiveText.character == "y")
        #expect(content.yesOrNoChoicePromptNegativeText.character == "n")
        #expect(content.yesOrNoChoicePromptPositiveText.fullText == "Yes")
        #expect(content.yesOrNoChoicePromptNegativeText.fullText == "No")
    }

    @Test("content choice-prompt instruction strings are populated")
    func contentChoicePromptInstructions() {
        let content = Style.content
        #expect(!content.choicePromptInstructionWithoutFilter.isEmpty)
        #expect(!content.choicePromptInstructionWithFilter.isEmpty)
        #expect(!content.choicePromptInstructionIsFiltering.isEmpty)
    }
}
