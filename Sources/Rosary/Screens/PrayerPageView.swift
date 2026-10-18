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
                    .font(.prayer(.title3))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .uiTag(UITag.libraryBody)
                if plan != nil {
                    NavigationLink {
                        DevotionSessionView(plan: plan, model: model, content: content, startsStepping: true)
                    } label: {
                        Text("Pray bead by bead")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Text(prayer.source)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
                Text(prayer.licenseNote)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryInk)
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
