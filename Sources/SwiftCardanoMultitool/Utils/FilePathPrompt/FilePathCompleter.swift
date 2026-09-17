import Foundation

/// Lists directory entries for path completion. Abstracted so completion can be tested
/// without touching the real file system.
protocol DirectoryListing: Sendable {
    /// Entries of a directory, or nil when it can't be read.
    func entries(atPath path: String) -> [FilePathCompleter.Entry]?
    /// Whether a path exists and whether it is a directory.
    func itemKind(atPath path: String) -> FilePathCompleter.ItemKind
}

struct FileManagerDirectoryListing: DirectoryListing {
    func entries(atPath path: String) -> [FilePathCompleter.Entry]? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else { return nil }
        return names.map { name in
            let full = (path as NSString).appendingPathComponent(name)
            return FilePathCompleter.Entry(name: name, isDirectory: itemKind(atPath: full) == .directory)
        }
    }

    func itemKind(atPath path: String) -> FilePathCompleter.ItemKind {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return .missing }
        return isDirectory.boolValue ? .directory : .file
    }
}

/// Completes file system paths as they are typed: `~`, relative and absolute paths,
/// hidden entries only when the typed name starts with a dot, and directories always
/// offered so the user can move through them.
struct FilePathCompleter: Sendable {
    /// What the prompt accepts.
    enum Selection: Sendable {
        case files
        case directories
        case filesOrDirectories
    }

    enum ItemKind: Equatable, Sendable {
        case file
        case directory
        case missing
    }

    struct Entry: Equatable, Sendable {
        let name: String
        let isDirectory: Bool
    }

    /// A suggestion for the current input.
    struct Suggestion: Equatable, Sendable {
        let name: String
        let isDirectory: Bool
        /// The whole input after choosing this suggestion.
        let completion: String

        /// The name as listed, with a trailing slash for directories.
        var displayName: String { isDirectory ? "\(name)/" : name }
    }

    var selection: Selection = .files
    /// Which files to suggest (by file name). Directories are always suggested unless
    /// only directories are accepted. Nil suggests every file.
    var fileMatches: (@Sendable (String) -> Bool)? = nil
    /// Relative paths are resolved against this directory.
    var baseDirectory: String = FileManager.default.currentDirectoryPath
    var homeDirectory: String = NSHomeDirectory()
    var listing: any DirectoryListing = FileManagerDirectoryListing()

    // MARK: - Paths

    /// Split input into the directory part as typed (ending in `/`, or empty) and the
    /// partial name after it.
    static func split(_ input: String) -> (directory: String, partial: String) {
        if input == "~" {
            return ("~/", "")
        }
        guard let slash = input.lastIndex(of: "/") else {
            return ("", input)
        }
        return (String(input[...slash]), String(input[input.index(after: slash)...]))
    }

    /// Expand `~` and resolve a typed path against the base directory.
    func resolve(_ typed: String) -> String {
        var path = typed
        if path == "~" {
            path = homeDirectory
        } else if path.hasPrefix("~/") {
            path = (homeDirectory as NSString).appendingPathComponent(String(path.dropFirst(2)))
            if typed.hasSuffix("/") { path += "/" }
        }
        if !path.hasPrefix("/") {
            path = (baseDirectory as NSString).appendingPathComponent(path)
            if typed.hasSuffix("/") || typed.isEmpty { path += "/" }
        }
        return path
    }

    /// The path to return for typed input: `~` expanded, otherwise as typed.
    func expanded(_ typed: String) -> String {
        if typed == "~" { return homeDirectory }
        if typed.hasPrefix("~/") {
            return (homeDirectory as NSString).appendingPathComponent(String(typed.dropFirst(2)))
        }
        return typed
    }

    func itemKind(of typed: String) -> ItemKind {
        let resolved = resolve(typed)
        let trimmed = resolved.count > 1 && resolved.hasSuffix("/") ? String(resolved.dropLast()) : resolved
        return listing.itemKind(atPath: trimmed)
    }

    // MARK: - Suggestions

    func suggestions(for input: String) -> [Suggestion] {
        let (directory, partial) = Self.split(input)
        let listedDirectory = directory.isEmpty ? baseDirectory : resolve(directory)
        guard let entries = listing.entries(atPath: listedDirectory) else { return [] }

        let showHidden = partial.hasPrefix(".")
        let candidates = entries.filter { entry in
            if entry.name.hasPrefix(".") && !showHidden { return false }
            if entry.isDirectory { return true }
            switch selection {
                case .directories: return false
                case .files, .filesOrDirectories: return fileMatches?(entry.name) ?? true
            }
        }

        let lowered = partial.lowercased()
        var matches = candidates.filter { $0.name.lowercased().hasPrefix(lowered) }
        if matches.isEmpty, !lowered.isEmpty {
            // Fall back to names containing the text, so `payment` finds `alice.payment.vkey`.
            matches = candidates.filter { $0.name.lowercased().contains(lowered) }
        }

        var suggestions = matches
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .map { entry in
                Suggestion(
                    name: entry.name,
                    isDirectory: entry.isDirectory,
                    completion: directory + entry.name + (entry.isDirectory ? "/" : "")
                )
            }

        if partial == ".." || (partial == "." && suggestions.isEmpty) {
            suggestions.insert(Suggestion(name: "..", isDirectory: true, completion: directory + "../"), at: 0)
        }
        return suggestions
    }

    /// The input extended as far as all suggestions agree, like shell tab completion.
    /// Nil when that adds nothing to the input.
    func commonCompletion(for input: String, suggestions: [Suggestion]) -> String? {
        let (directory, partial) = Self.split(input)
        let prefixed = suggestions.filter { $0.name.lowercased().hasPrefix(partial.lowercased()) }
        guard let first = prefixed.first else { return nil }
        if prefixed.count == 1 {
            return first.completion == input ? nil : first.completion
        }

        var common = first.name
        for suggestion in prefixed.dropFirst() {
            common = String(zip(common, suggestion.name)
                .prefix { $0.lowercased() == $1.lowercased() }
                .map { $0.0 })
        }
        guard common.count > partial.count else { return nil }
        return directory + common
    }
}
