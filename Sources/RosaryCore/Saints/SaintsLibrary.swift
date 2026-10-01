import Foundation

/// One slot in the saints library. A slot is shown in the app only when `verified` is true and
/// it has both `text` and `source`; unverified slots are placeholders for a human to fill.
public struct SaintMeditation: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var saint: String
    /// The exact excerpt, or nil for a placeholder. Never a paraphrase.
    public var text: String?
    /// Work, chapter/section/paragraph or date, and translation.
    public var source: String?
    public var sourceURL: String?
    /// "public domain" or "short attributed excerpt"; placeholders may say "copyrighted" or "unknown".
    public var license: String
    public var verified: Bool
    public var verificationNote: String?
    /// Licensing details for whoever ships the app. Not shown to people praying.
    public var copyrightNote: String?
    /// Where the excerpt sits in the source, e.g. that it begins mid-paragraph.
    public var excerptNote: String?
    /// For placeholders: where a human might look for a suitable text.
    public var suggestedSource: String?

    public init(
        id: String,
        saint: String,
        text: String?,
        source: String?,
        sourceURL: String? = nil,
        license: String,
        verified: Bool,
        verificationNote: String? = nil,
        copyrightNote: String? = nil,
        excerptNote: String? = nil,
        suggestedSource: String? = nil
    ) {
        self.id = id
        self.saint = saint
        self.text = text
        self.source = source
        self.sourceURL = sourceURL
        self.license = license
        self.verified = verified
        self.verificationNote = verificationNote
        self.copyrightNote = copyrightNote
        self.excerptNote = excerptNote
        self.suggestedSource = suggestedSource
    }

    public var isDisplayable: Bool {
        verified && !(text?.isEmpty ?? true) && !(source?.isEmpty ?? true)
    }
}

public struct MysteryMeditations: Codable, Hashable, Sendable {
    public var mystery: MysteryID
    /// Original app text: a question to pray with. Always labelled as not a quotation.
    public var reflectionPrompt: String
    public var meditations: [SaintMeditation]
}

public enum MeditationCard: Hashable, Sendable {
    case quote(SaintMeditation)
    case reflection(String)
}

public struct SaintsLibrary: Hashable, Sendable {
    public struct File: Codable, Hashable, Sendable {
        public var schemaVersion: Int
        public var contentPolicy: String
        public var mysteries: [MysteryMeditations]
    }

    public let file: File
    private let byMystery: [MysteryID: MysteryMeditations]

    public init(file: File) {
        self.file = file
        self.byMystery = Dictionary(file.mysteries.map { ($0.mystery, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public init(data: Data) throws {
        try self.init(file: JSONDecoder().decode(File.self, from: data))
    }

    public static let empty = SaintsLibrary(file: File(schemaVersion: 1, contentPolicy: "", mysteries: []))

    public static func bundled() throws -> SaintsLibrary {
        guard let url = Bundle.module.url(forResource: "saints_meditations", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try SaintsLibrary(data: Data(contentsOf: url))
    }

    public func entry(for mystery: MysteryID) -> MysteryMeditations? {
        byMystery[mystery]
    }

    public func verifiedQuotes(for mystery: MysteryID) -> [SaintMeditation] {
        entry(for: mystery)?.meditations.filter(\.isDisplayable) ?? []
    }

    public func placeholders(for mystery: MysteryID) -> [SaintMeditation] {
        entry(for: mystery)?.meditations.filter { !$0.isDisplayable } ?? []
    }

    /// The card to show when a mystery is announced. Verified quotes take turns by day;
    /// without one, the reflection prompt is shown (labelled as not a quotation).
    public func card(for mystery: MysteryID, on day: CivilDate) -> MeditationCard? {
        let quotes = verifiedQuotes(for: mystery)
        if !quotes.isEmpty {
            let index = ((day.dayNumber % quotes.count) + quotes.count) % quotes.count
            return .quote(quotes[index])
        }
        return entry(for: mystery).map { .reflection($0.reflectionPrompt) }
    }

    /// Everything there is to meditate on for a mystery, starting with `card(for:on:)`: each
    /// verified quote once, in turn, then the reflection prompt. Placeholders never appear.
    /// Empty when the library has no entry for the mystery.
    public func cards(for mystery: MysteryID, on day: CivilDate) -> [MeditationCard] {
        guard let entry = entry(for: mystery) else { return [] }
        let quotes = verifiedQuotes(for: mystery)
        let start = quotes.isEmpty ? 0 : ((day.dayNumber % quotes.count) + quotes.count) % quotes.count
        let rotated = quotes[start...] + quotes[..<start]
        return rotated.map(MeditationCard.quote) + [.reflection(entry.reflectionPrompt)]
    }

    public var allUnverified: [(MysteryID, SaintMeditation)] {
        MysteryID.allCases.flatMap { id in placeholders(for: id).map { (id, $0) } }
    }
}
