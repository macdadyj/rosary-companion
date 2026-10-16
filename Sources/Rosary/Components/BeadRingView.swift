#if os(iOS)
import RosaryCore
import SwiftUI
import UIKit

/// A glowing ring of beads. The current bead is larger and lit.
struct BeadRingView: View {
    let count: Int
    let completed: Int
    let current: Int?
    var caption: String?

    var body: some View {
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
            .frame(height: 230)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
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

struct SacredArtView: View {
    let work: SacredWork?
    let data: Data?
    var height: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let data, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Theme.raisedSurface
                        Text("†")
                            .font(.prayer(.largeTitle))
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1.5)
            )
            if let work {
                Text(work.creditLine)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(work?.creditLine ?? "Mystery artwork")
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
