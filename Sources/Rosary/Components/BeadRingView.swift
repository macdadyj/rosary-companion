#if os(iOS)
import RosaryCore
import SwiftUI

/// A glowing ring of beads. The current bead is larger and lit.
/// Tapping the ring is the only way the prayer screen moves ahead.
struct BeadRingView: View {
    let count: Int
    let completed: Int
    let current: Int?
    var caption: String?
    var diameter: CGFloat = 168
    let onAdvance: () -> Void

    var body: some View {
        Button(action: onAdvance) {
            ring
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(UITag.sessionBeads)
        .accessibilityLabel(accessibilityText)
    }

    private var ring: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: side / 2)
                let radius = side * 0.36
                ZStack {
                    Circle()
                        .stroke(Theme.gold.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                    Text("†")
                        .font(.prayer(.title2))
                        .foregroundStyle(Theme.gold)
                        .position(center)
                    ForEach(1...max(count, 1), id: \.self) { bead in
                        let angle = Angle.degrees(-90 + (360 / Double(max(count, 1))) * Double(bead - 1))
                        let point = CGPoint(
                            x: center.x + CGFloat(cos(angle.radians)) * radius,
                            y: center.y + CGFloat(sin(angle.radians)) * radius
                        )
                        beadMark(bead)
                            .position(point)
                    }
                }
                .frame(height: side)
            }
            .frame(height: diameter)
            if let current {
                Text("\(current) of \(count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.gold)
            } else if let caption {
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var accessibilityText: String {
        if let current { return "Bead \(current) of \(count)" }
        if completed >= count, count > 0 { return "All \(count) beads prayed" }
        return "\(count) beads"
    }

    private func beadMark(_ bead: Int) -> some View {
        let isCurrent = bead == current
        let done = bead <= completed
        return Circle()
            .fill(done ? Theme.gold : (isCurrent ? Theme.gold.opacity(0.55) : Theme.beadEmpty))
            .overlay(Circle().strokeBorder(Theme.gold, lineWidth: isCurrent ? 2 : 0))
            .frame(width: isCurrent ? 22 : 14, height: isCurrent ? 22 : 14)
            .shadow(color: isCurrent ? Theme.gold.opacity(0.95) : .clear, radius: isCurrent ? 12 : 0)
            .scaleEffect(isCurrent ? 1.2 : 1)
            .animation(.easeOut(duration: 0.25), value: isCurrent)
    }
}

/// Shown for the Creed and the closing prayers, which have no decade ring.
/// It is still the only control that moves the prayer forward.
struct OpeningBeadControl: View {
    let onAdvance: () -> Void

    var body: some View {
        Button(action: onAdvance) {
            VStack(spacing: 6) {
                HStack(spacing: 14) {
                    bead
                    Text("†")
                        .font(.prayer(.title))
                        .foregroundStyle(Theme.gold)
                    bead
                }
                Text("Tap the beads")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(UITag.sessionBeads)
        .accessibilityLabel("Rosary beads")
    }

    private var bead: some View {
        Circle()
            .fill(Theme.gold)
            .frame(width: 18, height: 18)
            .shadow(color: Theme.gold.opacity(0.8), radius: 6)
    }
}

struct SlotCard: View {
    let slot: ContentSlot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(slot.title, systemImage: "square.dashed")
                .font(.headline)
                .foregroundStyle(Theme.gold)
            Text("Not yet verified.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.burgundy)
            Text(slot.reason)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            Text(slot.id)
                .font(.caption2.monospaced())
                .foregroundStyle(Theme.secondaryInk)
        }
        .card()
        .accessibilityIdentifier("slot.\(slot.id)")
    }
}
#endif
