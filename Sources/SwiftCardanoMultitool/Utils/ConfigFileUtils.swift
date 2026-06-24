import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

/// A Cardano genesis era, used to locate the matching genesis file in the node
/// configuration.
enum GenesisEra: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible, Sendable {
    case byron
    case shelley
    case alonzo
    case conway

    var description: String { rawValue }

    /// The key used inside the node `config.json` that points at this era's
    /// genesis file (e.g. `ShelleyGenesisFile`).
    var nodeConfigKey: String {
        switch self {
            case .byron: return "ByronGenesisFile"
            case .shelley: return "ShelleyGenesisFile"
            case .alonzo: return "AlonzoGenesisFile"
            case .conway: return "ConwayGenesisFile"
        }
    }
}

/// Read a JSON file and pretty-print it, tolerating unknown or missing fields.
///
/// This intentionally avoids decoding into strict model types: the Cardano node
/// config and genesis formats change over time (fields are added and removed
/// between node releases), so a structural pretty-print keeps working where a
/// strict decode would throw.
func printJSONFile(at path: FilePath, label: TerminalText) throws {
    guard FileManager.default.fileExists(atPath: path.string) else {
        noora.error(
            .alert(
                "\(label) file not found.",
                takeaways: ["Expected a file at: \(.primary(path.string))"]
            )
        )
        throw ExitCode.failure
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: path.string))

    spacedPrint("\n\(label) \(.muted("(\(path.string))"))")

    guard let object = try? JSONSerialization.jsonObject(
        with: data,
        options: [.fragmentsAllowed]
    ) else {
        // Not valid JSON — show the raw contents rather than failing outright.
        noora.warning(
            .alert(
                "Could not parse the file as JSON.",
                takeaway: "Showing the raw file contents instead."
            )
        )
        print(String(data: data, encoding: .utf8) ?? "<non-text data>")
        return
    }

    let pretty = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    print(String(data: pretty, encoding: .utf8) ?? "")
    print("\n")
}

/// Resolve the node `config.json` path, preferring an explicit option and
/// falling back to the `config` field of the active config's `[cardano]` section.
func resolveNodeConfigPath(explicit: FilePath?, config: MultitoolConfig) throws -> FilePath {
    if let explicit { return explicit }
    if let path = config.cardano?.config { return path }

    noora.error(
        .alert(
            "No node config path is available.",
            takeaways: [
                "Pass one explicitly with \(.command("--path")).",
                "Or store one with \(.command("scm config node-config set <path>")).",
            ]
        )
    )
    throw ExitCode.failure
}

/// Resolve the topology file path, preferring an explicit option and falling back
/// to the `topology` field of the active config's `[cardano]` section.
func resolveTopologyPath(explicit: FilePath?, config: MultitoolConfig) throws -> FilePath {
    if let explicit { return explicit }
    if let path = config.cardano?.topology { return path }

    noora.error(
        .alert(
            "No topology path is available.",
            takeaways: [
                "Pass one explicitly with \(.command("--path")).",
                "Or store one with \(.command("scm config topology set <path>")).",
            ]
        )
    )
    throw ExitCode.failure
}

/// Resolve a genesis file path for `era`, either from an explicit option or by
/// reading the era's `*GenesisFile` entry out of the node config and resolving it
/// relative to the node config's own directory.
func resolveGenesisPath(
    era: GenesisEra,
    explicit: FilePath?,
    config: MultitoolConfig
) throws -> FilePath {
    if let explicit { return explicit }

    let nodeConfigPath = try resolveNodeConfigPath(explicit: nil, config: config)

    guard FileManager.default.fileExists(atPath: nodeConfigPath.string) else {
        noora.error(
            .alert(
                "Node config file not found, so the genesis path can't be resolved.",
                takeaways: [
                    "Expected the node config at: \(.primary(nodeConfigPath.string))",
                    "Pass the genesis file directly with \(.command("--path")).",
                ]
            )
        )
        throw ExitCode.failure
    }

    let data = try Data(contentsOf: URL(fileURLWithPath: nodeConfigPath.string))
    guard
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let relative = object[era.nodeConfigKey] as? String
    else {
        noora.error(
            .alert(
                "Could not find \(.primary(era.nodeConfigKey)) in the node config.",
                takeaways: [
                    "Pass the genesis file directly with \(.command("--path")).",
                ]
            )
        )
        throw ExitCode.failure
    }

    // Genesis files are usually referenced relative to the node config's folder.
    let baseDir = nodeConfigPath.removingLastComponent()
    return baseDir.pushing(FilePath(relative))
}

/// Load the active multitool config, apply `mutate` to its `[cardano]` section,
/// and write it back to the active config file (preserving its format by
/// extension).
func updateActiveCardanoConfig(_ mutate: (inout CardanoConfig) -> Void) async throws {
    var config = try await MultitoolConfig.load()

    guard var cardano = config.cardano else {
        noora.error(
            .alert(
                "The active config has no [cardano] section to update.",
                takeaways: [
                    "Add a [cardano] section, or run \(.command("scm config init")).",
                ]
            )
        )
        throw ExitCode.failure
    }

    mutate(&cardano)
    config.cardano = cardano

    guard let configPath = Environment.getFilePath(.config) else {
        noora.error(
            .alert(
                "Unable to find the active config path to save to.",
                takeaways: [
                    "Set the \(.primary(Environment.config.rawValue)) environment variable.",
                ]
            )
        )
        throw ExitCode.failure
    }

    try config.save(to: configPath, overwrite: true)
}

/// Warn (without failing) when a path being stored does not yet exist on disk.
func warnIfPathMissing(_ path: FilePath, label: String) {
    guard !FileManager.default.fileExists(atPath: path.string) else { return }
    noora.warning(
        .alert(
            "\(label) does not exist yet at \(.primary(path.string)).",
            takeaway: "The path was still saved; create the file before using it."
        )
    )
}
