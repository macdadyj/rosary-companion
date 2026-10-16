#if os(iOS)
import RosaryCore
import SwiftUI

/// Tracking mode: the current mystery's meditation, kept on screen through the whole decade.
/// It never grows past `maxHeight`; a long meditation scrolls inside the panel instead of
/// pushing the prayer and the tracking controls away.
struct TrackingMeditationPanel: View {
    let mystery: Mystery
    /// From `SaintsLibrary.cards(for:on:)`: verified quotes, then the reflection prompt.
    let cards: [MeditationCard]
    let textSize: PrayerTextSize
    let isExpanded: Bool
    let maxHeight: CGFloat
    let onToggle: () -> Void
    var content: PrayerContent?

    @State private var index = 0

    var body: some View {
        Group {
            if isExpanded {
                ViewThatFits(in: .vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        details
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        ScrollView {
                            details
                        }
                        .scrollIndicators(.visible)
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .frame(maxHeight: maxHeight, alignment: .top)
            } else {
                header
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Label("Meditation", systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                Spacer(minLength: 8)
                Text(isExpanded ? "Hide" : "Show")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Meditation")
        .accessibilityValue(isExpanded ? "Shown" : "Hidden")
        .accessibilityHint(isExpanded ? "Hides the meditation" : "Shows the meditation while you pray")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            MysteryDetailsView(mystery: mystery, content: content)
                .font(.footnote)
            if cards.indices.contains(index) {
                MeditationCardView(card: cards[index], textStyle: textSize.meditationStyle, framed: false)
                    .id(index)
                    .transition(.opacity)
            } else {
                Text("No meditation for this mystery yet.")
                    .font(.prayer(textSize.meditationStyle))
                    .foregroundStyle(Theme.secondaryInk)
            }
            if cards.count > 1 {
                HStack {
                    Text("\(index + 1) of \(cards.count)")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .accessibilityLabel("Meditation \(index + 1) of \(cards.count)")
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { index = (index + 1) % cards.count }
                    } label: {
                        Label("Another meditation", systemImage: "arrow.right.circle")
                            .font(.subheadline.weight(.medium))
                            .frame(minHeight: 44)
                    }
                    .tint(Theme.gold)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
