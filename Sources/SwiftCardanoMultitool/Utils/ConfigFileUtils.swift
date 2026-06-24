import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

/// A configuration that `config show` / `config set` can operate on.
enum ConfigTarget: String, ExpressibleByArgument, CaseIterable, AlignedChoiceDescribable, Sendable {
    case config
    case node
    case genesis
    case topology

    var name: String {
        switch self {
            case .config: return "Configuration"
            case .node: return "Node Config"
            case .genesis: return "Genesis"
            case .topology: return "Topology"
        }
    }

    var details: String {
        switch self {
            case .config: return "The scm multitool configuration itself."
            case .node: return "The Cardano node configuration (config.json)."
            case .genesis: return "A genesis file (byron, shelley, alonzo, conway)."
            case .topology: return "The Cardano node topology file."
        }
    }

    /// Targets whose path can be set. Genesis is derived from the node config and
    /// therefore not independently settable.
    static var settableCases: [ConfigTarget] { [.config, .node, .topology] }
}

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

/// Pretty-print the whole multitool configuration as JSON.
func printMultitoolConfig(_ config: MultitoolConfig) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try noora.json(config, encoder: encoder)
    print("\n\n")
}

/// Resolve the node `config.json` path from the active config's `[cardano]` section.
func resolveNodeConfigPath(config: MultitoolConfig) throws -> FilePath {
    if let path = config.cardano?.config { return path }

    noora.error(
        .alert(
            "No node config path is set.",
            takeaways: [
                "Store one with \(.command("scm config set node --path <path>")).",
            ]
        )
    )
    throw ExitCode.failure
}

/// Resolve the topology file path from the active config's `[cardano]` section.
func resolveTopologyPath(config: MultitoolConfig) throws -> FilePath {
    if let path = config.cardano?.topology { return path }

    noora.error(
        .alert(
            "No topology path is set.",
            takeaways: [
                "Store one with \(.command("scm config set topology --path <path>")).",
            ]
        )
    )
    throw ExitCode.failure
}

/// Resolve a genesis file path for `era` by reading the era's `*GenesisFile`
/// entry out of the node config and resolving it relative to the node config's
/// own directory.
func resolveGenesisPath(era: GenesisEra, config: MultitoolConfig) throws -> FilePath {
    let nodeConfigPath = try resolveNodeConfigPath(config: config)

    guard FileManager.default.fileExists(atPath: nodeConfigPath.string) else {
        noora.error(
            .alert(
                "Node config file not found, so the genesis path can't be resolved.",
                takeaways: [
                    "Expected the node config at: \(.primary(nodeConfigPath.string))",
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
                    "Make sure the node config references the \(.primary(era.rawValue)) genesis file.",
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
