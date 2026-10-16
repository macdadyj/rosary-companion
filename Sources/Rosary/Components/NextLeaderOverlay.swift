#if os(iOS)
import SwiftUI

/// Shown when a decade completes in family mode: whose turn it is, as big as the screen allows.
struct NextLeaderOverlay: View {
    let name: String
    let caption: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.gold)
                .accessibilityHidden(true)
            Text(name)
                .font(.system(size: 72, weight: .semibold, design: .serif))
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
            Text(caption)
                .font(.prayer(.title2))
                .foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Theme.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .chapelPanel()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(name) \(caption)"))
        .accessibilityAddTraits(.isHeader)
    }
}
#endif
