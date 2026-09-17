import Foundation
import Noora
import SystemPackage

/// Decodes terminal input bytes into prompt keys: UTF-8 characters, control keys and
/// the escape sequences for arrows and Shift+Tab.
struct FilePathKeyDecoder {
    /// Reads the next byte, blocking until one is available.
    let readByte: () -> UInt8?
    /// Reads a byte only if one is already waiting (the rest of an escape sequence).
    let readPendingByte: () -> UInt8?

    func nextKey() -> FilePathKey? {
        while let byte = readByte() {
            if let key = decode(byte) {
                return key
            }
        }
        return nil
    }

    private func decode(_ byte: UInt8) -> FilePathKey? {
        switch byte {
            case 0x0A, 0x0D: return .enter
            case 0x09: return .tab
            case 0x08, 0x7F: return .backspace
            case 0x15: return .clear
            case 0x17: return .deleteComponent
            case 0x1B: return decodeEscape()
            case 0x20 ..< 0x7F: return .character(Character(UnicodeScalar(byte)))
            case 0xC0 ... 0xF7: return decodeUTF8(lead: byte)
            default: return nil
        }
    }

    private func decodeEscape() -> FilePathKey? {
        guard let first = readPendingByte() else { return .escape }
        guard first == UInt8(ascii: "[") || first == UInt8(ascii: "O"), let second = readPendingByte() else {
            return .escape
        }
        switch second {
            case UInt8(ascii: "A"): return .up
            case UInt8(ascii: "B"): return .down
            case UInt8(ascii: "C"): return .right
            case UInt8(ascii: "Z"): return .shiftTab
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                // Sequences such as ESC [ 3 ~ (delete): consume up to the terminator and ignore.
                while let next = readPendingByte(), next != UInt8(ascii: "~") {}
                return nil
            default: return nil
        }
    }

    private func decodeUTF8(lead: UInt8) -> FilePathKey? {
        let length = lead >= 0xF0 ? 4 : lead >= 0xE0 ? 3 : 2
        var bytes = [lead]
        for _ in 1 ..< length {
            guard let next = readByte() else { return nil }
            bytes.append(next)
        }
        guard let text = String(bytes: bytes, encoding: .utf8), let character = text.first else { return nil }
        return .character(character)
    }
}

/// An interactive file path prompt with completion, in the style of the Noora prompts.
///
/// Type a path and matching entries are listed below it. Tab completes as far as the
/// matches agree and then cycles through them; ↑/↓ highlight a suggestion; Enter
/// chooses it (opening directories) or accepts the typed path.
struct FilePathPrompt {
    let title: TerminalText?
    let question: TerminalText
    let description: TerminalText?
    var state: FilePathPromptState
    /// Suggestions shown at once; the list scrolls with the highlight.
    var maxVisibleSuggestions = 8

    private let terminal = Terminal()
    private let renderer = Renderer()
    private let pipeline = StandardOutputPipeline()

    init(title: TerminalText?, question: TerminalText, description: TerminalText?, state: FilePathPromptState) {
        self.title = title
        self.question = question
        self.description = description
        self.state = state
    }

    mutating func run() throws -> String {
        guard terminal.isInteractive else {
            throw SwiftCardanoMultitoolError.valueError("'\(question.plain())' can't be prompted in a non-interactive session.")
        }

        var result: String? = nil
        // Read with read(2) rather than stdio: getchar buffers ahead, which would hide the rest
        // of an escape sequence from poll.
        func readByte(timeoutMilliseconds: Int32?) -> UInt8? {
            if let timeoutMilliseconds {
                var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
                guard poll(&descriptor, 1, timeoutMilliseconds) > 0 else { return nil }
            }
            var byte: UInt8 = 0
            return read(STDIN_FILENO, &byte, 1) == 1 ? byte : nil
        }
        let decoder = FilePathKeyDecoder(
            readByte: { readByte(timeoutMilliseconds: nil) },
            // Escape sequences arrive together; allow a moment for the rest of one.
            readPendingByte: { readByte(timeoutMilliseconds: 25) }
        )

        var state = self.state
        terminal.withoutCursor {
            terminal.inRawMode {
                render(state)
                while let key = decoder.nextKey() {
                    if case .submit(let path) = state.handle(key) {
                        result = path
                        break
                    }
                    render(state)
                }
            }
        }
        self.state = state

        guard let result else {
            throw SwiftCardanoMultitoolError.valueError("Input ended before a path was chosen.")
        }
        renderResult(result)
        return result
    }

    // MARK: - Rendering

    private func style(_ text: TerminalText) -> String {
        noora.format(text)
    }

    private var width: Int {
        max(20, (terminal.size()?.columns ?? 80) - 1)
    }

