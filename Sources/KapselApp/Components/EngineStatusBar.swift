import SwiftUI

/// Native sidebar footer showing engine status and controls
struct EngineStatusBar: View {
    let statusText: String
    let statusSubtitle: String
    let statusColor: Color
    let engineRunning: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .foregroundStyle(statusColor)
                .font(.caption2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(statusText))
                    .font(.caption)
                Text(LocalizedStringKey(statusSubtitle))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(action: onToggle) {
                    Image(systemName: engineRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.borderless)
                .help(engineRunning ? "Stop Engine" : "Start Engine")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .disabled(isDisabled && !isLoading)
    }
}
