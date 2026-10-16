import Foundation

/// Western painting or Byzantine / Eastern icon. Both are kept in the rotation.
public enum SacredArtTradition: String, Codable, Hashable, Sendable {
    case western
    case byzantine
}

/// A Wikimedia Commons category chosen for one mystery. The app does not search the open web.
public struct SacredArtCategory: Hashable, Sendable {
    public var mystery: MysteryID
    public var tradition: SacredArtTradition
    public var title: String

    public init(mystery: MysteryID, tradition: SacredArtTradition, title: String) {
        self.mystery = mystery
        self.tradition = tradition
        self.title = title
    }
}

/// One Commons file that might be shown for a mystery, before the reverence filter.
public struct SacredArtCandidate: Hashable, Sendable {
    public var mystery: MysteryID
    public var tradition: SacredArtTradition
    public var title: String
    public var artist: String
    public var license: String
    public var sourceURL: String
    public var thumbURL: String
    public var mime: String
    public var width: Int
    public var height: Int
    public var sha1: String
    public var summary: String

    public init(
        mystery: MysteryID,
        tradition: SacredArtTradition,
        title: String,
        artist: String,
        license: String,
        sourceURL: String,
        thumbURL: String,
        mime: String,
        width: Int,
        height: Int,
        sha1: String,
        summary: String
    ) {
        self.mystery = mystery
        self.tradition = tradition
        self.title = title
        self.artist = artist
        self.license = license
        self.sourceURL = sourceURL
        self.thumbURL = thumbURL
        self.mime = mime
        self.width = width
        self.height = height
        self.sha1 = sha1
        self.summary = summary
    }
}

/// Curated Commons categories and the rules that decide which files may be shown.
public enum SacredArtCatalog {
    /// Categories confirmed on Wikimedia Commons. Western paintings and Eastern icons are both listed.
    /// The proclamation uses two Western sermon categories; Commons has no separate icon category for it.
    public static let categories: [SacredArtCategory] = [
        .init(mystery: .annunciation, tradition: .western, title: "Category:Annunciation"),
        .init(mystery: .annunciation, tradition: .byzantine, title: "Category:Icons of Annunciation"),
        .init(mystery: .visitation, tradition: .western, title: "Category:Visitation (Bible)"),
        .init(mystery: .visitation, tradition: .byzantine, title: "Category:The Visitation (Pitzamanos)"),
        .init(mystery: .nativity, tradition: .western, title: "Category:Nativity of Jesus Christ"),
        .init(mystery: .nativity, tradition: .byzantine, title: "Category:Icons of the nativity of Jesus Christ"),
        .init(mystery: .presentation, tradition: .western, title: "Category:Presentation of Jesus Christ at the Temple"),
        .init(mystery: .presentation, tradition: .byzantine, title: "Category:Icons of the presentation of Jesus Christ at the Temple"),
        .init(mystery: .findingInTemple, tradition: .western, title: "Category:Jesus Christ among the doctors"),
        .init(mystery: .findingInTemple, tradition: .byzantine, title: "Category:Icons of Jesus Christ among the doctors"),
        .init(mystery: .baptism, tradition: .western, title: "Category:Baptism of Jesus Christ"),
        .init(mystery: .baptism, tradition: .byzantine, title: "Category:Icons of the baptism of Jesus Christ"),
        .init(mystery: .weddingAtCana, tradition: .western, title: "Category:Marriage at Cana"),
        .init(mystery: .weddingAtCana, tradition: .byzantine, title: "Category:Wedding at Cana (Damaskinos)"),
        .init(mystery: .proclamation, tradition: .western, title: "Category:Sermon on the Mount"),
        .init(mystery: .proclamation, tradition: .western, title: "Category:Paintings of the Sermon on the Mount"),
        .init(mystery: .transfiguration, tradition: .western, title: "Category:Transfiguration of Jesus Christ"),
        .init(mystery: .transfiguration, tradition: .byzantine, title: "Category:Icons of the transfiguration of Jesus Christ"),
        .init(mystery: .eucharist, tradition: .western, title: "Category:Last Supper"),
        .init(mystery: .eucharist, tradition: .byzantine, title: "Category:Icons of the Last Supper"),
        .init(mystery: .agonyInGarden, tradition: .western, title: "Category:Agony in the Garden"),
        .init(mystery: .agonyInGarden, tradition: .byzantine, title: "Category:Agony in the Garden in Orthodox art"),
        .init(mystery: .scourging, tradition: .western, title: "Category:Flagellation of Jesus Christ"),
        .init(mystery: .scourging, tradition: .byzantine, title: "Category:Icons of the flagellation of Jesus Christ"),
        .init(mystery: .crowningWithThorns, tradition: .western, title: "Category:Jesus Christ being crowned with thorns"),
        .init(mystery: .crowningWithThorns, tradition: .byzantine, title: "Category:Icons of the Man of Sorrows"),
        .init(mystery: .carryingCross, tradition: .western, title: "Category:Jesus Christ bearing the Cross"),
        .init(mystery: .carryingCross, tradition: .byzantine, title: "Category:Christ Bearing the Cross by Nikolaos Tzafouris"),
        .init(mystery: .crucifixion, tradition: .western, title: "Category:Crucifixion of Christ"),
        .init(mystery: .crucifixion, tradition: .byzantine, title: "Category:Icons of the crucifixion of Christ"),
        .init(mystery: .resurrection, tradition: .western, title: "Category:Resurrection of Christ"),
        .init(mystery: .resurrection, tradition: .byzantine, title: "Category:Icons of Resurrection of Christ"),
        .init(mystery: .ascension, tradition: .western, title: "Category:Ascension of Jesus Christ"),
        .init(mystery: .ascension, tradition: .byzantine, title: "Category:Icons of the Ascension of Christ"),
        .init(mystery: .descentOfHolySpirit, tradition: .western, title: "Category:Pentecost"),
        .init(mystery: .descentOfHolySpirit, tradition: .byzantine, title: "Category:Icons of Pentecost"),
        .init(mystery: .assumption, tradition: .western, title: "Category:Assumption of Mary"),
        .init(mystery: .assumption, tradition: .byzantine, title: "Category:Icons of Dormition of Virgin Mary"),
        .init(mystery: .coronation, tradition: .western, title: "Category:Coronation of Mary"),
        .init(mystery: .coronation, tradition: .byzantine, title: "Category:Icons of Coronation of Mary"),
    ]

