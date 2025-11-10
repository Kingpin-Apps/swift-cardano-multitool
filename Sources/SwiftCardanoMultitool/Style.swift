@preconcurrency import Noora

public struct Style: Sendable {
    public static let theme: Theme = Theme(
        primary: "A378F2",
        secondary: "A6CDFA",
        muted: "505050",
        accent: "AC6115",
        danger: "FF2929",
        success: "56822B",
        info: "0280B9",
        selectedRowText: "FFFFFF",
        selectedRowBackground: "4600AE"
    )
    
    public static let content: Content = Content(
        errorAlertTitle: "❗️ Error",
        errorAlertRecommendedTitle: "Sorry this didn’t work. Here’s what to try next",
        warningAlertTitle: "⚠️  Warning",
        warningAlertRecommendedTitle: "The following items may need attention",
        successAlertTitle: "✅  Success",
        successAlertRecommendedTitle: "Takeaways",
        infoAlertTitle: "🔎 Info",
        infoAlertRecommendedTitle: "Details",
        choicePromptFilterTitle: "Filter",
        choicePromptInstructionWithoutFilter: "↑/↓/k/j up/down • enter confirm",
        choicePromptInstructionWithFilter: "↑/↓/k/j up/down • / filter • enter confirm",
        choicePromptInstructionIsFiltering: "↑/↓ up/down • esc clear filter • enter confirm",
        multipleChoicePromptFilterTitle: "Filter",
        multipleChoicePromptErrorTitle: "Error",
        multipleChoicePromptInstructionWithoutFilter: "↑/↓/k/j up/down • [space] select • enter confirm",
        multipleChoicePromptInstructionWithFilter: "↑/↓/k/j up/down • [space] select • / filter • enter confirm",
        multipleChoicePromptInstructionIsFiltering: "↑/↓ up/down • [space] select • esc clear filter • enter confirm",
        textPromptValidationErrorsTitle: "Validation errors",
        yesOrNoChoicePromptInstruction: "←/→/h/l left/right • enter confirm",
        yesOrNoChoicePromptPositiveText: YesNoAnswerContent(fullText: "Yes", character: "y"),
        yesOrNoChoicePromptNegativeText: YesNoAnswerContent(fullText: "No", character: "n")
    )
}
