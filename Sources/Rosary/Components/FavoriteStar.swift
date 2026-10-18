#if os(iOS)
import RosaryCore
import SwiftUI

/// A star that sits outside a navigation link so marking a favorite does not open the prayer.
struct FavoriteStar: View {
    let id: String
    let model: AppModel

    var body: some View {
        Button {
            model.toggleFavorite(id)
        } label: {
            Image(systemName: model.isFavorite(id) ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(Theme.gold)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isFavorite(id) ? "Remove from favorites" : "Add to favorites")
        .uiTag(UITag.libraryFavorite(id))
    }
}
#endif
