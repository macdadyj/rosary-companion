#if os(iOS)
import RosaryCore
import SwiftUI

struct PrayerPageView: View {
    let prayer: LibraryPrayer
    let model: AppModel
    let content: PrayerContent?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(prayer.title)
                        .font(.prayer(.largeTitle, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    FavoriteStar(id: prayer.id, model: model)
                }
                Text(prayer.body)
                    .font(.prayer(model.settings.textSize.prayerStyle))
                    .lineSpacing(8)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .uiTag(UITag.libraryBody)
                if plan != nil {
                    NavigationLink {
                        DevotionSessionView(plan: plan, model: model, content: content, startsStepping: true)
                    } label: {
                        Text("Pray bead by bead")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .accessibilityHint("Opens this chaplet one bead at a time")
                }
                Text(prayer.source)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Source. \(prayer.source)")
                Text(prayer.licenseNote)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .accessibilityLabel("License. \(prayer.licenseNote)")
            }
            .padding(20)
        }
        .background(CandleBackground())
        .navigationTitle(prayer.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.rememberPrayer(prayer.id) }
    }

    private var book: PrayerBook {
        PrayerBook(usesHolyGhost: model.settings.usesHolyGhost)
    }

    private var plan: DevotionPlan? {
        switch prayer.devotionID {
        case "stMichael":
            return DevotionCatalog.stMichaelChaplet(book: book)
        case "sevenSorrows":
            return content.map { DevotionCatalog.sevenSorrows(book: book, content: $0) }
        case "divineMercy":
            return content.map { DevotionCatalog.divineMercy(book: book, content: $0) }
        case nil:
            return nil
        default:
            return nil
        }
    }
}
#endif
