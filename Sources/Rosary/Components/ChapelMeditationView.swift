#if os(iOS)
import RosaryCore
import SwiftUI

/// The mystery's painting beside the full Scripture passage.
struct ChapelMeditationView: View {
    let mystery: Mystery
    let content: PrayerContent?
    let library: SacredArtLibrary
    let day: CivilDate
    let textSize: PrayerTextSize
    let cards: [MeditationCard]
    var showsSaintCards: Bool
    var showsArt: Bool
    let onNewImage: () -> Void

    var body: some View {
        GeometryReader { geo in
            let artWidth = min(max(geo.size.width * 0.5, 156), geo.size.width * 0.58)
            HStack(alignment: .top, spacing: 12) {
                if showsArt {
                    artColumn(height: geo.size.height)
                        .frame(width: artWidth)
                }
                ScrollView {
                    textColumn
                        .padding(.trailing, 4)
                        .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(10)
        .chapelPanel()
    }

    private func artColumn(height: CGFloat) -> some View {
        let credit = library.creditLine(for: mystery.id, content: content, on: day)
        let imageHeight = max(height - 92, 140)
        return VStack(alignment: .leading, spacing: 6) {
            SacredArtView(
                data: library.imageData(for: mystery.id, content: content, on: day),
                credit: nil,
                height: imageHeight,
                sessionTag: UITag.sessionArt
            )
            Text(credit)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onNewImage) {
                Text("New image")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                    .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(UITag.sessionRefreshArt)
        }
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mystery.title)
                .font(.prayer(.headline, weight: .semibold))
                .foregroundStyle(Theme.gold)
            MysteryDetailsView(mystery: mystery, content: content, textStyle: textSize.meditationStyle)
            if showsSaintCards {
                if cards.isEmpty {
                    Text("No meditation for this mystery yet.")
                        .font(.prayer(textSize.meditationStyle))
                        .foregroundStyle(Theme.secondaryInk)
                } else {
                    MeditationPager(cards: cards, textSize: textSize)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Saint quotations under the Scripture. Paging them does not move the rosary.
private struct MeditationPager: View {
    let cards: [MeditationCard]
    let textSize: PrayerTextSize
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cards.indices.contains(index) {
                MeditationCardView(card: cards[index], textStyle: textSize.meditationStyle, framed: false)
                    .id(index)
            }
            if cards.count > 1 {
                HStack {
                    Text("\(index + 1) of \(cards.count)")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
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
    }
}
#endif
