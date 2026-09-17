import Foundation
import Noora
import SwiftCardanoCore
import SwiftCardanoTxValidator
import CBORCodable

// MARK: - Decoded tree

/// A readable, JSON-serializable view of a decoded object.
indirect enum DecodedValue: Equatable, Sendable {
    case string(String)
    case number(String)
    case bool(Bool)
    case null
    case object(DecodedObject)
    case array([DecodedValue])

    static func number<T: BinaryInteger>(_ value: T) -> DecodedValue { .number(String(value)) }
}

struct DecodedEntry: Equatable, Sendable {
    let label: String
    let key: String
    let value: DecodedValue
}

/// Ordered label/value pairs; JSON keys are derived from the labels.
struct DecodedObject: Equatable, Sendable {
    private(set) var entries: [DecodedEntry] = []

    init() {}

    mutating func add(_ label: String, _ value: DecodedValue?, key: String? = nil) {
        guard let value else { return }
        entries.append(DecodedEntry(label: label, key: key ?? Self.jsonKey(label), value: value))
    }

    mutating func add(_ label: String, _ text: String?, key: String? = nil) {
        add(label, text.map(DecodedValue.string), key: key)
    }

    mutating func add(_ label: String, _ object: DecodedObject, key: String? = nil) {
        add(label, .object(object), key: key)
    }

    mutating func append(contentsOf other: DecodedObject) {
        entries.append(contentsOf: other.entries)
    }

    subscript(key: String) -> DecodedValue? {
        entries.first { $0.key == key }?.value
    }

    /// `"CIP-129 DRep ID"` → `"cip129DrepId"`
    static func jsonKey(_ label: String) -> String {
        let words = label
            .split { !$0.isLetter && !$0.isNumber }
            .map { $0.lowercased() }
        guard let first = words.first else { return label }
        return first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}

/// The readable view of one file.
struct TextView: Sendable {
    var title: String
    var type: String
    var description: String
    var decoded: DecodedObject
    var notes: [String] = []
    var cborHex: String? = nil
    var cborDiagnostic: String? = nil

    // MARK: JSON

    func json() -> String {
        var root = DecodedObject()
        root.add("Title", title)
        root.add("Type", type)
        root.add("Description", description)
        root.add("Decoded", decoded)
        if !notes.isEmpty {
            root.add("Notes", .array(notes.map(DecodedValue.string)))
        }
        root.add("CBOR Hex", cborHex, key: "cborHex")
        root.add("CBOR Diagnostic", cborDiagnostic, key: "cborDiagnostic")
        return TextViewFormat.json(.object(root), indent: 0)
    }

    // MARK: Terminal

    func text(colored: Bool) -> String {
        var lines: [String] = []
        func style(_ text: TerminalText) -> String {
            colored ? noora.format(text) : text.plain()
        }
        lines.append(style("\(.primary("━━━ \(title) ━━━"))"))
        lines.append("")
        var header = DecodedObject()
        header.add("Type", type)
        header.add("Description", description.isEmpty ? nil : description)
        TextViewFormat.render(header, indent: 0, into: &lines, style: style)
        lines.append("")
        TextViewFormat.render(decoded, indent: 0, into: &lines, style: style)
        for note in notes {
            lines.append("")
            lines.append(style("\(.muted(note))"))
        }
        if let cborHex {
            lines.append("")
            lines.append(style("\(.primary("━━━ CBOR ━━━"))"))
            lines.append("")
            lines.append(cborHex)
        }
        if let cborDiagnostic {
            lines.append("")
            lines.append(style("\(.primary("━━━ CBOR Diagnostic ━━━"))"))
            lines.append("")
            lines.append(cborDiagnostic)
        }
        return lines.joined(separator: "\n")
    }
}

enum TextViewFormat {

    static func render(
        _ object: DecodedObject,
        indent: Int,
        into lines: inout [String],
        style: (TerminalText) -> String
    ) {
        let pad = String(repeating: " ", count: indent)
        let width = object.entries
            .filter { isScalar($0.value) }
            .map { $0.label.count }
            .max() ?? 0

        for entry in object.entries {
            switch entry.value {
                case .object(let child):
                    lines.append(pad + entry.label + ":")
                    if child.entries.isEmpty {
                        lines.append(pad + "  " + style("\(.muted("None"))"))
                    } else {
                        render(child, indent: indent + 2, into: &lines, style: style)
                    }
                case .array(let items):
                    lines.append(pad + entry.label + ":" + (items.isEmpty ? " " + style("\(.muted("None"))") : ""))
                    renderItems(items, indent: indent + 2, into: &lines, style: style)
                default:
                    let label = (entry.label + ":").padding(toLength: width + 2, withPad: " ", startingAt: 0)
                    lines.append(pad + label + scalarText(entry.value, style: style))
            }
        }
    }

