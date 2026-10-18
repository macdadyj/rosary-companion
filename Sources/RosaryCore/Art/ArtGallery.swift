import Foundation

/// One painting in the full-screen viewer. Bundled works and cached Commons files share this shape.
public struct ArtPlate: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
        case bundled
        case cached(fileName: String)
    }

    public var id: String
    public var mystery: MysteryID
    public var title: String
    public var artist: String
    public var date: String
    public var source: String
    public var caption: String
    public var sha1: String
    public var kind: Kind

    public init(
        id: String,
        mystery: MysteryID,
        title: String,
        artist: String,
        date: String,
        source: String,
        caption: String,
        sha1: String,
        kind: Kind
    ) {
        self.id = id
        self.mystery = mystery
        self.title = title
        self.artist = artist
        self.date = date
        self.source = source
        self.caption = caption
        self.sha1 = sha1
        self.kind = kind
    }
}

public enum ArtCaption {
    /// The first four-digit year in a title or credit line, when the catalogue has no separate date.
    public static func year(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\b(?:1[0-9]{3}|20[0-9]{2})\b"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let found = Range(match.range, in: text) else { return nil }
        return String(text[found])
    }

    /// Title, artist, date, and source, skipping anything blank.
    public static func line(title: String, artist: String, date: String, source: String) -> String {
        [title, artist, date, source]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// The paintings for every mystery, in mystery order, with a wrap-around page index.
public struct ArtGallery: Hashable, Sendable {
    public var plates: [ArtPlate]
    public var index: Int

    public init(plates: [ArtPlate], index: Int = 0) {
        self.plates = plates
        if plates.isEmpty {
            self.index = 0
        } else {
            let wrapped = ((index % plates.count) + plates.count) % plates.count
            self.index = wrapped
        }
    }

    public var plate: ArtPlate? {
        plates.indices.contains(index) ? plates[index] : nil
    }

    public var positionLabel: String {
        guard !plates.isEmpty else { return "" }
        return "\(index + 1) of \(plates.count)"
    }

    public func stepped(_ delta: Int) -> ArtGallery {
        guard !plates.isEmpty else { return self }
        return ArtGallery(plates: plates, index: index + delta)
    }

    /// Bundled work first within each mystery, then cached records by title. A repeated file is kept once.
    public static func assemble(works: [SacredWork], records: [SacredArtRecord], focus: MysteryID) -> ArtGallery {
        var plates: [ArtPlate] = []
        var seen = Set<String>()
        func unseen(_ sha: String) -> Bool {
            let key = sha.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return true }
            return seen.insert(key).inserted
        }
        for mystery in MysteryID.allCases {
            if let work = works.first(where: { $0.mystery == mystery }) {
                let sha = work.commonsSha1.isEmpty ? work.sha1 : work.commonsSha1
                if unseen(sha) {
                    plates.append(bundled(work))
                }
            }
            let cached = records
                .filter { $0.mystery == mystery }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            for record in cached where unseen(record.sha1) {
                plates.append(cachedPlate(record))
            }
        }
        let focusIndex = plates.firstIndex { $0.mystery == focus } ?? 0
        return ArtGallery(plates: plates, index: focusIndex)
    }

    private static func bundled(_ work: SacredWork) -> ArtPlate {
        let date = ArtCaption.year(in: work.title) ?? ArtCaption.year(in: work.credit) ?? ""
        return ArtPlate(
            id: "bundled-\(work.mystery.rawValue)",
            mystery: work.mystery,
            title: work.title,
            artist: work.artist,
            date: date,
            source: work.license,
            caption: ArtCaption.line(title: work.title, artist: work.artist, date: date, source: work.license),
            sha1: work.commonsSha1.isEmpty ? work.sha1 : work.commonsSha1,
            kind: .bundled
        )
    }

    private static func cachedPlate(_ record: SacredArtRecord) -> ArtPlate {
        let date = ArtCaption.year(in: record.title) ?? ArtCaption.year(in: record.creditLine) ?? ""
        return ArtPlate(
            id: record.sha1,
            mystery: record.mystery,
            title: record.title,
            artist: record.artist,
            date: date,
            source: "Wikimedia Commons",
            caption: ArtCaption.line(title: record.title, artist: record.artist, date: date, source: "Wikimedia Commons"),
            sha1: record.sha1,
            kind: .cached(fileName: record.fileName)
        )
    }
}
