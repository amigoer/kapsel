import Foundation

/// Manages Linux kernel download, installation, and removal for the container runtime.
public final class KernelService: Sendable {
    public static let shared = KernelService()

    private let cli = CLIService.shared
    private let system = SystemService.shared

    public init() {}

    /// Reads kernel configuration and on-disk install state.
    public func getConfiguration() async throws -> KernelConfiguration {
        let status = try await system.getSystemStatus()
        let propertyList = try await system.getProperties()
        return KernelConfiguration.load(propertyList: propertyList, appRoot: status.appRoot)
    }

    /// Downloads the recommended archive with byte progress, then installs via the CLI.
    public func installRecommended(
        onProgress: (@Sendable (KernelInstallProgress) -> Void)? = nil
    ) async throws {
        onProgress?(KernelInstallProgress(stage: .preparing, detail: "Reading kernel configuration…"))

        let status = try await system.getSystemStatus()
        let propertyList = try await system.getProperties()
        let config = KernelConfiguration.load(propertyList: propertyList, appRoot: status.appRoot)

        if let sourceURL = config.sourceURL, let memberPath = config.archiveMemberPath {
            onProgress?(KernelInstallProgress(
                stage: .downloading,
                fractionCompleted: 0,
                detail: "Downloading kernel archive…"
            ))

            let archiveURL = try await downloadArchive(from: sourceURL) { fraction in
                let percent = Int((fraction * 100).rounded())
                onProgress?(KernelInstallProgress(
                    stage: .downloading,
                    fractionCompleted: fraction,
                    detail: "Downloading kernel archive… \(percent)%"
                ))
            }

            defer { try? FileManager.default.removeItem(at: archiveURL) }

            onProgress?(KernelInstallProgress(
                stage: .installing,
                fractionCompleted: nil,
                detail: "Extracting and installing kernel…"
            ))

            _ = try await cli.run(arguments: [
                "system", "kernel", "set",
                "--tar", archiveURL.path,
                "--binary", memberPath,
                "--force"
            ])
            return
        }

        onProgress?(KernelInstallProgress(
            stage: .installing,
            fractionCompleted: nil,
            detail: "Installing recommended kernel…"
        ))

        try await system.setRecommendedKernel { chunk in
            let tail = chunk.buildKitLogTail
            guard !tail.isEmpty else { return }
            onProgress?(KernelInstallProgress(stage: .installing, detail: tail))
        }
    }

    /// Stops BuildKit if needed and removes installed kernel files from the app data directory.
    public func removeInstalled(
        onProgress: (@Sendable (KernelInstallProgress) -> Void)? = nil
    ) async throws {
        onProgress?(KernelInstallProgress(stage: .removing, detail: "Stopping BuildKit builder…"))

        if await system.fetchBuilderRunning() {
            _ = try await cli.run(arguments: ["builder", "stop"])
        }

        let status = try await system.getSystemStatus()
        let kernelsDir = URL(fileURLWithPath: status.appRoot, isDirectory: true)
            .appendingPathComponent("kernels")

        onProgress?(KernelInstallProgress(stage: .removing, detail: "Removing kernel files…"))

        let fm = FileManager.default
        guard fm.fileExists(atPath: kernelsDir.path) else { return }

        let entries = (try? fm.contentsOfDirectory(at: kernelsDir, includingPropertiesForKeys: nil)) ?? []
        guard !entries.isEmpty else { return }

        for entry in entries {
            try fm.removeItem(at: entry)
        }
    }

    private func downloadArchive(
        from url: URL,
        onFraction: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            final class ProgressBox: @unchecked Sendable {
                var observation: NSKeyValueObservation?
            }

            let box = ProgressBox()
            let task = URLSession.shared.downloadTask(with: url) { tempURL, _, error in
                box.observation?.invalidate()
                box.observation = nil

                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: CLIError.invalidOutput)
                    return
                }

                do {
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("kapsel-kernel-\(UUID().uuidString)")
                        .appendingPathExtension(url.pathExtension.isEmpty ? "tar" : url.pathExtension)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            box.observation = task.progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
                onFraction(progress.fractionCompleted)
            }

            task.resume()
        }
    }
}

private extension String {
    var buildKitLogTail: String {
        split(separator: "\n", omittingEmptySubsequences: true).suffix(1).map(String.init).joined()
    }
}
