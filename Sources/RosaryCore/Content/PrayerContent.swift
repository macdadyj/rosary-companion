import Foundation

public struct ScriptureVerse: Codable, Hashable, Sendable {
    public var verse: Int
    public var text: String
}

public struct ScripturePassage: Codable, Hashable, Sendable, Identifiable {
    public var mystery: MysteryID
    public var reference: String
    public var book: String
    public var chapter: Int
    public var verified: Bool
    public var note: String?
    public var verses: [ScriptureVerse]
    public var sha1: String

    public var id: MysteryID { mystery }

    public var body: String {
        verses.map { "\($0.verse) \($0.text)" }.joined(separator: "\n")
    }
}

public struct FruitPrayer: Codable, Hashable, Sendable, Identifiable {
    public var mystery: MysteryID
    public var heading: String
    public var contemplate: String
    public var prayer: String
    public var sha1: String

    public var id: MysteryID { mystery }

    public var body: String { contemplate + "\n" + prayer }
}

public struct LitanyRow: Codable, Hashable, Sendable, Identifiable {
    public var latin: String
    public var english: String

    public var id: String { english + "\n" + latin }
}

public struct SorrowSection: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var meditation: String
    public var prayer: String
    public var ourFather: Int
    public var hailMarys: Int
    public var sha1: String
}

public struct ContentSlot: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var reason: String
}

public struct SacredWork: Codable, Hashable, Sendable, Identifiable {
    public var mystery: MysteryID
    public var file: String
    public var title: String
    public var artist: String
    public var credit: String
    public var license: String
    public var sourceURL: String
    public var commonsSha1: String
    public var sha1: String

    public var id: MysteryID { mystery }

    /// What to print under the picture.
    public var creditLine: String {
        let painter = artist.isEmpty ? "Artist not named on the file" : artist
        return "\(title). \(painter). \(license)."
    }
}

public struct MarianFeast: Codable, Hashable, Sendable, Identifiable {
    public var month: Int?
    public var day: Int?
    public var movable: MovableMarianFeast?
    public var name: String
    public var rank: String?

    public var id: String {
        "\(month ?? 0)-\(day ?? 0)-\(movable?.rawValue ?? "")-\(name)"
    }

    public func occurs(on date: CivilDate) -> Bool {
        if let movable {
            switch movable {
            case .mondayAfterPentecost:
                return date == LiturgicalCalendar.easter(year: date.year).adding(days: 50)
            case .saturdayAfterSacredHeart:
                return date == LiturgicalCalendar.easter(year: date.year).adding(days: 69)
            }
        }
        return month == date.month && day == date.day
    }

    public var fixedDate: CivilDate? {
        guard let month, let day else { return nil }
        return CivilDate(year: 2000, month: month, day: day)
    }
}

public enum MovableMarianFeast: String, Codable, Hashable, Sendable {
    case mondayAfterPentecost
    case saturdayAfterSacredHeart
}

public struct FeastCalendar: Codable, Hashable, Sendable {
    public var name: String
    public var source: String
    public var sourceURL: String
    public var feasts: [MarianFeast]

    public func feasts(on date: CivilDate) -> [MarianFeast] {
        feasts.filter { $0.occurs(on: date) }
    }

    /// Fixed feasts in month order, then movable ones.
    public var ordered: [MarianFeast] {
        feasts.sorted { lhs, rhs in
            let left = (lhs.month ?? 13) * 100 + (lhs.day ?? 0)
            let right = (rhs.month ?? 13) * 100 + (rhs.day ?? 0)
            if left != right { return left < right }
            return lhs.name < rhs.name
        }
    }
}

/// Regina Caeli replaces the Angelus in the season named by the 1857 Raccolta.
public enum MarianHours {
    public static func usesReginaCaeli(on date: CivilDate) -> Bool {
        let easter = LiturgicalCalendar.easter(year: date.year)
        let holySaturday = easter.adding(days: -1)
        let saturdayBeforeTrinity = easter.adding(days: 55)
        return date >= holySaturday && date <= saturdayBeforeTrinity
    }
}

public struct PrayerContent: Sendable {
    public struct ScriptureFile: Codable, Sendable {
        public var translation: String
        public var source: String
        public var sourceURL: String
        public var license: String
        public var retrieved: String
        public var passages: [ScripturePassage]
    }

    public struct FruitFile: Codable, Sendable {
        public var source: String
        public var sourceURL: String
        public var license: String
        public var retrieved: String
        public var note: String
        public var prayers: [FruitPrayer]
    }

    public struct LitanyFile: Codable, Sendable {
        public var title: String
        public var source: String
        public var sourceURL: String
        public var license: String
        public var retrieved: String
        public var note: String
        public var rows: [LitanyRow]
        public var sha1: String
    }

    public struct HoursFile: Codable, Sendable {
        public var source: String
        public var sourceURL: String
        public var license: String
        public var retrieved: String
        public var seasonNote: String
        public var angelus: [String]
        public var reginaCaeli: [String]
        public var angelusSha1: String
        public var reginaSha1: String
    }

