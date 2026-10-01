import Foundation

/// What a detected phrase tells us about where the person is in the Rosary.
public enum AnchorKind: Hashable, Sendable {
    case prayer(PrayerID)
    case announcement(decade: Int)
}

public enum PrayerPart: Hashable, Sendable {
    case leader
    case response
}

/// A short, distinctive phrase from a prayer. Prayers are recognised from fragments rather
/// than full transcription so a few misheard words never block progress.
public struct AnchorFragment: Hashable, Sendable, CustomStringConvertible {
    public let kind: AnchorKind
    /// Position of the fragment within its prayer, used to tell a new repetition from a continuation.
    public let order: Int
    public let part: PrayerPart
    /// The last distinctive phrase of the prayer: hearing it means the prayer is finished.
    public let isClosing: Bool
    public let phrase: String
    public let folded: [UInt8]
    public let maxErrors: Int

    public init(
        kind: AnchorKind,
        order: Int,
        part: PrayerPart,
        isClosing: Bool = false,
        phrase: String,
        errorRate: Double = AnchorLibrary.defaultErrorRate,
        maxErrors: Int? = nil
    ) {
        self.kind = kind
        self.order = order
        self.part = part
        self.isClosing = isClosing
        self.phrase = phrase
        self.folded = TextNormalizer.folded(phrase)
        self.maxErrors = maxErrors ?? max(1, Int(Double(folded.count) * errorRate))
    }

    public var description: String { "\(kind)#\(order) \"\(phrase)\"" }
}

public enum AnchorLibrary {
    /// Fraction of characters (after folding) that may be wrong in a match.
    public static let defaultErrorRate = 0.26

    public static func fragments(for prayer: PrayerID) -> [AnchorFragment] {
        prayerFragments[prayer] ?? []
    }

    public static func fragments(forAnnouncementOf mystery: Mystery) -> [AnchorFragment] {
        let kind = AnchorKind.announcement(decade: mystery.number)
        let ordinal = mystery.ordinalWord
        return [
            // Ordinals are close to each other ("first"/"fifth"), so allow fewer errors.
            AnchorFragment(kind: kind, order: 0, part: .leader,
                           phrase: "\(ordinal) \(mystery.set.adjective.lowercased()) mystery", maxErrors: 3),
            AnchorFragment(kind: kind, order: 0, part: .leader, phrase: "\(ordinal) mystery", maxErrors: 2),
            AnchorFragment(kind: kind, order: 1, part: .leader, phrase: mystery.spokenKey, errorRate: 0.22),
        ]
    }

    public static func fragments(for step: RosaryStep) -> [AnchorFragment] {
        switch step.content {
        case .prayer(let id): fragments(for: id)
        case .mysteryAnnouncement(let mystery): fragments(forAnnouncementOf: mystery)
        }
    }

    private static func build(_ prayer: PrayerID, _ items: [(PrayerPart, String)]) -> [AnchorFragment] {
        items.enumerated().map { index, item in
            AnchorFragment(
                kind: .prayer(prayer),
                order: index,
                part: item.0,
                isClosing: index == items.count - 1,
                phrase: item.1
            )
        }
    }

    static let prayerFragments: [PrayerID: [AnchorFragment]] = [
        .signOfTheCross: build(.signOfTheCross, [
            (.leader, "in the name of the father"),
            (.leader, "and of the son and of the holy spirit"),
        ]),
        .apostlesCreed: build(.apostlesCreed, [
            (.leader, "i believe in god the father almighty"),
            (.leader, "creator of heaven and earth"),
            (.leader, "his only son our lord"),
            (.leader, "born of the virgin mary"),
            (.leader, "suffered under pontius pilate"),
            (.leader, "he descended into hell"),
            (.leader, "he ascended into heaven"),
            (.leader, "to judge the living and the dead"),
            (.response, "i believe in the holy spirit"),
            (.response, "the holy catholic church"),
            (.response, "the communion of saints"),
            (.response, "the forgiveness of sins"),
            (.response, "the resurrection of the body"),
            (.response, "and life everlasting"),
        ]),
        .ourFather: build(.ourFather, [
            (.leader, "our father who art in heaven"),
            (.leader, "hallowed be thy name"),
            (.leader, "thy kingdom come"),
            (.leader, "thy will be done on earth"),
            (.response, "give us this day our daily bread"),
            (.response, "forgive us our trespasses"),
            (.response, "as we forgive those who trespass against us"),
            (.response, "lead us not into temptation"),
            (.response, "but deliver us from evil"),
        ]),
        .hailMary: build(.hailMary, [
            (.leader, "hail mary full of grace"),
            (.leader, "the lord is with thee"),
            (.leader, "blessed art thou among women"),
            (.leader, "blessed is the fruit of thy womb"),
            (.response, "holy mary mother of god"),
            (.response, "pray for us sinners"),
            (.response, "now and at the hour of our death"),
        ]),
        .gloryBe: build(.gloryBe, [
            (.leader, "glory be to the father"),
            (.leader, "and to the son and to the holy spirit"),
            (.response, "as it was in the beginning"),
            (.response, "is now and ever shall be"),
            (.response, "world without end"),
        ]),
        .fatimaPrayer: build(.fatimaPrayer, [
            (.response, "o my jesus forgive us our sins"),
            (.response, "save us from the fires of hell"),
            (.response, "lead all souls to heaven"),
            (.response, "especially those in most need of thy mercy"),
        ]),
        .hailHolyQueen: build(.hailHolyQueen, [
            (.leader, "hail holy queen mother of mercy"),
            (.leader, "our life our sweetness and our hope"),
            (.response, "poor banished children of eve"),
            (.response, "mourning and weeping in this valley of tears"),
            (.response, "most gracious advocate"),
            (.response, "thine eyes of mercy toward us"),
            (.response, "after this our exile"),
            (.response, "o clement o loving o sweet virgin mary"),
        ]),
        .rosaryVersicle: build(.rosaryVersicle, [
            (.leader, "pray for us o holy mother of god"),
            (.response, "that we may be made worthy"),
            (.response, "of the promises of christ"),
        ]),
        .closingPrayer: build(.closingPrayer, [
            (.leader, "o god whose only begotten son"),
            (.leader, "purchased for us the rewards of eternal life"),
            (.leader, "meditating upon these mysteries"),
            (.leader, "imitate what they contain"),
            (.leader, "obtain what they promise"),
            (.leader, "through the same christ our lord"),
        ]),
    ]
}
