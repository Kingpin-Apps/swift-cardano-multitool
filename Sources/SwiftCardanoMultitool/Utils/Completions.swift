import Foundation
import ArgumentParser

extension CompletionKind {
    /// Completes a name prefix such as `--name` or `--address-name` from the key files
    /// already on disk: `alice.payment.vkey` and `alice.stake.vkey` offer `alice`.
    ///
    /// The shell runs `scm` again for every Tab press, so this only lists one
    /// directory: no config, no prompts, no network.
    static var fileStems: CompletionKind {
        .custom { _, _, prefix in stemsOfFiles(matching: prefix) }
    }
}

/// The distinct stems (the part before the first `.`) of the files in the directory
/// `prefix` points into, each kept behind that directory as it was typed.
func stemsOfFiles(
    matching prefix: String,
    workingDirectory: String = ".",
    fileManager: FileManager = .default
) -> [String] {
    let typedDirectory: String
    if let slash = prefix.lastIndex(of: "/") {
        typedDirectory = String(prefix[...slash])
    } else {
        typedDirectory = ""
    }

    let expanded = (typedDirectory as NSString).expandingTildeInPath
    let lookup = expanded.hasPrefix("/") ? expanded : (workingDirectory as NSString).appendingPathComponent(expanded)
    guard let entries = try? fileManager.contentsOfDirectory(atPath: lookup) else { return [] }

    var stems = Set<String>()
    for entry in entries where !entry.hasPrefix(".") {
        guard let dot = entry.firstIndex(of: "."), dot != entry.startIndex else { continue }
        var isDirectory: ObjCBool = false
        let path = (lookup as NSString).appendingPathComponent(entry)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            continue
        }
        stems.insert(typedDirectory + entry[..<dot])
    }
    return stems.filter { $0.hasPrefix(prefix) }.sorted()
}
