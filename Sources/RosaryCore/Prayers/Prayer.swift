import Foundation

public enum PrayerID: String, Codable, CaseIterable, Hashable, Sendable {
    case signOfTheCross
    case apostlesCreed
    case ourFather
    case hailMary
    case gloryBe
    case fatimaPrayer
    case hailHolyQueen
    case rosaryVersicle
    case closingPrayer
}

/// The three traditional intentions for the opening Hail Marys.
public enum OpeningIntention: String, Codable, CaseIterable, Hashable, Sendable {
    case faith, hope, charity

    public var spoken: String {
        switch self {
        case .faith: "For an increase of faith."
        case .hope: "For an increase of hope."
        case .charity: "For an increase of charity."
        }
    }

    public var label: String {
        switch self {
        case .faith: "For faith"
        case .hope: "For hope"
        case .charity: "For charity"
        }
    }
}

/// A prayer split into the part a leader says and the part everyone answers.
/// Either half may be empty (e.g. the Fatima Prayer is said by all).
public struct PrayerText: Hashable, Sendable {
    public let id: PrayerID
    public let title: String
    public let leader: String
    public let response: String

    public var full: String {
        [leader, response].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// Traditional English texts of the Rosary prayers (public domain).
public struct PrayerBook: Hashable, Sendable {
    /// Many families still pray "Holy Ghost"; the anchor matcher accepts either.
    public var usesHolyGhost: Bool

    public init(usesHolyGhost: Bool = false) {
        self.usesHolyGhost = usesHolyGhost
    }

    public func text(for id: PrayerID) -> PrayerText {
        let base = Self.texts[id]!
        guard usesHolyGhost else { return base }
        return PrayerText(
            id: base.id,
            title: base.title,
            leader: base.leader.replacingOccurrences(of: "Holy Spirit", with: "Holy Ghost"),
            response: base.response.replacingOccurrences(of: "Holy Spirit", with: "Holy Ghost")
        )
    }

    static let texts: [PrayerID: PrayerText] = {
        let all: [PrayerText] = [
            PrayerText(
                id: .signOfTheCross,
                title: "Sign of the Cross",
                leader: "In the name of the Father, and of the Son, and of the Holy Spirit. Amen.",
                response: ""
            ),
            PrayerText(
                id: .apostlesCreed,
                title: "Apostles' Creed",
                leader: """
                I believe in God, the Father almighty, Creator of heaven and earth; \
                and in Jesus Christ, his only Son, our Lord, \
                who was conceived by the Holy Spirit, born of the Virgin Mary, \
                suffered under Pontius Pilate, was crucified, died, and was buried. \
                He descended into hell; the third day he rose again from the dead; \
                he ascended into heaven, and sitteth at the right hand of God, the Father almighty; \
                from thence he shall come to judge the living and the dead.
                """,
                response: """
                I believe in the Holy Spirit, the holy Catholic Church, the communion of saints, \
                the forgiveness of sins, the resurrection of the body, and life everlasting. Amen.
                """
            ),
            PrayerText(
                id: .ourFather,
                title: "Our Father",
                leader: """
                Our Father, who art in heaven, hallowed be thy name; thy kingdom come, \
                thy will be done on earth as it is in heaven.
                """,
                response: """
                Give us this day our daily bread, and forgive us our trespasses, \
                as we forgive those who trespass against us; \
                and lead us not into temptation, but deliver us from evil. Amen.
                """
            ),
            PrayerText(
                id: .hailMary,
                title: "Hail Mary",
                leader: """
                Hail Mary, full of grace, the Lord is with thee; blessed art thou among women, \
                and blessed is the fruit of thy womb, Jesus.
                """,
                response: """
                Holy Mary, Mother of God, pray for us sinners, \
                now and at the hour of our death. Amen.
                """
            ),
            PrayerText(
                id: .gloryBe,
                title: "Glory Be",
                leader: "Glory be to the Father, and to the Son, and to the Holy Spirit.",
                response: "As it was in the beginning, is now, and ever shall be, world without end. Amen."
            ),
            PrayerText(
                id: .fatimaPrayer,
                title: "Fatima Prayer",
                leader: "",
                response: """
                O my Jesus, forgive us our sins, save us from the fires of hell; \
                lead all souls to heaven, especially those in most need of thy mercy.
                """
            ),
            PrayerText(
                id: .hailHolyQueen,
                title: "Hail, Holy Queen",
                leader: "Hail, holy Queen, Mother of mercy, our life, our sweetness and our hope.",
                response: """
                To thee do we cry, poor banished children of Eve; \
                to thee do we send up our sighs, mourning and weeping in this valley of tears. \
                Turn then, most gracious advocate, thine eyes of mercy toward us; \
                and after this our exile, show unto us the blessed fruit of thy womb, Jesus. \
                O clement, O loving, O sweet Virgin Mary.
                """
            ),
            PrayerText(
                id: .rosaryVersicle,
                title: "Versicle and Response",
                leader: "Pray for us, O holy Mother of God.",
                response: "That we may be made worthy of the promises of Christ."
            ),
            PrayerText(
                id: .closingPrayer,
                title: "Closing Prayer",
                leader: """
                Let us pray. O God, whose only-begotten Son, by his life, death, and resurrection, \
                has purchased for us the rewards of eternal life; grant, we beseech thee, \
                that, meditating upon these mysteries of the most holy Rosary of the Blessed Virgin Mary, \
                we may imitate what they contain and obtain what they promise, \
                through the same Christ our Lord. Amen.
                """,
                response: ""
            ),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()
}
