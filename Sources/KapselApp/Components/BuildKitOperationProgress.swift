import SwiftUI
import KapselKit

/// Active BuildKit / kernel setup phase shown while long-running CLI work is in progress.
enum BuildKitOperationPhase: Equatable {
    case startingBuilder
    case stoppingBuilder
    case installingKernel
    case startingBuilderAfterKernel
    case removingKernel

    var title: LocalizedStringKey {
        switch self {
        case .startingBuilder:
            "Starting BuildKit…"
        case .stoppingBuilder:
            "Stopping BuildKit…"
        case .installingKernel:
            "Installing recommended kernel…"
        case .startingBuilderAfterKernel:
            "Starting BuildKit…"
        case .removingKernel:
            "Removing kernel…"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .startingBuilder:
            "Connecting to the BuildKit builder service."
        case .stoppingBuilder:
            "Shutting down the BuildKit builder service."
        case .installingKernel:
            "Downloading and configuring the Linux kernel. This may take a few minutes — keep Kapsel open."
        case .startingBuilderAfterKernel:
            "Kernel installed. Launching the BuildKit builder."
        case .removingKernel:
            "Stopping BuildKit and deleting kernel files from disk."
        }
    }
}

/// Native in-form progress for long-running BuildKit setup operations.
struct BuildKitOperationProgress: View {
    let phase: BuildKitOperationPhase
    let installProgress: KernelInstallProgress?
    let logTail: String

    private var fraction: Double? {
        installProgress?.fractionCompleted
    }

    private var statusLine: String? {
        guard let installProgress else { return nil }
        if installProgress.stage == .downloading || installProgress.stage == .installing || installProgress.stage == .removing {
            return installProgress.detail
        }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let fraction {
                ProgressView(value: fraction) {
                    EmptyView()
                }
                .progressViewStyle(.linear)
                .frame(width: 160)
            } else {
                ProgressView()
                    .controlSize(.regular)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(phase.title)
                    .font(.callout)

                if let statusLine, !statusLine.isEmpty {
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(phase.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let fraction {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                if !logTail.isEmpty, logTail != statusLine {
                    Text(logTail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension String {
    /// Last few non-empty lines from streamed CLI output, for a compact live log.
    var buildKitLogTail: String {
        let lines = split(separator: "\n", omittingEmptySubsequences: true).suffix(4)
        return lines.map(String.init).joined(separator: "\n")
    }
}
