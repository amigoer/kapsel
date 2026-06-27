import SwiftUI
import KapselKit

/// Shared BuildKit + kernel controls with determinate progress and uninstall.
struct BuildKitKernelControls: View {
    let kernelInstalled: Bool
    let kernelVersion: String?
    let builderRunning: Bool
    let engineRunning: Bool
    let cliInstalled: Bool

    let operationPhase: BuildKitOperationPhase?
    let installProgress: KernelInstallProgress?
    let feedback: String?
    let feedbackIsError: Bool
    let needsKernel: Bool

    let onToggleBuilder: (Bool) -> Void
    let onInstallKernel: () -> Void
    let onUninstallKernel: () -> Void

    private var isBusy: Bool { operationPhase != nil }

    var body: some View {
        LabeledContent {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Toggle("", isOn: builderToggle)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!engineRunning || !cliInstalled || needsKernel)
            }
        } label: {
            Label("BuildKit Builder", systemImage: "hammer.fill")
        }

        if kernelInstalled {
            LabeledContent {
                if isBusy {
                    EmptyView()
                } else {
                    Button("Uninstall", role: .destructive) {
                        onUninstallKernel()
                    }
                    .disabled(!engineRunning || !cliInstalled || builderRunning)
                }
            } label: {
                Label {
                    HStack(spacing: 6) {
                        Text("Linux Kernel")
                        if let kernelVersion {
                            Text(kernelVersion)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "memorychip")
                }
            }
        }

        if let operationPhase {
            BuildKitOperationProgress(
                phase: operationPhase,
                installProgress: installProgress,
                logTail: installProgress?.detail ?? ""
            )
        } else if needsKernel {
            Text("BuildKit requires a Linux kernel for your Mac's architecture. Install the recommended kernel first.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onInstallKernel) {
                Label("Install Recommended Kernel", systemImage: "arrow.down.circle")
            }
            .disabled(!engineRunning || !cliInstalled)
        }

        if let feedback {
            Text(feedback)
                .font(.caption)
                .foregroundStyle(feedbackIsError ? .red : .green)
        }
    }

    private var builderToggle: Binding<Bool> {
        Binding(
            get: { builderRunning },
            set: { onToggleBuilder($0) }
        )
    }
}

/// Compact variant for the Services page section layout.
struct BuildKitKernelServiceSection: View {
    let kernelInstalled: Bool
    let kernelVersion: String?
    let builderRunning: Bool
    let engineRunning: Bool
    let operationPhase: BuildKitOperationPhase?
    let installProgress: KernelInstallProgress?
    let feedback: String?
    let feedbackIsError: Bool
    let needsKernel: Bool

    let onToggleBuilder: (Bool) -> Void
    let onInstallKernel: () -> Void
    let onUninstallKernel: () -> Void

    private var isBusy: Bool { operationPhase != nil }

    var body: some View {
        LabeledContent {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Toggle("", isOn: builderToggle)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!engineRunning || needsKernel && !kernelInstalled)
            }
        } label: {
            Label("BuildKit Builder", systemImage: "hammer.fill")
        }

        if kernelInstalled {
            LabeledContent("Linux Kernel") {
                Text(kernelVersion ?? "Installed")
            }

            if !isBusy {
                Button("Uninstall Kernel", role: .destructive) {
                    onUninstallKernel()
                }
                .disabled(!engineRunning || builderRunning)
            }
        }

        Text("Launch a dedicated BuildKit environment to compile OCI container images with high performance using local Dockerfiles.")

        if needsKernel, !kernelInstalled {
            Text("BuildKit requires a Linux kernel for your Mac's architecture. Install the recommended kernel first.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !isBusy {
                Button(action: onInstallKernel) {
                    Label("Install Recommended Kernel", systemImage: "arrow.down.circle")
                }
                .disabled(!engineRunning)
            }
        }

        if let operationPhase {
            BuildKitOperationProgress(
                phase: operationPhase,
                installProgress: installProgress,
                logTail: installProgress?.detail ?? ""
            )
        }

        if let feedback {
            Text(feedback)
                .font(.caption)
                .foregroundStyle(feedbackIsError ? .red : .green)
        }
    }

    private var builderToggle: Binding<Bool> {
        Binding(
            get: { builderRunning },
            set: { onToggleBuilder($0) }
        )
    }
}
