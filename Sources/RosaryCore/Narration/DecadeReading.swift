import Foundation

/// Words spoken at the start of a decade when meditations are read aloud:
/// the mystery title, then the Scripture, then a short meditation.
public enum DecadeReading {
    public struct Scripts: Hashable, Sendable {
        public var scripture: [MysteryID: String]
        public var meditation: [MysteryID: String]

        public init(scripture: [MysteryID: String] = [:], meditation: [MysteryID: String] = [:]) {
            self.scripture = scripture
            self.meditation = meditation
        }
    }

    /// “Luke 1:26–38. 26 And in the sixth month…” or the citation alone when the verses are missing.
    public static func scriptureLine(reference: String, body: String) -> String {
        let spoken = collapsed(body)
        let cite = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if spoken.isEmpty { return cite }
        if cite.isEmpty { return spoken }
        return "\(cite). \(spoken)"
    }

    /// The fruit to contemplate, then the first verified saint quote for the day.
    public static func meditationLine(contemplate: String?, quote: String?) -> String {
        let parts = [contemplate, quote]
            .compactMap { $0 }
            .map(collapsed)
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    public static func narrations(
        announcement: Narration,
        scripture: String,
        meditation: String
    ) -> [Narration] {
        var lines = [announcement]
        let scripture = collapsed(scripture)
        let meditation = collapsed(meditation)
        if !scripture.isEmpty { lines.append(Narration(scripture)) }
        if !meditation.isEmpty { lines.append(Narration(meditation)) }
        return lines
    }

    public static func scripts(content: PrayerContent?, saints: SaintsLibrary?, day: CivilDate) -> Scripts {
        var scripture: [MysteryID: String] = [:]
        var meditation: [MysteryID: String] = [:]
        for id in MysteryID.allCases {
            let mystery = Mystery.with(id: id)
            if let passage = content?.passage(for: id) {
                scripture[id] = scriptureLine(reference: passage.reference, body: passage.body)
            } else if !mystery.scripture.isEmpty {
                scripture[id] = mystery.scripture
            }
            let contemplate = content?.fruitPrayer(for: id)?.contemplate
            let quote = saints?.card(for: id, on: day).flatMap(quoteText)
            let line = meditationLine(contemplate: contemplate, quote: quote)
            if !line.isEmpty { meditation[id] = line }
        }
        return Scripts(scripture: scripture, meditation: meditation)
    }

    private static func quoteText(_ card: MeditationCard) -> String? {
        switch card {
        case .quote(let meditation):
            return meditation.text
        case .reflection:
            return nil
        }
    }

    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
