import Foundation

/// A key the file path prompt reacts to.
enum FilePathKey: Equatable, Sendable {
    case character(Character)
    case backspace
    /// Ctrl+W: delete the last path component.
    case deleteComponent
    /// Ctrl+U: clear the input.
    case clear
    case tab
    case shiftTab
    case up
    case down
    case right
    case escape
    case enter
}

/// The editing state of the file path prompt, separate from the terminal so key
/// handling can be tested.
struct FilePathPromptState {
    enum Outcome: Equatable {
        case `continue`
        case submit(String)
    }

    let completer: FilePathCompleter
    var defaultValue: String? = nil
    var mustExist = true
    /// Extra checks on the expanded path; returns error messages.
    var validate: (String) -> [String] = { _ in [] }

    private(set) var input: String
    private(set) var suggestions: [FilePathCompleter.Suggestion] = []
    /// Index into `suggestions` of the highlighted suggestion.
    private(set) var selectedIndex: Int? = nil
    private(set) var showSuggestions = true
    private(set) var errors: [String] = []

    init(
        completer: FilePathCompleter,
        input: String = "",
        defaultValue: String? = nil,
        mustExist: Bool = true,
        validate: @escaping (String) -> [String] = { _ in [] }
    ) {
        self.completer = completer
        self.input = input
        self.defaultValue = defaultValue
        self.mustExist = mustExist
        self.validate = validate
        refreshSuggestions()
    }

    var selectedSuggestion: FilePathCompleter.Suggestion? {
        selectedIndex.flatMap { suggestions.indices.contains($0) ? suggestions[$0] : nil }
    }

    mutating func handle(_ key: FilePathKey) -> Outcome {
        switch key {
            case .character(let character):
                setInput(input + String(character))
            case .backspace:
                if !input.isEmpty { setInput(String(input.dropLast())) }
            case .deleteComponent:
                setInput(Self.removingLastComponent(input))
            case .clear:
                setInput("")
            case .tab:
                complete(forward: true)
            case .shiftTab:
                complete(forward: false)
            case .down:
                moveSelection(by: 1)
            case .up:
                moveSelection(by: -1)
            case .right:
                if let selected = selectedSuggestion {
                    setInput(selected.completion)
                }
            case .escape:
                if selectedIndex != nil {
                    selectedIndex = nil
                } else {
                    showSuggestions.toggle()
                }
            case .enter:
                return submit()
        }
        return .continue
    }

    // MARK: - Editing

    private mutating func setInput(_ value: String) {
        input = value
        errors = []
        selectedIndex = nil
        showSuggestions = true
        refreshSuggestions()
    }

    private mutating func refreshSuggestions() {
        suggestions = completer.suggestions(for: input)
    }

    private mutating func moveSelection(by step: Int) {
        guard !suggestions.isEmpty else { return }
        showSuggestions = true
        if let current = selectedIndex {
            selectedIndex = (current + step + suggestions.count) % suggestions.count
        } else {
            selectedIndex = step > 0 ? 0 : suggestions.count - 1
        }
    }

    /// Tab completes as far as the matches agree; with nothing more in common it
    /// cycles through the suggestions, and applies the highlighted one first if any.
    private mutating func complete(forward: Bool) {
        if forward, selectedIndex == nil, let common = completer.commonCompletion(for: input, suggestions: suggestions) {
            setInput(common)
            // A single directory match opens straight away; keep its contents listed.
            return
        }
        moveSelection(by: forward ? 1 : -1)
    }

    private mutating func submit() -> Outcome {
        if let selected = selectedSuggestion {
            setInput(selected.completion)
            // Choosing a directory opens it; Enter again accepts it when directories are allowed.
            if selected.isDirectory {
                return .continue
            }
        }

        var typed = input.trimmingCharacters(in: .whitespaces)
        if typed.isEmpty, let defaultValue {
            typed = defaultValue
        }
        guard !typed.isEmpty else {
            errors = ["Enter a path."]
            return .continue
        }

        let kind = completer.itemKind(of: typed)
        switch (kind, completer.selection) {
            case (.directory, .files):
                // Enter on a directory opens it.
                setInput(typed.hasSuffix("/") ? typed : typed + "/")
                return .continue
            case (.file, .directories):
                errors = ["\(typed) is a file, not a directory."]
                return .continue
            case (.missing, _) where mustExist:
                errors = ["\(typed) does not exist."]
                return .continue
            default:
                break
        }

        var result = completer.expanded(typed)
        if result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        let validationErrors = validate(result)
        guard validationErrors.isEmpty else {
            errors = validationErrors
            return .continue
        }
        return .submit(result)
    }

    /// `keys/alice.vkey` → `keys/`, `keys/` → ``, `~/a/b/` → `~/a/`
    static func removingLastComponent(_ input: String) -> String {
        var trimmed = input
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let slash = trimmed.lastIndex(of: "/") else { return "" }
        return String(trimmed[...slash])
    }
}
