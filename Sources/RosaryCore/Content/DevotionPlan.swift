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
