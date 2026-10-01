import Foundation

public enum AppearancePreference: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case dark, light, system

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "Match iPhone"
        }
    }
}

public enum PrayerTextSize: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case large, larger, largest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .large: "Large"
        case .larger: "Larger"
        case .largest: "Largest"
        }
    }
}

public enum SessionLength: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case oneDecade, fiveDecades, fullRosary

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .oneDecade: "One decade"
        case .fiveDecades: "Five decades"
        case .fullRosary: "Full Rosary"
        }
    }

    public func scope(decade: Int) -> SessionScope {
        switch self {
        case .oneDecade: .singleDecade(decade)
        case .fiveDecades: .fiveDecades
        case .fullRosary: .fullRosary
        }
    }
}

public struct AppSettings: Codable, Hashable, Sendable {
    public var defaultMode: PrayerMode = .guided
    public var defaultLength: SessionLength = .oneDecade
    public var openingIntentions = true
    public var seasonalSundays = false
    public var usesHolyGhost = false
    public var voiceTracking = true
    public var haptics = true
    /// AVSpeechUtterance rate (0...1, 0.5 is the system default).
    public var narrationRate = 0.42
    /// AVSpeechSynthesisVoice identifier; nil picks the best installed English voice.
    public var narratorVoiceID: String?
    /// Guided mode: seconds of quiet after a mystery is announced, to read the meditation.
    public var meditationPause: Double = 8
    public var appearance: AppearancePreference = .dark
    public var textSize: PrayerTextSize = .large
    public var family = FamilySettings()

    public init() {}

    public static let meditationPauseChoices: [(seconds: Double, title: String)] = [
        (3, "Short"), (8, "Medium"), (15, "Long"),
    ]

    enum CodingKeys: String, CodingKey {
        case defaultMode, defaultLength, openingIntentions, seasonalSundays, usesHolyGhost, voiceTracking
        case haptics, narrationRate, narratorVoiceID, meditationPause, appearance, textSize, family
    }

    /// Missing keys fall back to defaults so older saved settings keep loading.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        defaultMode = (try? c.decodeIfPresent(PrayerMode.self, forKey: .defaultMode)) ?? d.defaultMode
        defaultLength = (try? c.decodeIfPresent(SessionLength.self, forKey: .defaultLength)) ?? d.defaultLength
        openingIntentions = try c.decodeIfPresent(Bool.self, forKey: .openingIntentions) ?? d.openingIntentions
        seasonalSundays = try c.decodeIfPresent(Bool.self, forKey: .seasonalSundays) ?? d.seasonalSundays
        usesHolyGhost = try c.decodeIfPresent(Bool.self, forKey: .usesHolyGhost) ?? d.usesHolyGhost
        voiceTracking = try c.decodeIfPresent(Bool.self, forKey: .voiceTracking) ?? d.voiceTracking
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        narrationRate = try c.decodeIfPresent(Double.self, forKey: .narrationRate) ?? d.narrationRate
        narratorVoiceID = try c.decodeIfPresent(String.self, forKey: .narratorVoiceID)
        meditationPause = try c.decodeIfPresent(Double.self, forKey: .meditationPause) ?? d.meditationPause
        appearance = (try? c.decodeIfPresent(AppearancePreference.self, forKey: .appearance)) ?? d.appearance
        textSize = (try? c.decodeIfPresent(PrayerTextSize.self, forKey: .textSize)) ?? d.textSize
        family = try c.decodeIfPresent(FamilySettings.self, forKey: .family) ?? d.family
    }
}
