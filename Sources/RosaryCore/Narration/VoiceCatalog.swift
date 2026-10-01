import Foundation

public enum VoiceQuality: Int, Comparable, CaseIterable, Hashable, Sendable {
    case standard = 1
    case enhanced
    case premium

    public static func < (lhs: VoiceQuality, rhs: VoiceQuality) -> Bool { lhs.rawValue < rhs.rawValue }

    public var title: String {
        switch self {
        case .standard: "Standard"
        case .enhanced: "Enhanced"
        case .premium: "Premium"
        }
    }
}

/// What the app needs to know about an installed text-to-speech voice
/// (mirrors the relevant parts of AVSpeechSynthesisVoice).
public struct VoiceInfo: Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// BCP 47 language tag, e.g. "en-GB".
    public var language: String
    public var quality: VoiceQuality
    public var isNovelty: Bool
    public var isPersonal: Bool

    public init(
        id: String, name: String, language: String, quality: VoiceQuality,
        isNovelty: Bool = false, isPersonal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.isNovelty = isNovelty
        self.isPersonal = isPersonal
    }

    public var languageCode: String {
        String(language.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? "").lowercased()
    }

    public var regionCode: String? {
        let pieces = language.split(whereSeparator: { $0 == "-" || $0 == "_" })
        return pieces.count > 1 ? String(pieces[pieces.count - 1]).uppercased() : nil
    }

    /// Eloquence voices (Eddy, Flo, Reed, ...) and the classic Mac voices (Fred, Ralph, ...)
    /// come from older synthesizers and sound robotic even at their best.
    public var isLegacySynthesizer: Bool {
        id.hasPrefix("com.apple.eloquence.") || id.hasPrefix("com.apple.speech.synthesis.voice.")
    }
}

/// The installed voices that suit reading the prayers, best first: Premium, then Enhanced, then
/// Standard. Within a quality, voices from the person's own region come first, then American
/// English (where most voices are), then the rest.
public struct VoiceCatalog: Hashable, Sendable {
    public let voices: [VoiceInfo]

    /// - Parameters:
    ///   - language: the language of the prayer texts.
    ///   - preferredRegion: the person's region, e.g. "GB"; nil prefers American English.
    ///   - systemDefaultID: the voice iOS uses for this language, which the person may have
    ///     chosen in Spoken Content settings; it wins ties.
    public init(
        installed: [VoiceInfo],
        language: String = "en",
        preferredRegion: String? = nil,
        systemDefaultID: String? = nil
    ) {
        let region = preferredRegion?.uppercased()
        func regionRank(_ voice: VoiceInfo) -> Int {
            if let region, voice.regionCode == region { return 0 }
            return voice.regionCode == "US" ? 1 : 2
        }
        var seen = Set<String>()
        voices = installed
            .filter { $0.languageCode == language && !$0.isNovelty && !$0.isPersonal && !$0.isLegacySynthesizer }
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
                if regionRank(lhs) != regionRank(rhs) { return regionRank(lhs) < regionRank(rhs) }
                if (lhs.id == systemDefaultID) != (rhs.id == systemDefaultID) { return lhs.id == systemDefaultID }
                if lhs.regionCode != rhs.regionCode { return (lhs.regionCode ?? "") < (rhs.regionCode ?? "") }
                if lhs.name != rhs.name { return lhs.name < rhs.name }
                return lhs.id < rhs.id
            }
    }

    /// The automatic choice. Nil when no suitable voice is installed, in which case the
    /// system's default voice for the language is used.
    public var best: VoiceInfo? { voices.first }

    /// The person's chosen voice if it's still installed and suitable, otherwise the automatic choice.
    public func voice(selectedID: String?) -> VoiceInfo? {
        if let selectedID, let chosen = voices.first(where: { $0.id == selectedID }) { return chosen }
        return best
    }

    /// False when only Standard voices are installed: worth suggesting a download.
    public var hasNaturalVoice: Bool {
        (best?.quality ?? .standard) >= .enhanced
    }

    public func voices(of quality: VoiceQuality) -> [VoiceInfo] {
        voices.filter { $0.quality == quality }
    }
}
