import SwiftUI
import KapselKit

/// A badge view representing the container's execution status
struct StatusBadge: View {
    let status: Container.Status

    var body: some View {
        Label {
            Text(LocalizedStringKey(status.displayName))
        } icon: {
            Image(systemName: status == .running ? "circle.fill" : "circle")
        }
        .font(.caption)
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .running: .green
        case .stopped: .red
        case .paused: .orange
        case .created: .blue
        case .unknown: .secondary
        }
    }
}
