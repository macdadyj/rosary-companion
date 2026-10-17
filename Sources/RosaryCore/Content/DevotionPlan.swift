import Foundation
import Observation

public struct DevotionBead: Hashable, Sendable, Identifiable {
    public let id: Int
    public let title: String
    /// Verified words. Nil when this bead is an unverified slot.
    public let text: String?
    public let prayer: PrayerID?
    public let slotID: String?
    /// 1-based place in a run of Hail Marys, when this bead is one of them.
    public let hailMaryIndex: Int?
    public let hailMaryCount: Int?

    public var isSlot: Bool { slotID != nil && text == nil }
}

public struct DevotionPlan: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let source: String
    public let sourceURL: String
    public let beads: [DevotionBead]

    public func bead(_ index: Int) -> DevotionBead? {
        beads.indices.contains(index) ? beads[index] : nil
    }

    /// Every bead, in order, with its words. A counted invocation that has no text says so.
    public var fullText: String {
        beads.map { bead in
            if let text = bead.text, !text.isEmpty {
                return "\(bead.title)\n\(text)"
            }
            return "\(bead.title)\nCounted bead. Pray this invocation from an approved edition."
        }.joined(separator: "\n\n")
    }
}

public enum DevotionCatalog {
    public static func sevenSorrows(book: PrayerBook, content: PrayerContent) -> DevotionPlan {
        let file = content.sorrows
        var beads: [DevotionBead] = []
        func add(title: String, text: String?, prayer: PrayerID? = nil, slotID: String? = nil, hailIndex: Int? = nil, hailCount: Int? = nil) {
            beads.append(DevotionBead(
                id: beads.count,
                title: title,
                text: text,
                prayer: prayer,
                slotID: slotID,
                hailMaryIndex: hailIndex,
                hailMaryCount: hailCount
            ))
        }
        add(title: "Offering", text: file.offering)
        for sorrow in file.sorrows {
            add(title: sorrow.title, text: sorrow.meditation)
            add(title: "Our Father", text: book.text(for: .ourFather).full, prayer: .ourFather)
            for number in 1...sorrow.hailMarys {
                add(
                    title: "Hail Mary \(number) of \(sorrow.hailMarys)",
                    text: book.text(for: .hailMary).full,
                    prayer: .hailMary,
                    hailIndex: number,
                    hailCount: sorrow.hailMarys
                )
            }
            add(title: sorrow.title, text: sorrow.prayer)
        }
        add(title: "Queen of Martyrs", text: file.queenOfMartyrs)
        add(title: "Act of Consecration", text: file.actOfConsecration)
        return DevotionPlan(
            id: "sevenSorrows",
            title: file.title,
            source: file.source,
            sourceURL: file.sourceURL,
            beads: beads
        )
    }

    /// Our Father, Hail Mary, and the Creed are the public-domain prayers already in the app.
    /// The Mercy invocations themselves are slots. See VERIFY.md.
    public static func divineMercy(book: PrayerBook, content: PrayerContent) -> DevotionPlan {
        var beads: [DevotionBead] = []
        func add(title: String, text: String?, prayer: PrayerID? = nil, slotID: String? = nil, hailIndex: Int? = nil, hailCount: Int? = nil) {
            beads.append(DevotionBead(
                id: beads.count,
                title: title,
                text: text,
                prayer: prayer,
                slotID: slotID,
                hailMaryIndex: hailIndex,
                hailMaryCount: hailCount
            ))
        }
        let opening = content.slot("divine-mercy.opening")
        let decade = content.slot("divine-mercy.decade")
        let closing = content.slot("divine-mercy.closing")
        add(title: opening?.title ?? "Opening", text: nil, slotID: "divine-mercy.opening")
        add(title: "Our Father", text: book.text(for: .ourFather).full, prayer: .ourFather)
        add(title: "Hail Mary", text: book.text(for: .hailMary).full, prayer: .hailMary)
        add(title: "Apostles' Creed", text: book.text(for: .apostlesCreed).full, prayer: .apostlesCreed)
        for decadeNumber in 1...5 {
            add(title: "Decade \(decadeNumber) · Our Father", text: book.text(for: .ourFather).full, prayer: .ourFather)
            for bead in 1...10 {
                add(
                    title: "Decade \(decadeNumber) · \(decade?.title ?? "Decade prayer") \(bead) of 10",
                    text: nil,
                    slotID: "divine-mercy.decade",
                    hailIndex: bead,
                    hailCount: 10
                )
            }
        }
        add(title: closing?.title ?? "Closing", text: nil, slotID: "divine-mercy.closing")
        return DevotionPlan(
            id: "divineMercy",
            title: "Chaplet of Divine Mercy",
            source: "Bead pattern only. The Mercy prayers are not included. See VERIFY.md.",
            sourceURL: "",
            beads: beads
        )
    }