    /// Fit plain text to the terminal width so lines never wrap (the renderer redraws by line count).
    private func fit(_ text: String, indent: Int, keepEnd: Bool = false) -> String {
        let available = max(8, width - indent)
        guard text.count > available else { return text }
        return keepEnd ? "…" + String(text.suffix(available - 1)) : String(text.prefix(available - 1)) + "…"
    }

    private func render(_ state: FilePathPromptState) {
        let offset = title != nil ? "  " : ""
        var lines: [String] = []

        if let title {
            lines.append(style("\(.primary("◉ \(fit(title.plain(), indent: 2))"))"))
        }
        let questionText = fit(question.plain(), indent: offset.count)
        let input = fit(state.input, indent: offset.count + 1, keepEnd: true)
        lines.append(offset + style("\(.raw(questionText))"))
        lines.append(offset + style("\(.muted("›")) \(.secondary(input))") + "█")

        if state.input.isEmpty, let defaultValue = state.defaultValue {
            lines.append(offset + style("\(.muted(fit("Press Enter to use \(defaultValue)", indent: offset.count)))"))
        }

        if state.showSuggestions {
            let suggestions = state.suggestions
            if suggestions.isEmpty {
                lines.append(offset + style("\(.muted("  No matches"))"))
            } else {
                let rows = visibleRows(count: suggestions.count, selected: state.selectedIndex)
                if rows.lowerBound > 0 {
                    lines.append(offset + style("\(.muted("  ↑ \(rows.lowerBound) more"))"))
                }
                for index in rows {
                    let suggestion = suggestions[index]
                    let name = fit(suggestion.displayName, indent: offset.count + 4)
                    if index == state.selectedIndex {
                        lines.append(offset + style("\(.primary("❯ \(name)"))"))
                    } else if suggestion.isDirectory {
                        lines.append(offset + "  " + style("\(.accent(name))"))
                    } else {
                        lines.append(offset + "  " + name)
                    }
                }
                if rows.upperBound < suggestions.count {
                    lines.append(offset + style("\(.muted("  ↓ \(suggestions.count - rows.upperBound) more"))"))
                }
            }
        }

        if !state.errors.isEmpty {
            lines.append(offset + style("\(.danger("Validation errors:"))"))
            for error in state.errors {
                lines.append(offset + style("\(.danger(fit("· \(error)", indent: offset.count)))"))
            }
        }

        if let description {
            lines.append(offset + style("\(.muted(fit(description.plain(), indent: offset.count)))"))
        }
        lines.append(offset + style("\(.muted(fit("tab complete • ↑/↓ select • enter choose/open • ctrl+w up a folder • esc hide", indent: offset.count)))"))

        renderer.render(lines.joined(separator: "\n"), standardPipeline: pipeline)
    }

    private func visibleRows(count: Int, selected: Int?) -> Range<Int> {
        let rowsAvailable = (terminal.size()?.rows ?? 24) - 8
        let rows = max(3, min(maxVisibleSuggestions, rowsAvailable))
        guard count > rows else { return 0 ..< count }
        let anchor = selected ?? 0
        var start = max(0, anchor - rows / 2)
        start = min(start, count - rows)
        return start ..< start + rows
    }

    private func renderResult(_ path: String) {
        let label = (title ?? question).plain()
        renderer.render(
            style("\(.success("✔︎")) \(.primary("\(label):")) \(.raw(fit(path, indent: label.count + 4, keepEnd: true)))"),
            standardPipeline: pipeline
        )
    }
}

/// Prompt for a file or directory path with completion.
/// - Parameters:
///   - title: Prompt title.
///   - question: The question shown above the input.
///   - description: Optional muted help text.
///   - selection: Whether files, directories or both can be chosen.
///   - fileMatches: Which files to suggest; any file can still be typed.
///   - defaultValue: Used when Enter is pressed on empty input.
///   - mustExist: Require the path to exist.
///   - validationRules: Extra checks on the chosen path.
/// - Returns: The chosen path, with `~` expanded.
func filePathPrompt(
    title: TerminalText?,
    question: TerminalText,
    description: TerminalText? = nil,
    selection: FilePathCompleter.Selection = .files,
    fileMatches: (@Sendable (String) -> Bool)? = nil,
    defaultValue: String? = nil,
    mustExist: Bool = true,
    validationRules: [ValidatableRule] = []
) throws -> FilePath {
    let completer = FilePathCompleter(selection: selection, fileMatches: fileMatches)
    let state = FilePathPromptState(
        completer: completer,
        defaultValue: defaultValue,
        mustExist: mustExist,
        validate: { path in
            validationRules.filter { !$0.validate(input: path) }.map { $0.error.message }
        }
    )
    var prompt = FilePathPrompt(title: title, question: question, description: description, state: state)
    return FilePath(try prompt.run())
}
