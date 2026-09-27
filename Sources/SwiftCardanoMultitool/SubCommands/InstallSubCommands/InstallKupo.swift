import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension InstallMainCommand {
    struct Kupo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "kupo",
            abstract: "Install Kupo."
        )

        @Option(
            name: [.customShort("d"), .customLong("install-dir")],
            help: "Directory to install the binary into. Defaults to ~/.local/bin.",
            completion: .directory
        )
        var installDir: String?

        @Option(
            name: .shortAndLong,
            help: "Install method."
        )
        var method: InstallMethod?

        @Option(
            name: [.customShort("i"), .customLong("image")],
            help: "Container image to pull. If omitted, the official image is used."
        )
        var image: String?

        mutating func wizard() async throws {
            if method == nil {
                let selected: InstallMethod = noora.singleChoicePrompt(
                    title: "Install Method",
                    question: "How would you like to install Kupo?",
                    options: InstallMethod.available,
                    description: "Choose an installation method."
                )
                method = selected
            }

            if method == .binary && installDir == nil {
                let defaultDir = defaultInstallDirectory().path
                let useDefault = noora.yesOrNoChoicePrompt(
                    title: "Install Directory",
                    question: "Install to \(defaultDir)?",
                    defaultAnswer: true,
                    description: "Choose 'no' to specify a custom directory."
                )
                if !useDefault {
                    installDir = try filePathPrompt(
                        title: "Install Directory",
                        question: "Enter the full path to the install directory:",
                        selection: .directories,
                        mustExist: false
                    ).string
                }
            }

            let isContainerMethod = method == .docker || method == .appleContainer
            if isContainerMethod && image == nil {
                let defaultImage = "\(OfficialImage.kupo.rawValue):latest"
                let useDefault = noora.yesOrNoChoicePrompt(
                    title: "Container Image",
                    question: "Use default image (\(defaultImage))?",
                    defaultAnswer: true,
                    description: "Choose 'no' to specify a custom image."
                )
                if !useDefault {
                    image = noora.textPrompt(
                        title: "Container Image",
                        prompt: "Enter the full image name (e.g. \(defaultImage)):"
                    )
                }
            }
        }

        mutating func run() async throws {
            if method == nil {
                try await wizard()
            }

            guard let installMethod = method else {
                throw ExitCode.failure
            }

            switch installMethod {
                case .binary:
                    try await installBinaryRelease()
                case .docker:
                    let img = image ?? "\(OfficialImage.kupo.rawValue):latest"
                    try await pullImage(cli: "docker", image: img)
                case .appleContainer:
                    let img = image ?? "\(OfficialImage.kupo.rawValue):latest"
                    try await pullImage(cli: "container", image: img)
            }
        }

        private func installBinaryRelease() async throws {
            let installDirURL = installDir.map { URL(fileURLWithPath: $0) } ?? defaultInstallDirectory()

            let release = try await noora.progressStep(
                message: "Fetching latest Kupo release...",
                successMessage: "Found latest release.",
                errorMessage: "Failed to fetch release information.",
                showSpinner: true
            ) { _ in
                return try await fetchLatestRelease(owner: "CardanoSolutions", repo: "kupo")
            }

            guard let asset = findMatchingAsset(in: release) else {
                noora.error(.alert(
                    "No compatible binary found for your platform (\(CurrentPlatform.os)/\(CurrentPlatform.arch)).",
                    takeaways: [
                        "Check available assets at: https://github.com/CardanoSolutions/kupo/releases",
                        "You may need to build from source for your platform."
                    ]
                ))
                throw ExitCode.failure
            }

            spacedPrint("Found asset: \(.primary(asset.name)) from release \(.secondary(release.tagName))")

            let _ = try await noora.progressStep(
                message: "Downloading and installing Kupo \(release.tagName)...",
                successMessage: "Kupo \(release.tagName) installed to \(installDirURL.path)",
                errorMessage: "Failed to install Kupo.",
                showSpinner: true
            ) { _ in
                let assetURL = URL(string: asset.browserDownloadUrl)!
                let archivePath = try await downloadFile(from: assetURL)
                defer { try? FileManager.default.removeItem(at: archivePath) }
                try processDownloadedAsset(archivePath: archivePath, binaryName: "kupo", installDir: installDirURL)
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
