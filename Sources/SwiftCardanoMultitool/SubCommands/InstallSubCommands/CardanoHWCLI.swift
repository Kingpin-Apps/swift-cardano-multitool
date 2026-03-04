import Foundation
import ArgumentParser
import Noora
import SystemPackage

extension InstallMainCommand {
    struct CardanoHWCLI: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cardano-hw-cli",
            abstract: "Install cardano-hw-cli."
        )

        @Option(
            name: [.customShort("d"), .customLong("install-dir")],
            help: "Directory to install the binary into. Defaults to ~/.local/bin."
        )
        var installDir: String?

        @Option(
            name: .shortAndLong,
            help: "Install method: binary, docker, or apple-container."
        )
        var method: String?

        @Option(
            name: [.customShort("i"), .customLong("image")],
            help: "Container image to pull. Required when using docker or apple-container (no official image exists)."
        )
        var image: String?

        mutating func wizard() async throws {
            if method == nil {
                let selected: InstallMethod = noora.singleChoicePrompt(
                    title: "Install Method",
                    question: "How would you like to install cardano-hw-cli?",
                    options: InstallMethod.available,
                    description: "Choose an installation method."
                )
                method = selected.rawValue
            }

            if method == InstallMethod.binary.rawValue && installDir == nil {
                let defaultDir = defaultInstallDirectory().path
                let useDefault = noora.yesOrNoChoicePrompt(
                    title: "Install Directory",
                    question: "Install to \(defaultDir)?",
                    defaultAnswer: true,
                    description: "Choose 'no' to specify a custom directory."
                )
                if !useDefault {
                    installDir = noora.textPrompt(
                        title: "Install Directory",
                        prompt: "Enter the full path to the install directory:"
                    )
                }
            }

            let isContainerMethod = method == InstallMethod.docker.rawValue || method == InstallMethod.appleContainer.rawValue
            if isContainerMethod && image == nil {
                image = noora.textPrompt(
                    title: "Container Image",
                    prompt: "Enter the full image name (e.g. myregistry/cardano-hw-cli:latest):"
                )
            }
        }

        mutating func run() async throws {
            let isContainerMethod = method == InstallMethod.docker.rawValue || method == InstallMethod.appleContainer.rawValue
            if method == nil || (isContainerMethod && image == nil) {
                try await wizard()
            }

            guard let installMethod = method.flatMap({ InstallMethod(rawValue: $0) }) else {
                noora.error(.alert(
                    "Invalid install method: '\(method ?? "")'.",
                    takeaways: ["Valid options are: binary, docker, apple-container."]
                ))
                throw ExitCode.failure
            }

            switch installMethod {
                case .binary:
                    try await installBinaryRelease()
                case .docker:
                    guard let img = image, !img.isEmpty else {
                        noora.error(.alert(
                            "No container image specified for cardano-hw-cli.",
                            takeaways: ["Use --image to specify a Docker image (e.g. --image myregistry/cardano-hw-cli:latest)."]
                        ))
                        throw ExitCode.failure
                    }
                    try await pullImage(cli: "docker", image: img)
                case .appleContainer:
                    guard let img = image, !img.isEmpty else {
                        noora.error(.alert(
                            "No container image specified for cardano-hw-cli.",
                            takeaways: ["Use --image to specify an Apple Container image (e.g. --image myregistry/cardano-hw-cli:latest)."]
                        ))
                        throw ExitCode.failure
                    }
                    try await pullImage(cli: "container", image: img)
            }
        }

        private func installBinaryRelease() async throws {
            let installDirURL = installDir.map { URL(fileURLWithPath: $0) } ?? defaultInstallDirectory()

            let release = try await noora.progressStep(
                message: "Fetching latest cardano-hw-cli release...",
                successMessage: "Found latest release.",
                errorMessage: "Failed to fetch release information.",
                showSpinner: true
            ) { _ in
                return try await fetchLatestRelease(owner: "vacuumlabs", repo: "cardano-hw-cli")
            }

            guard let asset = findMatchingAsset(in: release) else {
                noora.error(.alert(
                    "No compatible binary found for your platform (\(CurrentPlatform.os)/\(CurrentPlatform.arch)).",
                    takeaways: [
                        "Check available assets at: https://github.com/vacuumlabs/cardano-hw-cli/releases",
                        "You may need to build from source for your platform."
                    ]
                ))
                throw ExitCode.failure
            }

            spacedPrint("Found asset: \(.primary(asset.name)) from release \(.secondary(release.tagName))")

            let _ = try await noora.progressStep(
                message: "Downloading and installing cardano-hw-cli \(release.tagName)...",
                successMessage: "cardano-hw-cli \(release.tagName) installed to \(installDirURL.path)",
                errorMessage: "Failed to install cardano-hw-cli.",
                showSpinner: true
            ) { _ in
                let assetURL = URL(string: asset.browserDownloadUrl)!
                let archivePath = try await downloadFile(from: assetURL)
                defer { try? FileManager.default.removeItem(at: archivePath) }
                try processDownloadedAsset(archivePath: archivePath, binaryName: "cardano-hw-cli", installDir: installDirURL)
                return installDirURL.path
            }

            warnIfNotInPath(installDirURL)
        }

        private func pullImage(cli: String, image: String) async throws {
            let _ = try await noora.progressStep(
                message: "Pulling image \(image)...",
                successMessage: "Successfully pulled \(image).",
                errorMessage: "Failed to pull image.",
                showSpinner: true
            ) { _ in
                try await pullContainerImage(cli: cli, image: image)
                return image
            }
        }
    }
}
