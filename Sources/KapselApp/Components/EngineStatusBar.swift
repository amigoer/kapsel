import SwiftUI

/// Native sidebar footer showing engine status and controls.
struct EngineStatusBar: View {
    let statusText: String
    let statusSubtitle: String
    let statusColor: Color
    let engineRunning: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(statusText))
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(LocalizedStringKey(statusSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: onToggle) {
                        Image(systemName: engineRunning ? "stop.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                    .help(engineRunning ? "Stop Engine" : "Start Engine")
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.vertical, 4)
        .disabled(isDisabled && !isLoading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(statusText)))
    }
}

#Preview {
    List {
        Section {
            EngineStatusBar(
                statusText: "Engine Running",
                statusSubtitle: "Container API is online",
                statusColor: .green,
                engineRunning: true,
                isLoading: false,
                isDisabled: false,
                onToggle: {}
            )
        }
    }
    .listStyle(.sidebar)
    .frame(width: 240, height: 120)
}