    /// Words that tie a file to the mystery. Commons titles are often German, Italian, or Russian.
    public static func keywords(for mystery: MysteryID) -> [String] {
        switch mystery {
        case .annunciation:
            return ["annunciation", "verkündigung", "annunciazione", "благовещ"]
        case .visitation:
            return ["visitation", "heimsuchung", "visitazione"]
        case .nativity:
            return ["nativity", "natività", "geburt", "krippe", "рождество"]
        case .presentation:
            return ["presentation", "darstellung", "presentazione", "сретен", "simeon"]
        case .findingInTemple:
            return ["doctor", "doctore", "tempel", "temple", "schriftgelehrt"]
        case .baptism:
            return ["baptism", "taufe", "battesimo", "крещен", "jordan"]
        case .weddingAtCana:
            return ["cana", "kana", "hochzeit", "nozze"]
        case .proclamation:
            return ["sermon", "bergpredigt", "bergrede", "proclamation", "kingdom"]
        case .transfiguration:
            return ["transfiguration", "verklärung", "trasfigurazione", "преображен", "tabor"]
        case .eucharist:
            return ["last supper", "abendmahl", "ultima cena", "eucharist", "тайная"]
        case .agonyInGarden:
            return ["agony", "gethsemane", "ölberg", "olberg", "гефсиман", "olive", "chashe", "molenie"]
        case .scourging:
            return ["flagellation", "scourging", "geißel", "geissel", "flagellazione", "бичеван"]
        case .crowningWithThorns:
            return ["thorn", "dornen", "spine", "терн", "man of sorrows", "tapeinosis"]
        case .carryingCross:
            return ["bearing the cross", "carrying the cross", "kreuztragung", "portement", "via dolorosa", "way of the cross"]
        case .crucifixion:
            return ["crucifix", "kreuzigung", "crocifissione", "распят", "calvary", "golgotha"]
        case .resurrection:
            return ["resurrection", "auferstehung", "resurrezione", "воскресен"]
        case .ascension:
            return ["ascension", "himmelfahrt", "ascensione", "вознесен"]
        case .descentOfHolySpirit:
            return ["pentecost", "pfingsten", "pentecoste", "пятидесят"]
        case .assumption:
            return ["assumption", "dormition", "himmelfahrt mari", "entschlaf", "успени", "koimesis"]
        case .coronation:
            return ["coronation", "krönung", "incoronazione", "коронован", "queen of heaven"]
        }
    }

    public static func categories(for mystery: MysteryID) -> [SacredArtCategory] {
        categories.filter { $0.mystery == mystery }
    }
}