    private static func renderItems(
        _ items: [DecodedValue],
        indent: Int,
        into lines: inout [String],
        style: (TerminalText) -> String
    ) {
        let pad = String(repeating: " ", count: indent)
        for (index, item) in items.enumerated() {
            switch item {
                case .object(let child):
                    lines.append(pad + style("\(.muted("[\(index + 1)]"))"))
                    render(child, indent: indent + 2, into: &lines, style: style)
                case .array(let nested):
                    lines.append(pad + style("\(.muted("[\(index + 1)]"))"))
                    renderItems(nested, indent: indent + 2, into: &lines, style: style)
                default:
                    lines.append(pad + "- " + scalarText(item, style: style))
            }
        }
    }

    private static func isScalar(_ value: DecodedValue) -> Bool {
        switch value {
            case .object, .array: return false
            default: return true
        }
    }

    private static func scalarText(_ value: DecodedValue, style: (TerminalText) -> String) -> String {
        switch value {
            case .string(let text): return style("\(.primary(text))")
            case .number(let text): return style("\(.primary(text))")
            case .bool(let flag): return style("\(.primary(flag ? "Yes" : "No"))")
            case .null: return style("\(.muted("None"))")
            case .object, .array: return ""
        }
    }

    static func json(_ value: DecodedValue, indent: Int) -> String {
        let pad = String(repeating: "  ", count: indent + 1)
        let closing = String(repeating: "  ", count: indent)
        switch value {
            case .string(let text): return quoted(text)
            case .number(let text): return text
            case .bool(let flag): return flag ? "true" : "false"
            case .null: return "null"
            case .array(let items):
                guard !items.isEmpty else { return "[]" }
                let body = items.map { pad + json($0, indent: indent + 1) }.joined(separator: ",\n")
                return "[\n\(body)\n\(closing)]"
            case .object(let object):
                guard !object.entries.isEmpty else { return "{}" }
                let body = object.entries
                    .map { pad + quoted($0.key) + ": " + json($0.value, indent: indent + 1) }
                    .joined(separator: ",\n")
                return "{\n\(body)\n\(closing)}"
        }
    }

    private static func quoted(_ text: String) -> String {
        var escaped = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
                case "\"": escaped += "\\\""
                case "\\": escaped += "\\\\"
                case "\n": escaped += "\\n"
                case "\r": escaped += "\\r"
                case "\t": escaped += "\\t"
                case let s where s.value < 0x20: escaped += String(format: "\\u%04x", s.value)
                default: escaped.unicodeScalars.append(scalar)
            }
        }
        return escaped + "\""
    }

    // MARK: CBOR

    /// Indented CBOR diagnostic notation.
    static func diagnostic(_ cbor: CBOR, indent: Int = 0) -> String {
        let inline = cbor.diagnostic
        if inline.count + indent * 2 <= 80 { return inline }
        let pad = String(repeating: "  ", count: indent + 1)
        let closing = String(repeating: "  ", count: indent)
        switch cbor {
            case .array(let items), .indefiniteArray(let items):
                let open = { if case .indefiniteArray = cbor { return "[_ " } else { return "[" } }()
                let body = items.map { pad + diagnostic($0, indent: indent + 1) }.joined(separator: ",\n")
                return "\(open)\n\(body)\n\(closing)]"
            case .map(let map), .indefiniteMap(let map):
                let open = { if case .indefiniteMap = cbor { return "{_ " } else { return "{" } }()
                let body = map.map { key, value in
                    pad + diagnostic(key, indent: indent + 1) + ": " + diagnostic(value, indent: indent + 1)
                }.joined(separator: ",\n")
                return "\(open)\n\(body)\n\(closing)}"
            case .tagged(let tag, let inner):
                return "\(tag)(\(diagnostic(inner, indent: indent)))"
            default:
                return inline
        }
    }

    /// A generic readable tree for CBOR without a dedicated decoder.
    static func decoded(_ cbor: CBOR) -> DecodedValue {
        switch cbor {
            case .unsignedInt(let value): return .number(value)
            case .negativeInt(let value): return .number("-\(UInt64(value) &+ 1)")
            case .byteString(let data): return .string("h'\(data.toHex)'")
            case .textString(let text): return .string(text)
            case .array(let items), .indefiniteArray(let items): return .array(items.map(decoded))
            case .map(let map), .indefiniteMap(let map):
                var object = DecodedObject()
                for (key, value) in map {
                    let label = { if case .textString(let text) = key { return text } else { return key.diagnostic } }()
                    object.add(label, decoded(value), key: label)
                }
                return .object(object)
            case .tagged(let tag, let inner):
                var object = DecodedObject()
                object.add("Tag", .number(tag))
                object.add("Value", decoded(inner))
                return .object(object)
            case .boolean(let flag): return .bool(flag)
            case .null, .undefined: return .null
            default: return .string(cbor.diagnostic)
        }
    }
}
