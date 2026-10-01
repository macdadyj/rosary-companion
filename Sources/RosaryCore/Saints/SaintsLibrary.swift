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
    /// "public domain" or "short attributed excerpt" (or "unknown" for placeholders).
    public var license: String
    public var verified: Bool
    public var verificationNote: String?
    public var copyrightNote: String?
    /// For placeholders: where a human might look for a suitable text.
    public var suggestedSource: String?

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

    public var allUnverified: [(MysteryID, SaintMeditation)] {
        MysteryID.allCases.flatMap { id in placeholders(for: id).map { (id, $0) } }
    }
}