public enum SacredArtText {
    /// Commons artist and description fields are HTML.
    public static func plain(_ html: String) -> String {
        var result = ""
        var inTag = false
        for character in html {
            if character == "<" {
                inTag = true
                continue
            }
            if character == ">" {
                inTag = false
                result.append(" ")
                continue
            }
            if !inTag { result.append(character) }
        }
        var text = result
        let entities = [
            ("&nbsp;", " "), ("&#160;", " "), ("&amp;", "&"), ("&quot;", "\""),
            ("&#39;", "'"), ("&apos;", "'"), ("&lt;", "<"), ("&gt;", ">"),
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func fileTitle(_ commonsTitle: String) -> String {
        var title = commonsTitle
        if title.hasPrefix("File:") { title.removeFirst(5) }
        if let dot = title.lastIndex(of: "."), title.distance(from: dot, to: title.endIndex) <= 5 {
            title = String(title[..<dot])
        }
        return title.replacingOccurrences(of: "_", with: " ")
    }
}

public enum SacredArtFilter {
    /// Public domain and free licenses. Non-commercial and no-derivatives licenses stay out.
    public static func licenseIsOpen(_ name: String) -> Bool {
        let value = name.lowercased()
        guard !value.isEmpty else { return false }
        let blocked = [
            "noncommercial", "non-commercial", "-nc", " nc",
            "noderiv", "no deriv", "-nd",
            "fair use", "all rights", "copyrighted", "incopyright",
        ]
        if blocked.contains(where: { value.contains($0) }) { return false }
        if value == "pd" || value.hasPrefix("pd ") || value.hasPrefix("pd-") { return true }
        let allowed = ["public domain", "pdm", "cc0", "cc by", "cc-by", "gfdl", "no restrictions"]
        return allowed.contains(where: { value.contains($0) })
    }

    public static func accepts(_ candidate: SacredArtCandidate) -> Bool {
        guard licenseIsOpen(candidate.license) else { return false }
        guard ["image/jpeg", "image/png", "image/webp"].contains(candidate.mime) else { return false }
        guard candidate.width >= 320, candidate.height >= 320 else { return false }
        let longSide = max(candidate.width, candidate.height)
        let shortSide = min(candidate.width, candidate.height)
        guard longSide >= 480, shortSide * 4 >= longSide else { return false }
        guard candidate.thumbURL.lowercased().hasPrefix("https://") else { return false }
        let haystack = SacredArtText.plain(
            [candidate.title, candidate.summary].joined(separator: " ")
        ).lowercased()
        if isIrreverentOrIrrelevant(haystack) { return false }
        let keywords = SacredArtCatalog.keywords(for: candidate.mystery)
        return keywords.contains { haystack.contains($0) }
    }

    private static func isIrreverentOrIrrelevant(_ text: String) -> Bool {
        let blocked = [
            "meme", "cartoon", "comic", "manga", "anime", "parody", "satire", "selfie",
            "cosplay", "fan art", "fanart", "joke", "protest", "advertisement", "graffiti",
            "porn", "erotic", "nude", "naked", "blasphem", "halloween", "costume",
            "lego", "playmobil", "screenshot", "postage", "banknote", "floor plan",
            "ground plan", "diagram", "coin ", "medal", "sermon preached", "early-english-books",
            "google books", ".pdf", "fassade", "facade", "exterior of", "interior of the church",
            "church interior", "map of",
        ]
        return blocked.contains { text.contains($0) }
    }
}

/// Reads a Commons `prop=imageinfo` response. No network.
public enum CommonsCatalogParser {
    public static func candidates(
        in data: Data,
        mystery: MysteryID,
        tradition: SacredArtTradition
    ) -> [SacredArtCandidate] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = root["query"] as? [String: Any],
              let pages = query["pages"] as? [String: Any] else { return [] }
        return pages.values.compactMap { value in
            guard let page = value as? [String: Any] else { return nil }
            return candidate(page: page, mystery: mystery, tradition: tradition)
        }
    }

    private static func candidate(
        page: [String: Any],
        mystery: MysteryID,
        tradition: SacredArtTradition
    ) -> SacredArtCandidate? {
        guard let rawTitle = page["title"] as? String,
              let infos = page["imageinfo"] as? [[String: Any]],
              let info = infos.first,
              let thumb = info["thumburl"] as? String,
              let mime = info["mime"] as? String,
              let sha1 = info["sha1"] as? String,
              !sha1.isEmpty else { return nil }
        let width = intValue(info["width"])
        let height = intValue(info["height"])
        let meta = info["extmetadata"] as? [String: Any] ?? [:]
        let license = metaValue(meta, "LicenseShortName")
        let artist = SacredArtText.plain(metaValue(meta, "Artist"))
        let summary = SacredArtText.plain(metaValue(meta, "ImageDescription"))
        let source = (info["descriptionurl"] as? String) ?? ""
        let resolvedTradition = traditionOf(title: rawTitle, summary: summary, fallback: tradition)
        return SacredArtCandidate(
            mystery: mystery,
            tradition: resolvedTradition,
            title: SacredArtText.fileTitle(rawTitle),
            artist: artist,
            license: license,
            sourceURL: source,
            thumbURL: thumb,
            mime: mime,
            width: width,
            height: height,
            sha1: sha1,
            summary: summary
        )
    }

    private static func intValue(_ value: Any?) -> Int {
        if let number = value as? NSNumber { return number.intValue }
        return 0
    }

    private static func metaValue(_ meta: [String: Any], _ key: String) -> String {
        guard let entry = meta[key] as? [String: Any] else { return "" }
        return entry["value"] as? String ?? ""
    }

    /// A file from a mixed category is treated as an icon when its title says so.
    private static func traditionOf(title: String, summary: String, fallback: SacredArtTradition) -> SacredArtTradition {
        let text = (title + " " + summary).lowercased()
        if text.contains("icon") || text.contains("икона") || text.contains("byzantine") { return .byzantine }
        return fallback
    }
}

public enum SacredArtImageKind {
    public static func isRasterImage(_ data: Data) -> Bool {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return true }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        guard data.count >= 12 else { return false }
        return data.prefix(4) == Data("RIFF".utf8) && data.subdata(in: 8..<12) == Data("WEBP".utf8)
    }
}
