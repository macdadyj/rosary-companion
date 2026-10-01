#if os(iOS)
import RosaryCore
import SwiftUI

struct MeditationCardView: View {
    let card: MeditationCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch card {
            case .quote(let meditation):
                Label(meditation.saint, systemImage: "quote.opening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                Text(meditation.text ?? "")
                    .font(.prayer(.title3))
                    .italic()
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("— \(meditation.saint)")
                    if let source = meditation.source { Text(source) }
                }
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
            case .reflection(let prompt):
                Label("Reflection prompt", systemImage: "leaf")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                Text(Self.promptBody(prompt))
                    .font(.prayer(.title3))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Written for this app. Not a quotation.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    /// The stored prompt starts with its own label, which the card shows separately.
    static func promptBody(_ prompt: String) -> String {
        let label = "Reflection prompt (not a quotation):"
        guard prompt.hasPrefix(label) else { return prompt }
        return prompt.dropFirst(label.count).trimmingCharacters(in: .whitespaces)
    }
}
#endif
