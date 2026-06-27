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
        HStack(alignment: .center, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(statusText))
                        .font(.callout)
                    Text(LocalizedStringKey(statusSubtitle))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } icon: {
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 0)

            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(action: onToggle) {
                        Label(
                            engineRunning ? "Stop Engine" : "Start Engine",
                            systemImage: engineRunning ? "stop.fill" : "play.fill"
                        )
                        .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.regular)
                    .help(engineRunning ? "Stop Engine" : "Start Engine")
                }
            }
            .frame(width: 28, height: 28)
        }
        .padding(.vertical, 4)
        .disabled(isDisabled && !isLoading)
        .accessibilityElement(children: .combine)
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
