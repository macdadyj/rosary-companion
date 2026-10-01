#if os(iOS)
import RosaryCore
import SwiftUI

struct BeadCounterView: View {
    let progress: BeadProgress
    /// Tracking mode counts are estimates.
    let isEstimate: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: progress.count > 5 ? 8 : 14) {
                ForEach(1...progress.count, id: \.self) { bead in
                    Circle()
                        .fill(fill(for: bead))
                        .overlay(Circle().strokeBorder(Theme.gold.opacity(bead == progress.current ? 1 : 0), lineWidth: 2))
                        .frame(width: size(for: bead), height: size(for: bead))
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 30)

            if let current = progress.current {
                Text("\(isEstimate ? "≈ " : "")\(current) of \(progress.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text((isEstimate ? "About " : "") + progress.accessibilityLabel))
    }

    private func fill(for bead: Int) -> Color {
        if bead <= progress.completed { return Theme.gold }
        if bead == progress.current { return Theme.gold.opacity(0.45) }
        return Theme.beadEmpty
    }

    private func size(for bead: Int) -> CGFloat {
        bead == progress.current ? 26 : 20
    }
}
#endif
