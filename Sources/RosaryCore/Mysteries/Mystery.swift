import Foundation

public enum MysterySet: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case joyful, luminous, sorrowful, glorious

    public var id: String { rawValue }

    public var adjective: String {
        switch self {
        case .joyful: "Joyful"
        case .luminous: "Luminous"
        case .sorrowful: "Sorrowful"
        case .glorious: "Glorious"
        }
    }

    /// "The Joyful Mysteries"
    public var title: String { "The \(adjective) Mysteries" }

    public var mysteries: [Mystery] {
        Mystery.all.filter { $0.set == self }.sorted { $0.number < $1.number }
    }
}

public enum MysteryID: String, Codable, CaseIterable, Hashable, Sendable {
    case annunciation, visitation, nativity, presentation, findingInTemple
    case baptism, weddingAtCana, proclamation, transfiguration, eucharist
    case agonyInGarden, scourging, crowningWithThorns, carryingCross, crucifixion
    case resurrection, ascension, descentOfHolySpirit, assumption, coronation
}

public struct Mystery: Identifiable, Hashable, Sendable {
    public let id: MysteryID
    public let set: MysterySet
    /// 1...5 within its set.
    public let number: Int
    public let title: String
    /// Words that are distinctive enough to recognise the mystery when someone announces it.
    public let spokenKey: String
    public let scripture: String
    /// The fruit traditionally associated with the mystery (traditions vary slightly).
    public let fruit: String

    public var ordinalWord: String { Ordinal.word(number) }

    /// "The First Joyful Mystery"
    public var heading: String {
        "The \(ordinalWord.capitalized) \(set.adjective) Mystery"
    }

    /// What the leader says to announce the decade.
    public var announcement: String {
        "\(heading): \(title)."
    }

    public static func with(id: MysteryID) -> Mystery {
        all.first { $0.id == id }!
    }

    public static let all: [Mystery] = [
        Mystery(id: .annunciation, set: .joyful, number: 1, title: "The Annunciation",
                spokenKey: "the annunciation", scripture: "Luke 1:26–38", fruit: "Humility"),
        Mystery(id: .visitation, set: .joyful, number: 2, title: "The Visitation",
                spokenKey: "the visitation", scripture: "Luke 1:39–56", fruit: "Love of neighbor"),
        Mystery(id: .nativity, set: .joyful, number: 3, title: "The Nativity",
                spokenKey: "the nativity", scripture: "Luke 2:1–20", fruit: "Poverty of spirit"),
        Mystery(id: .presentation, set: .joyful, number: 4, title: "The Presentation in the Temple",
                spokenKey: "the presentation", scripture: "Luke 2:22–38", fruit: "Obedience"),
        Mystery(id: .findingInTemple, set: .joyful, number: 5, title: "The Finding of Jesus in the Temple",
                spokenKey: "the finding of jesus", scripture: "Luke 2:41–52", fruit: "Joy in finding Jesus"),

        Mystery(id: .baptism, set: .luminous, number: 1, title: "The Baptism of the Lord",
                spokenKey: "the baptism", scripture: "Matthew 3:13–17", fruit: "Openness to the Holy Spirit"),
        Mystery(id: .weddingAtCana, set: .luminous, number: 2, title: "The Wedding at Cana",
                spokenKey: "the wedding at cana", scripture: "John 2:1–12", fruit: "To Jesus through Mary"),
        Mystery(id: .proclamation, set: .luminous, number: 3, title: "The Proclamation of the Kingdom",
                spokenKey: "the proclamation of the kingdom", scripture: "Mark 1:14–15",
                fruit: "Repentance and trust in God"),
        Mystery(id: .transfiguration, set: .luminous, number: 4, title: "The Transfiguration",
                spokenKey: "the transfiguration", scripture: "Luke 9:28–36", fruit: "Desire for holiness"),
        Mystery(id: .eucharist, set: .luminous, number: 5, title: "The Institution of the Eucharist",
                spokenKey: "the institution of the eucharist", scripture: "Luke 22:14–20", fruit: "Adoration"),

        Mystery(id: .agonyInGarden, set: .sorrowful, number: 1, title: "The Agony in the Garden",
                spokenKey: "the agony in the garden", scripture: "Luke 22:39–46", fruit: "Sorrow for sin"),
        Mystery(id: .scourging, set: .sorrowful, number: 2, title: "The Scourging at the Pillar",
                spokenKey: "the scourging at the pillar", scripture: "John 19:1", fruit: "Purity"),
        Mystery(id: .crowningWithThorns, set: .sorrowful, number: 3, title: "The Crowning with Thorns",
                spokenKey: "the crowning with thorns", scripture: "Matthew 27:27–31", fruit: "Courage"),
        Mystery(id: .carryingCross, set: .sorrowful, number: 4, title: "The Carrying of the Cross",
                spokenKey: "the carrying of the cross", scripture: "John 19:16–17", fruit: "Patience"),
        Mystery(id: .crucifixion, set: .sorrowful, number: 5, title: "The Crucifixion and Death of Our Lord",
                spokenKey: "the crucifixion", scripture: "Luke 23:33–46", fruit: "Perseverance"),

        Mystery(id: .resurrection, set: .glorious, number: 1, title: "The Resurrection",
                spokenKey: "the resurrection", scripture: "Mark 16:1–8", fruit: "Faith"),
        Mystery(id: .ascension, set: .glorious, number: 2, title: "The Ascension",
                spokenKey: "the ascension", scripture: "Acts 1:6–11", fruit: "Hope"),
        Mystery(id: .descentOfHolySpirit, set: .glorious, number: 3, title: "The Descent of the Holy Spirit",
                spokenKey: "the descent of the holy spirit", scripture: "Acts 2:1–13", fruit: "Love of God"),
        Mystery(id: .assumption, set: .glorious, number: 4, title: "The Assumption of Mary",
                spokenKey: "the assumption", scripture: "cf. Revelation 12:1", fruit: "Grace of a happy death"),
        Mystery(id: .coronation, set: .glorious, number: 5, title: "The Coronation of Mary",
                spokenKey: "the coronation", scripture: "cf. Revelation 12:1",
                fruit: "Trust in Mary's intercession"),
    ]
}

public enum Ordinal {
    public static let words = ["first", "second", "third", "fourth", "fifth"]

    public static func word(_ number: Int) -> String {
        guard (1...words.count).contains(number) else { return "\(number)th" }
        return words[number - 1]
    }
}
