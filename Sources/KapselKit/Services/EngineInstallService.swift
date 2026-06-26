import Foundation

/// Errors that can occur while installing the container engine
public enum EngineInstallError: LocalizedError, Sendable {
    case homebrewNotFound
    case downloadURLNotFound
    case downloadFailed(details: String)
    case installFailed(details: String)
    case cliNotFoundAfterInstall

    public var errorDescription: String? {
        switch self {
        case .homebrewNotFound:
            return "Homebrew was not found on this Mac."
        case .downloadURLNotFound:
            return "Could not find a signed installer package in the latest release."
        case .downloadFailed(let details):
            return "Failed to download installer: \(details)"
        case .installFailed(let details):
            return "Installation failed: \(details)"
        case .cliNotFoundAfterInstall:
            return "Installation finished, but the container CLI was not detected yet."
        }
    }
}

/// Result of checking whether the container CLI is present on this Mac
public enum EngineInstallStatus: Sendable, Equatable {
    case checking
    case installed(cliPath: String)
    case notInstalled
}

/// Handles discovery and guided installation of the apple/container CLI
public final class EngineInstallService: Sendable {
    public static let shared = EngineInstallService()

    /// Common install locations checked in priority order
    public static let candidateCLIPaths = [
        "/usr/local/bin/container",
        "/opt/homebrew/bin/container",
        "/usr/bin/container"
    ]

    private static let homebrewPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/apple/container/releases/latest")!

    private init() {}

    /// Returns the first discovered container CLI path, if any
    public func findInstalledCLIPath() -> String? {
        for path in Self.candidateCLIPaths where FileManager.default.fileExists(atPath: path) {
            return path
        }

        if let whichPath = Self.findCLIPathViaWhich() {
            return whichPath
        }

        return nil
    }

    /// Whether the container CLI binary exists on this Mac
    public func isCLIInstalled() -> Bool {
        findInstalledCLIPath() != nil
    }

    /// Performs a full detection pass and verifies the binary responds to `--version`
    public func detectEngine() async -> EngineInstallStatus {
        if let path = findInstalledCLIPath(), await verifyCLI(at: path) {
            CLIService.shared.cliPath = path
            return .installed(cliPath: path)
        }
        return .notInstalled
    }

    /// Whether `brew info --cask container` succeeds on this Mac
    public func isContainerCaskAvailable() async -> Bool {
        guard let brewPath = homebrewPath() else { return false }

        do {
            let exitCode = try await runCommand(
                launchPath: brewPath,
                arguments: ["info", "--cask", "container"],
                onOutput: { _ in }
            )
            return exitCode == 0
        } catch {
            return false
        }
    }

