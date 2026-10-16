import Foundation

/// A sacred image kept on disk so a decade can open with no network.
public struct SacredArtRecord: Codable, Hashable, Sendable, Identifiable {
    public var mystery: MysteryID
    public var tradition: SacredArtTradition
    public var title: String
    public var artist: String
    public var license: String
    public var sourceURL: String
    public var sha1: String
    public var fileName: String
    public var savedAt: Date

    public var id: String { sha1 }

    public init(
        mystery: MysteryID,
        tradition: SacredArtTradition,
        title: String,
        artist: String,
        license: String,
        sourceURL: String,
        sha1: String,
        fileName: String,
        savedAt: Date
    ) {
        self.mystery = mystery
        self.tradition = tradition
        self.title = title
        self.artist = artist
        self.license = license
        self.sourceURL = sourceURL
        self.sha1 = sha1
        self.fileName = fileName
        self.savedAt = savedAt
    }

    public var creditLine: String {
        let painter = artist.isEmpty ? "Artist not named on the file" : artist
        return "\(title). \(painter). \(license). Wikimedia Commons."
    }
}

public struct SacredArtIndex: Codable, Hashable, Sendable {
    public var refreshedAt: Date?
    public var records: [SacredArtRecord]
    /// How many times someone asked for another image of this mystery.
    public var offsets: [String: Int]

    public init(refreshedAt: Date? = nil, records: [SacredArtRecord] = [], offsets: [String: Int] = [:]) {
        self.refreshedAt = refreshedAt
        self.records = records
        self.offsets = offsets
    }

    public static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    public static let limitPerMystery = 8

    public static func shouldRefresh(refreshedAt: Date?, now: Date, interval: TimeInterval = refreshInterval) -> Bool {
        guard let refreshedAt else { return true }
        return now.timeIntervalSince(refreshedAt) >= interval
    }

    /// Alternates Western and Byzantine works, then walks one step per day plus any hand advances.
    public func choice(for mystery: MysteryID, on day: CivilDate) -> SacredArtRecord? {
        let ordered = SacredArtRotation.order(records.filter { $0.mystery == mystery })
        guard !ordered.isEmpty else { return nil }
        let offset = offsets[mystery.rawValue] ?? 0
        let slot = day.dayNumber + offset
        let index = slot % ordered.count
        let normalized = index >= 0 ? index : index + ordered.count
        return ordered[normalized]
    }

    public func advanced(mystery: MysteryID) -> SacredArtIndex {
        var copy = self
        copy.offsets[mystery.rawValue, default: 0] += 1
        return copy
    }

    /// Keeps the newest distinct files, capped per mystery, with both traditions when they exist.
    public func merging(_ incoming: [SacredArtRecord], now: Date) -> SacredArtIndex {
        var copy = self
        var combined = records
        for record in incoming where !combined.contains(where: { $0.sha1 == record.sha1 }) {
            combined.append(record)
        }
        var kept: [SacredArtRecord] = []
        for mystery in MysteryID.allCases {
            let mine = combined.filter { $0.mystery == mystery }.sorted { $0.savedAt > $1.savedAt }
            kept.append(contentsOf: Array(SacredArtRotation.order(mine).prefix(Self.limitPerMystery)))
        }
        copy.records = kept
        copy.refreshedAt = now
        return copy
    }
}

public enum SacredArtRotation {
    /// Western, then Byzantine, so the two traditions take turns across the week.
    public static func order(_ records: [SacredArtRecord]) -> [SacredArtRecord] {
        let western = records.filter { $0.tradition == .western }.sorted { $0.sha1 < $1.sha1 }
        let byzantine = records.filter { $0.tradition == .byzantine }.sorted { $0.sha1 < $1.sha1 }
        var mixed: [SacredArtRecord] = []
        let count = max(western.count, byzantine.count)
        for index in 0..<count {
            if index < western.count { mixed.append(western[index]) }
            if index < byzantine.count { mixed.append(byzantine[index]) }
        }
        return mixed
    }
}

public struct SacredArtStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var indexURL: URL { directory.appendingPathComponent("index.json") }
    public var imagesURL: URL { directory.appendingPathComponent("images", isDirectory: true) }

    public func load() -> SacredArtIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? Self.decoder.decode(SacredArtIndex.self, from: data) else {
            return SacredArtIndex()
        }
        return index
    }

    public func save(_ index: SacredArtIndex) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
    }

    public func imageData(fileName: String) -> Data? {
        guard Self.isSafeFileName(fileName) else { return nil }
        return try? Data(contentsOf: imagesURL.appendingPathComponent(fileName))
    }

    public func writeImage(_ data: Data, sha1: String, mime: String) throws -> String? {
        guard SacredArtImageKind.isRasterImage(data), let fileName = Self.fileName(sha1: sha1, mime: mime) else {
            return nil
        }
        try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        try data.write(to: imagesURL.appendingPathComponent(fileName), options: .atomic)
        return fileName
    }

    public static func fileName(sha1: String, mime: String) -> String? {
        let hex = sha1.lowercased()
        guard (8...64).contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
        let ext: String
        switch mime {
        case "image/png": ext = "png"
        case "image/webp": ext = "webp"
        case "image/jpeg": ext = "jpg"
        default: ext = "jpg"
        }
        return "\(hex).\(ext)"
    }

    public static func isSafeFileName(_ name: String) -> Bool {
        guard let dot = name.lastIndex(of: ".") else { return false }
        let stem = name[..<dot]
        let ext = name[name.index(after: dot)...]
        guard ["jpg", "png", "webp"].contains(ext) else { return false }
        return (8...64).contains(stem.count) && stem.allSatisfy(\.isHexDigit)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

public enum CommonsArtRequest {
    public static let userAgent = "RosaryCompanion/1.0 (https://github.com/macdadyj/rosary-companion; sacred-art)"

    public static func categoryURL(_ category: String, limit: Int = 12) -> URL? {
        var parts = URLComponents(string: "https://commons.wikimedia.org/w/api.php")
        parts?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "categorymembers"),
            URLQueryItem(name: "gcmtitle", value: category),
            URLQueryItem(name: "gcmtype", value: "file"),
            URLQueryItem(name: "gcmlimit", value: String(limit)),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|size|mime|sha1|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: "960"),
        ]
        return parts?.url
    }
}