    /// Chaplet of Saint Michael. The salutations are the traditional English of the chaplet
    /// approved in 1851. Each choir is one salutation, one Our Father, and three Hail Marys,
    /// then four Our Fathers and the closing prayers.
    public static func stMichaelChaplet(book: PrayerBook) -> DevotionPlan {
        var beads: [DevotionBead] = []
        func add(title: String, text: String, prayer: PrayerID? = nil, hailIndex: Int? = nil, hailCount: Int? = nil) {
            beads.append(DevotionBead(
                id: beads.count,
                title: title,
                text: text,
                prayer: prayer,
                slotID: nil,
                hailMaryIndex: hailIndex,
                hailMaryCount: hailCount
            ))
        }
        let glory = book.text(for: .gloryBe).full
        add(
            title: "Opening",
            text: """
            O God, come to my assistance.
            O Lord, make haste to help me.
            \(glory)
            """
        )
        for choir in michaelChoirs {
            add(title: choir.title, text: choir.text)
            add(title: "Our Father", text: book.text(for: .ourFather).full, prayer: .ourFather)
            for number in 1...3 {
                add(
                    title: "Hail Mary \(number) of 3",
                    text: book.text(for: .hailMary).full,
                    prayer: .hailMary,
                    hailIndex: number,
                    hailCount: 3
                )
            }
        }
        for (title, line) in michaelOurFathers {
            add(title: title, text: "\(line)\n\(book.text(for: .ourFather).full)", prayer: .ourFather)
        }
        add(
            title: "Closing",
            text: """
            \(michaelClosing)

            \(LayPrayers.saintMichaelShort)
            """
        )
        return DevotionPlan(
            id: "stMichael",
            title: "Chaplet of Saint Michael",
            source: "Traditional English of the chaplet of Saint Michael, from the form approved in 1851 and printed in prayer books before 1928.",
            sourceURL: "",
            beads: beads
        )
    }

    private static let michaelChoirs: [(title: String, text: String)] = [
        ("Choir of Seraphim", "By the intercession of Saint Michael and the celestial Choir of Seraphim, may the Lord make us worthy to burn with the fire of perfect charity. Amen."),
        ("Choir of Cherubim", "By the intercession of Saint Michael and the celestial Choir of Cherubim, may the Lord grant us the grace to leave the ways of sin and run in the paths of Christian perfection. Amen."),
        ("Choir of Thrones", "By the intercession of Saint Michael and the celestial Choir of Thrones, may the Lord infuse into our hearts a true and sincere spirit of humility. Amen."),
        ("Choir of Dominions", "By the intercession of Saint Michael and the celestial Choir of Dominions, may the Lord give us grace to govern our senses and overcome our passions. Amen."),
        ("Choir of Powers", "By the intercession of Saint Michael and the celestial Choir of Powers, may the Lord protect our souls against the snares and temptations of the devil. Amen."),
        ("Choir of Virtues", "By the intercession of Saint Michael and the celestial Choir of Virtues, may the Lord preserve us from evil and from falling into temptation. Amen."),
        ("Choir of Principalities", "By the intercession of Saint Michael and the celestial Choir of Principalities, may God fill our souls with a true spirit of obedience. Amen."),
        ("Choir of Archangels", "By the intercession of Saint Michael and the celestial Choir of Archangels, may the Lord give us perseverance in faith and in all good works, in order that we may attain the glory of Heaven. Amen."),
        ("Choir of Angels", "By the intercession of Saint Michael and the celestial Choir of Angels, may the Lord grant us to be protected by them in this mortal life and conducted hereafter to eternal glory. Amen."),
    ]

    private static let michaelOurFathers: [(String, String)] = [
        ("Our Father · Saint Michael", "One Our Father in honor of Saint Michael."),
        ("Our Father · Saint Gabriel", "One Our Father in honor of Saint Gabriel."),
        ("Our Father · Saint Raphael", "One Our Father in honor of Saint Raphael."),
        ("Our Father · Guardian Angel", "One Our Father in honor of our Guardian Angel."),
    ]

    private static let michaelClosing = """
    O glorious Prince Saint Michael, chief and commander of the heavenly hosts, guardian of souls, vanquisher of rebel spirits, servant in the house of the Divine King and our admirable conductor, who dost shine with excellence and superhuman virtue: vouchsafe to deliver us from all evil, who turn to thee with confidence, and enable us by thy gracious protection to serve God more and more faithfully every day.

    Pray for us, O glorious Saint Michael, Prince of the Church of Jesus Christ.
    That we may be made worthy of his promises.

    Almighty and everlasting God, who by a prodigy of goodness and a merciful desire for the salvation of all men hast appointed the most glorious Archangel Saint Michael prince of thy Church: make us worthy, we beseech thee, to be delivered by his protection from all our enemies, that none of them may harass us at the hour of death, but that we may be conducted by him into thy presence. This we ask through the merits of Jesus Christ our Lord. Amen.
    """
}

@Observable
public final class DevotionController {
    public let plan: DevotionPlan
    public private(set) var index = 0
    public private(set) var haptics: [HapticEvent] = []
    private let detector = AnchorDetector()
    private var epoch = 0

    public init(plan: DevotionPlan) {
        self.plan = plan
    }

    public var bead: DevotionBead? { plan.bead(index) }
    public var isFinished: Bool { index >= plan.beads.count }

    public func tap() {
        advance(cause: .tapAdvance)
    }

    public func back() {
        guard index > 0 else { return }
        index -= 1
        epoch += 1
        detector.reset()
        haptics.append(.stepBack)
    }

    /// Voice tracking for beads whose words are already in the Rosary (Our Father, Hail Mary, Creed).
    public func ingest(_ update: TranscriptUpdate, at time: TimeInterval) {
        guard let prayer = bead?.prayer else { return }
        let closings = AnchorLibrary.fragments(for: prayer).filter(\.isClosing)
        guard !closings.isEmpty else { return }
        let stamped = TranscriptUpdate(epoch: epoch, segment: update.segment, text: update.text, isFinal: update.isFinal)
        let hits = detector.process(stamped, fragments: closings, now: time)
        if hits.contains(where: { $0.fragment.isClosing }) {
            advance(cause: .voiceAdvance)
        }
    }

    private func advance(cause: HapticEvent) {
        guard !isFinished else { return }
        index += 1
        epoch += 1
        detector.reset()
        haptics.append(cause)
        if isFinished { haptics.append(.sessionComplete) }
    }
}