    /// Verifies that the binary is a working container CLI
    public func verifyCLI(at path: String) async -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }

        do {
            let exitCode = try await runCommand(
                launchPath: path,
                arguments: ["--version"],
                onOutput: { _ in }
            )
            return exitCode == 0
        } catch {
            return false
        }
    }

    /// Detects an installed CLI and stores its path in `CLIService`
    @discardableResult
    public func autoConfigureCLIPath() -> String? {
        guard let path = findInstalledCLIPath() else { return nil }
        CLIService.shared.cliPath = path
        return path
    }

    /// Whether Homebrew is available for one-click installation
    public func isHomebrewAvailable() -> Bool {
        homebrewPath() != nil
    }

    /// Returns the Homebrew executable path, if installed
    public func homebrewPath() -> String? {
        Self.homebrewPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Installs via Homebrew when available, otherwise downloads the signed pkg installer
    public func installRecommended(
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws {
        if let brewPath = homebrewPath(), await isContainerCaskAvailable() {
            try await installViaHomebrew(brewPath: brewPath, onProgress: onProgress)
        } else {
            onProgress("Downloading official installer...")
            let pkgURL = try await downloadLatestInstaller(onProgress: onProgress)
            try await openInstaller(at: pkgURL, onProgress: onProgress)
        }
    }

    /// Installs the container engine using `brew install --cask container`
    public func installViaHomebrew(
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let brewPath = homebrewPath() else {
            throw EngineInstallError.homebrewNotFound
        }
        guard await isContainerCaskAvailable() else {
            throw EngineInstallError.installFailed(details: "The container cask is not available in Homebrew.")
        }
        try await installViaHomebrew(brewPath: brewPath, onProgress: onProgress)
    }

    /// Downloads the latest signed installer package from GitHub releases
    @discardableResult
    public func downloadLatestInstaller(
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        onProgress("Fetching latest release information...")

        let (releaseData, response) = try await URLSession.shared.data(from: Self.latestReleaseAPI)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EngineInstallError.downloadFailed(details: "GitHub API request failed.")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: releaseData)

        guard let asset = release.assets.first(where: { $0.name.contains("installer-signed.pkg") }) else {
            throw EngineInstallError.downloadURLNotFound
        }

        onProgress("Downloading \(asset.name)...")

        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let destinationURL = downloadsDirectory.appendingPathComponent(asset.name)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        let (tempURL, downloadResponse) = try await URLSession.shared.download(from: asset.browserDownloadUrl)
        guard let downloadHTTP = downloadResponse as? HTTPURLResponse, downloadHTTP.statusCode == 200 else {
            throw EngineInstallError.downloadFailed(details: "Download request failed.")
        }

        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        onProgress("Downloaded to \(destinationURL.path)")
        return destinationURL
    }

    /// Opens a downloaded `.pkg` installer with the system installer UI
    public func openInstaller(
        at pkgURL: URL,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws {
        onProgress("Opening installer...")
        let exitCode = try await runCommand(
            launchPath: "/usr/bin/open",
            arguments: [pkgURL.path],
            onOutput: onProgress
        )
        guard exitCode == 0 else {
            throw EngineInstallError.installFailed(details: "Could not open installer package.")
        }
    }

    /// Polls for a newly installed CLI for up to the given timeout
    public func waitForCLIInstallation(
        timeout: TimeInterval = 90,
        onProgress: @escaping @Sendable (String) -> Void
    ) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let path = autoConfigureCLIPath() {
                return path
            }
            onProgress("Waiting for installation to complete...")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        return nil
    }

    private func installViaHomebrew(
        brewPath: String,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws {
        onProgress("Installing container via Homebrew...")
        var environment = ProcessInfo.processInfo.environment
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"

        let exitCode = try await runCommand(
            launchPath: brewPath,
            arguments: ["install", "--cask", "container"],
            environment: environment,
            onOutput: onProgress
        )

        guard exitCode == 0 else {
            throw EngineInstallError.installFailed(details: "Homebrew exited with code \(exitCode).")
        }

        guard autoConfigureCLIPath() != nil else {
            throw EngineInstallError.cliNotFoundAfterInstall
        }
    }

    private static func findCLIPathViaWhich() -> String? {
        for launchPath in ["/usr/bin/which", "/bin/which"] {
            guard FileManager.default.fileExists(atPath: launchPath) else { continue }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = ["container"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                continue
            }

            guard process.terminationStatus == 0 else { continue }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }

    private func runCommand(
        launchPath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> Int32 {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: launchPath)
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    output
                        .split(whereSeparator: \.isNewline)
                        .map(String.init)
                        .filter { !$0.isEmpty }
                        .forEach(onOutput)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                    output
                        .split(whereSeparator: \.isNewline)
                        .map(String.init)
                        .filter { !$0.isEmpty }
                        .forEach(onOutput)
                }
            }

            do {
                try process.run()
            } catch {
                throw EngineInstallError.installFailed(details: error.localizedDescription)
            }

            process.waitUntilExit()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            return process.terminationStatus
        }.value
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [GitHubAsset]
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadUrl: URL
}
