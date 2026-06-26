import SwiftUI
import KapselKit

/// Guided setup banner shown when the container CLI is missing
struct EngineSetupBanner: View {
    @Environment(AppLanguageManager.self) private var languageManager
    @Environment(EngineStatusModel.self) private var engineStatus

    var onInstalled: (() -> Void)? = nil

    @State private var isWorking = false
    @State private var progressLines: [String] = []
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("The apple/container CLI was not found on this Mac. Install it with one click, or download the official installer package.")
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "arrow.down.circle")
            }

            HStack(spacing: 10) {
                Button(action: installRecommended) {
                    if isWorking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Install Engine", systemImage: "bolt.fill")
                    }
                }
                .disabled(isWorking)

                if engineStatus.isHomebrewCaskAvailable {
                    Button(action: installViaHomebrew) {
                        Label("Install via Homebrew", systemImage: "terminal")
                    }
                    .disabled(isWorking)
                }

                Button(action: downloadInstaller) {
                    Label("Download Installer", systemImage: "arrow.down.circle")
                }
                .disabled(isWorking)

                Button(action: openReleasesPage) {
                    Label("View Releases", systemImage: "safari")
                }
                .disabled(isWorking)
            }

            if !progressLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(progressLines.suffix(4).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let statusMessage {
                HStack(spacing: 12) {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.green)

                    Button("Recheck Installation") {
                        recheckInstallation()
                    }
                    .font(.caption)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func installRecommended() {
        runInstallTask {
            try await EngineInstallService.shared.installRecommended(onProgress: progressHandler)
            await finishAfterExternalInstall()
        }
    }

    private func installViaHomebrew() {
        runInstallTask {
            try await EngineInstallService.shared.installViaHomebrew(onProgress: progressHandler)
            markInstalledSuccess()
        }
    }

    private func downloadInstaller() {
        runInstallTask {
            let pkgURL = try await EngineInstallService.shared.downloadLatestInstaller(onProgress: progressHandler)
            try await EngineInstallService.shared.openInstaller(at: pkgURL, onProgress: progressHandler)
            await finishAfterExternalInstall(showInstallerHint: true)
        }
    }

    private var progressHandler: @Sendable (String) -> Void {
        { line in
            Task { @MainActor in
                progressLines.append(line)
            }
        }
    }

    private func runInstallTask(_ operation: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        progressLines = []

        Task {
            do {
                try await operation()
            } catch {
                errorMessage = languageManager.localized("Installation failed: \(error.localizedDescription)")
            }
            isWorking = false
        }
    }

    private func recheckInstallation() {
        isWorking = true
        errorMessage = nil

        Task {
            await engineStatus.refresh()
            if engineStatus.isCLIInstalled {
                markInstalledSuccess()
            } else {
                errorMessage = languageManager.localized("Installation finished, but the container CLI was not detected yet.")
            }
            isWorking = false
        }
    }

    private func markInstalledSuccess() {
        statusMessage = languageManager.localized("Engine installed successfully.")
        Task {
            await engineStatus.refresh()
            onInstalled?()
        }
    }

    private func finishAfterExternalInstall(showInstallerHint: Bool = false) async {
        if showInstallerHint {
            await MainActor.run {
                statusMessage = languageManager.localized("Installer opened. Complete the setup, then click Recheck Installation.")
            }
        }

        if let _ = await EngineInstallService.shared.waitForCLIInstallation(onProgress: progressHandler) {
            await MainActor.run {
                statusMessage = languageManager.localized("Engine installed successfully.")
            }
            await engineStatus.refresh()
            await MainActor.run {
                onInstalled?()
            }
        } else if !showInstallerHint {
            await MainActor.run {
                errorMessage = languageManager.localized("Installation finished, but the container CLI was not detected yet.")
            }
        }
    }

    private func openReleasesPage() {
        if let url = URL(string: "https://github.com/apple/container/releases") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    Form {
        Section {
            EngineSetupBanner()
        }
    }
    .formStyle(.grouped)
    .environment(AppLanguageManager.shared)
    .environment(EngineStatusModel.shared)
}