    public struct SorrowsFile: Codable, Sendable {
        public var title: String
        public var source: String
        public var sourceURL: String
        public var license: String
        public var retrieved: String
        public var note: String
        public var offering: String
        public var offeringSha1: String
        public var sorrows: [SorrowSection]
        public var queenOfMartyrs: String
        public var queenSha1: String
        public var actOfConsecration: String
        public var actSha1: String
    }

    public struct SlotFile: Codable, Sendable {
        public var slots: [ContentSlot]
    }

    public struct ArtFile: Codable, Sendable {
        public var note: String
        public var works: [SacredWork]
    }

    public struct FeastFile: Codable, Sendable {
        public var retrieved: String
        public var ruthenian: FeastCalendar
        public var western: FeastCalendar
    }

    public let scripture: ScriptureFile
    public let fruits: FruitFile
    public let litany: LitanyFile
    public let hours: HoursFile
    public let sorrows: SorrowsFile
    public let slots: SlotFile
    public let art: ArtFile
    public let feasts: FeastFile

    public static func bundled() throws -> PrayerContent {
        try PrayerContent(
            scripture: load("scripture", as: ScriptureFile.self),
            fruits: load("fruits", as: FruitFile.self),
            litany: load("litany", as: LitanyFile.self),
            hours: load("hours", as: HoursFile.self),
            sorrows: load("seven_sorrows", as: SorrowsFile.self),
            slots: load("slots", as: SlotFile.self),
            art: load("art", as: ArtFile.self),
            feasts: load("feasts", as: FeastFile.self)
        )
    }

    public func passage(for mystery: MysteryID) -> ScripturePassage? {
        scripture.passages.first { $0.mystery == mystery }
    }

    public func fruitPrayer(for mystery: MysteryID) -> FruitPrayer? {
        fruits.prayers.first { $0.mystery == mystery }
    }

    public func work(for mystery: MysteryID) -> SacredWork? {
        art.works.first { $0.mystery == mystery }
    }

    public func imageData(for mystery: MysteryID) -> Data? {
        guard let work = work(for: mystery) else { return nil }
        return Self.resourceData(name: work.file, subdirectory: "Art")
    }

    public func slot(_ id: String) -> ContentSlot? {
        slots.slots.first { $0.id == id }
    }

    public func feasts(on date: CivilDate, rite: Rite) -> [MarianFeast] {
        switch rite {
        case .ruthenian: feasts.ruthenian.feasts(on: date)
        case .western: feasts.western.feasts(on: date)
        }
    }

    /// Problems in the bundled files: a hash that does not match, or a painting whose bytes changed.
    public func integrityProblems() -> [String] {
        var problems: [String] = []
        for passage in scripture.passages where ContentSHA1.hex(passage.body) != passage.sha1 {
            problems.append("scripture \(passage.mystery.rawValue)")
        }
        for prayer in fruits.prayers where ContentSHA1.hex(prayer.body) != prayer.sha1 {
            problems.append("fruit \(prayer.mystery.rawValue)")
        }
        let litanyBody = litany.rows.map { "\($0.latin) / \($0.english)" }.joined(separator: "\n")
        if ContentSHA1.hex(litanyBody) != litany.sha1 { problems.append("litany") }
        if ContentSHA1.hex(hours.angelus.joined(separator: "\n")) != hours.angelusSha1 { problems.append("angelus") }
        if ContentSHA1.hex(hours.reginaCaeli.joined(separator: "\n")) != hours.reginaSha1 { problems.append("regina") }
        if ContentSHA1.hex(sorrows.offering) != sorrows.offeringSha1 { problems.append("sorrows offering") }
        if ContentSHA1.hex(sorrows.queenOfMartyrs) != sorrows.queenSha1 { problems.append("queen of martyrs") }
        if ContentSHA1.hex(sorrows.actOfConsecration) != sorrows.actSha1 { problems.append("act of consecration") }
        for sorrow in sorrows.sorrows where ContentSHA1.hex(sorrow.meditation + "\n" + sorrow.prayer) != sorrow.sha1 {
            problems.append("sorrow \(sorrow.id)")
        }
        for work in art.works {
            guard let data = imageData(for: work.mystery) else {
                problems.append("missing art \(work.mystery.rawValue)")
                continue
            }
            if ContentSHA1.hex(data) != work.sha1 {
                problems.append("art sha1 \(work.mystery.rawValue)")
            }
        }
        return problems
    }

    private static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let data = resourceData(name: "\(name).json", subdirectory: "verified") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func resourceData(name: String, subdirectory: String) -> Data? {
        let nsName = name as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        let url = Bundle.module.url(forResource: base, withExtension: ext.isEmpty ? nil : ext, subdirectory: subdirectory)
            ?? Bundle.module.url(forResource: base, withExtension: ext.isEmpty ? nil : ext)
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
}

public enum Rite: String, CaseIterable, Hashable, Sendable, Identifiable {
    case ruthenian
    case western

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .ruthenian: "Byzantine Ruthenian"
        case .western: "Western"
        }
    }
}
