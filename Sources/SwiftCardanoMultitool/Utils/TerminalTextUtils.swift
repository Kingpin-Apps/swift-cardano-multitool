import Foundation
import Noora
import Path

/// A `.path`-styled terminal-text component that tolerates relative paths.
///
/// Noora's `.path` component requires an `AbsolutePath`, so the previous pattern
/// `\(pathComponent(somePath))` threw "invalid absolute path"
/// whenever it was handed a relative path — aborting the command (often *after*
/// the underlying file operation had already succeeded). This resolves a
/// relative path against the current working directory first, and falls back to
/// plain `.primary` styling if it still can't be made absolute, so it never
/// throws.
func pathComponent(_ pathString: String) -> TerminalText.Component {
    let absoluteString = pathString.hasPrefix("/")
        ? pathString
        : FileManager.default.currentDirectoryPath + "/" + pathString

    if let absolute = try? AbsolutePath(validating: absoluteString) {
        return .path(absolute)
    }
    return .primary(pathString)
}
