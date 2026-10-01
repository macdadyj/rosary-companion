#if os(iOS)
import AVFoundation
import Observation
import RosaryCore

/// The English voices installed on this iPhone, ranked by RosaryCore's VoiceCatalog.
enum InstalledVoices {
    static func catalog() -> VoiceCatalog {
        VoiceCatalog(
            installed: AVSpeechSynthesisVoice.speechVoices().map(VoiceInfo.init),
            preferredRegion: preferredRegion,
            systemDefaultID: systemDefault?.identifier
        )
    }

    /// The chosen voice while it's installed, otherwise the best installed one, otherwise
    /// whatever iOS reads English with.
    static func voice(selectedID: String?) -> AVSpeechSynthesisVoice? {
        catalog().voice(selectedID: selectedID).flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
            ?? systemDefault
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// The person's region when the iPhone is set to English, e.g. "GB".
    static var preferredRegion: String? {
        guard Locale.current.language.languageCode == .english else { return nil }
        return Locale.current.region?.identifier
    }

    private static var systemDefault: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "en-\(preferredRegion ?? "US")")
    }
}

extension VoiceInfo {
    init(_ voice: AVSpeechSynthesisVoice) {
        let quality: VoiceQuality
        switch voice.quality {
        case .premium: quality = .premium
        case .enhanced: quality = .enhanced
        default: quality = .standard
        }
        self.init(
            id: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality,
            isNovelty: voice.voiceTraits.contains(.isNoveltyVoice),
            isPersonal: voice.voiceTraits.contains(.isPersonalVoice)
        )
    }

    /// "United Kingdom", or the language tag if iOS has no name for it.
    var regionName: String {
        regionCode.flatMap { Locale.current.localizedString(forRegionCode: $0) } ?? language
    }
}

/// Reads a sample line in a given voice and pace, for the Settings screen.
@MainActor
@Observable
final class VoicePreview {
    enum Target: Hashable {
        case automatic
        case voice(String)
    }

    private(set) var playing: Target?

    @ObservationIgnored private let output = SpeechOutput(voice: nil)
    @ObservationIgnored private lazy var sequencer = NarrationSequencer(output: output)
    @ObservationIgnored private let audio = AudioSessionCoordinator()
    @ObservationIgnored private var generation = 0

    private static let sample: Narration = {
        let book = PrayerBook()
        return Narration([book.leaderPart(for: .hailMary), book.leaderPart(for: .gloryBe)].compactMap { $0 })
    }()

    func play(_ target: Target, pacing: SpeechPacing) {
        generation += 1
        let current = generation
        switch target {
        case .automatic: output.voice = InstalledVoices.voice(selectedID: nil)
        case .voice(let id): output.voice = InstalledVoices.voice(selectedID: id)
        }
        sequencer.planner = NarrationPlanner(pacing: pacing)
        audio.activate(listening: false)
        playing = target
        sequencer.speak(Self.sample, preDelay: 0) { [weak self] in
            guard let self, self.generation == current else { return }
            self.playing = nil
            self.audio.deactivate()
        }
    }

    func toggle(_ target: Target, pacing: SpeechPacing) {
        if playing == target { stop() } else { play(target, pacing: pacing) }
    }

    func stop() {
        sequencer.stop()
    }
}
#endif
