import SwiftUI

/// One line in the hover detail popover.
struct ResourceGaugeDetailLine: Identifiable {
    let id = UUID()
    let label: LocalizedStringKey
    let value: String
}

/// Circular dashboard-style resource gauge with hover popover details.
struct ResourceGaugeRing: View {
    let title: LocalizedStringKey
    let icon: String
    let value: Double
    var tint: Color = .accentColor
    var isActive: Bool = true
    var detailLines: [ResourceGaugeDetailLine] = []

    @State private var isHovered = false

    /// `accessoryCircularCapacity` has a fixed intrinsic size on macOS; scale to dashboard size.
    private let ringSize: CGFloat = 92
    private let gaugeScale: CGFloat = 1.55

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Gauge(value: value) {
                    Image(systemName: icon)
                        .foregroundStyle(isHovered ? tint : .secondary)
                } currentValueLabel: {
                    Text(percentageText)
                        .font(.caption.bold())
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(isActive ? tint : .secondary)
                .scaleEffect(gaugeScale)
            }
            .frame(width: ringSize, height: ringSize)
            .opacity(isActive ? 1 : 0.45)

            Text(title)
                .font(.callout)
                .foregroundStyle(isHovered ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .scaleEffect(isHovered ? 1.03 : 1)
        .animation(.snappy(duration: 0.18), value: isHovered)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isHovered, arrowEdge: .bottom) {
            ResourceGaugeDetailPopover(
                title: title,
                icon: icon,
                tint: tint,
                percentage: percentageText,
                lines: detailLines
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isHovered ? .isSelected : [])
    }

    private var percentageText: String {
        isActive ? "\(Int((value * 100).rounded()))%" : "—"
    }
}

/// Native popover content for resource gauge hover details.
private struct ResourceGaugeDetailPopover: View {
    let title: LocalizedStringKey
    let icon: String
    let tint: Color
    let percentage: String
    let lines: [ResourceGaugeDetailLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)

            Text(percentage)
                .font(.title2.bold())
                .monospacedDigit()

            if !lines.isEmpty {
                Divider()

                ForEach(lines) { line in
                    LabeledContent(line.label) {
                        Text(line.value)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 200)
    }
}
