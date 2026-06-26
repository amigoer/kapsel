import SwiftUI
import KapselKit

/// A badge view representing the container's execution status
struct StatusBadge: View {
    let status: Container.Status
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(LocalizedStringKey(status.displayName))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var color: Color {
        switch status {
        case .running:
            return .green
        case .stopped:
            return .red
        case .paused:
            return .orange
        case .created:
            return .blue
        case .unknown:
            return .secondary
        }
    }
}
