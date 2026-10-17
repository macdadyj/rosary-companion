import Foundation

public struct LectionaryDay: Codable, Hashable, Sendable {
    public var season: String
    public var celebration: String?
    public var firstReading: String?
    public var psalm: String?
    public var secondReading: String?
    public var gospel: String?

    public init(season: String, celebration: String? = nil, firstReading: String? = nil, psalm: String? = nil, secondReading: String? = nil, gospel: String? = nil) {
        self.season = season
        self.celebration = celebration
        self.firstReading = firstReading
        self.psalm = psalm
        self.secondReading = secondReading
        self.gospel = gospel
    }

    public var readings: [(label: String, citation: String)] {
        var rows: [(String, String)] = []
        if let firstReading { rows.append(("First Reading", firstReading)) }
        if let psalm { rows.append(("Psalm", psalm)) }
        if let secondReading { rows.append(("Second Reading", secondReading)) }
        if let gospel { rows.append(("Gospel", gospel)) }
        return rows
    }
}

/// Days saved after a refresh. The bundled calendar remains the offline copy.
public struct LectionaryOverlay: Codable, Sendable {
    public var days: [String: LectionaryDay]

    public init(days: [String: LectionaryDay]) {
        self.days = days
    }
}

/// Offline Mass citations for 2026 and 2027, with Challoner Douay-Rheims verses.
public struct LectionaryLibrary: Sendable {
    public let notice: String
    public let days: [String: LectionaryDay]
    private let verses: [String: [String: [String: String]]]

    public init(notice: String, days: [String: LectionaryDay], verses: [String: [String: [String: String]]], overlay: [String: LectionaryDay] = [:]) {
        self.notice = notice
        var merged = days
        for (key, day) in overlay { merged[key] = day }
        self.days = merged
        self.verses = verses
    }

    public static func bundled(overlay: [String: LectionaryDay] = [:]) throws -> LectionaryLibrary {
        let calendar = try load(LectionaryFile.self, name: "lectionary")
        let bible = try load(DouayFile.self, name: "douay")
        return LectionaryLibrary(notice: calendar.notice, days: calendar.days, verses: bible.books, overlay: overlay)
    }

    public func day(on date: CivilDate) -> LectionaryDay? {
        days[date.description]
    }

    /// Challoner text for a citation. Empty when the lectionary's verse numbers are not in the Douay-Rheims.
    public func text(for citation: String) -> String {
        let groups = ScriptureCitation.alternatives(in: citation)
        var blocks: [String] = []
        for group in groups {
            var lines: [String] = []
            for range in group {
                lines.append(contentsOf: verseLines(for: range))
            }
            if !lines.isEmpty {
                blocks.append(lines.joined(separator: "\n"))
            }
        }
        return blocks.joined(separator: "\n\nor\n\n")
    }

    private func verseLines(for range: ScriptureRange) -> [String] {
        guard let chapters = verses[range.book] else { return [] }
        var lines: [String] = []
        guard range.endChapter >= range.startChapter else { return [] }
        for chapter in range.startChapter...range.endChapter {
            guard let chapterVerses = chapters[String(chapter)] else { continue }
            let first = chapter == range.startChapter ? range.startVerse : 1
            let storedLast = chapterVerses.keys.compactMap(Int.init).max() ?? first
            let last = chapter == range.endChapter ? range.endVerse : storedLast
            guard last >= first else { continue }
            for verse in first...last {
                if let text = chapterVerses[String(verse)] {
                    lines.append("\(verse) \(text)")
                }
            }
        }
        return lines
    }

    private static func load<T: Decodable>(_ type: T.Type, name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json")
            ?? Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct LectionaryFile: Decodable {
    var notice: String
    var days: [String: LectionaryDay]
}

private struct DouayFile: Decodable {
    var notice: String
    var books: [String: [String: [String: String]]]
}
