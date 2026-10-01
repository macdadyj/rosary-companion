import Foundation

/// Fixed wording the app says aloud. Each case names one recording slot, so a recorded voice
/// can stand in for synthesized speech without the session engine knowing the difference.
public enum NarrationClip: Hashable, Sendable {
    /// The part of a prayer the app leads in guided mode. `holyGhost` is true only for prayers
    /// whose leader part changes with the "Holy Ghost" wording.
    case leaderPart(PrayerID, holyGhost: Bool)
    case intention(OpeningIntention)
    case mysteryAnnouncement(MysteryID)

    /// File name without extension, e.g. `prayer.gloryBe.holyGhost` or `mystery.scourging`.
    public var fileName: String {
        switch self {
        case let .leaderPart(prayer, holyGhost):
            "prayer.\(prayer.rawValue)" + (holyGhost ? ".holyGhost" : "")
        case .intention(let intention):
            "intention.\(intention.rawValue)"
        case .mysteryAnnouncement(let mystery):
            "mystery.\(mystery.rawValue)"
        }
    }

    /// The exact words a recording for this slot replaces.
    public var script: String {
        switch self {
        case let .leaderPart(prayer, holyGhost):
            PrayerBook(usesHolyGhost: holyGhost).text(for: prayer).leader
        case .intention(let intention):
            intention.spoken
        case .mysteryAnnouncement(let mystery):
            Mystery.with(id: mystery).announcement
        }
    }

    /// Every slot a full set of recordings would fill, in both wordings.
    public static var all: [NarrationClip] {
        let plain = PrayerBook(usesHolyGhost: false)
        let ghost = PrayerBook(usesHolyGhost: true)
        let prayers = PrayerID.allCases.flatMap { id in
            [plain.leaderPart(for: id)?.clip, ghost.leaderPart(for: id)?.clip].compactMap { $0 }
        }
        var seen = Set<NarrationClip>()
        return (prayers.filter { seen.insert($0).inserted })
            + OpeningIntention.allCases.map(NarrationClip.intention)
            + MysteryID.allCases.map(NarrationClip.mysteryAnnouncement)
    }
}

/// Something the app says aloud. Each part is either fixed wording, which a recording may
/// replace, or text that changes from session to session, such as a family member's name.
public struct Narration: Hashable, Sendable {
    public struct Part: Hashable, Sendable {
        public var text: String
        public var clip: NarrationClip?

        public init(_ text: String, clip: NarrationClip? = nil) {
            self.text = text
            self.clip = clip
        }
    }

    public var parts: [Part]

    public init(_ parts: [Part]) {
        self.parts = parts
    }

    /// Text that changes (names, for instance), so it is always synthesized.
    public init(_ text: String) {
        self.parts = [Part(text)]
    }

    public var text: String {
        parts.map(\.text).joined(separator: " ")
    }
}

extension PrayerBook {
    /// The leader part of a prayer, tagged with its recording slot; nil when all say it together.
    public func leaderPart(for id: PrayerID) -> Narration.Part? {
        let leader = text(for: id).leader
        guard !leader.isEmpty else { return nil }
        let changesWording = usesHolyGhost && Self.texts[id]?.leader.contains("Holy Spirit") == true
        return Narration.Part(leader, clip: .leaderPart(id, holyGhost: changesWording))
    }
}

extension Mystery {
    public var announcementPart: Narration.Part {
        Narration.Part(announcement, clip: .mysteryAnnouncement(id))
    }
}

extension OpeningIntention {
    public var spokenPart: Narration.Part {
        Narration.Part(spoken, clip: .intention(self))
    }
}
