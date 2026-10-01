#if os(iOS)
import AVFoundation
import RosaryCore

/// Reads the leader parts aloud with an on-device voice.
@MainActor
final class NarratorService: NSObject, SpeechNarrating {
    private let synthesizer = AVSpeechSynthesizer()
    private var completions: [ObjectIdentifier: @MainActor () -> Void] = [:]
    private var voice: AVSpeechSynthesisVoice?
    private var rate: Float

    init(voiceID: String?, rate: Double) {
        self.rate = Float(rate)
        super.init()
        synthesizer.delegate = self
        voice = Self.voice(id: voiceID)
    }

    func configure(voiceID: String?, rate: Double) {
        self.rate = Float(rate)
        voice = Self.voice(id: voiceID)
    }

    func speak(_ text: String, preDelay: TimeInterval, completion: @escaping @MainActor () -> Void) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.pitchMultiplier = 0.95
        utterance.preUtteranceDelay = preDelay
        utterance.postUtteranceDelay = 0.15
        completions[ObjectIdentifier(utterance)] = completion
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        let pending = completions
        completions.removeAll()
        for completion in pending.values { completion() }
    }

    private func finished(_ id: ObjectIdentifier) {
        completions.removeValue(forKey: id)?()
    }

    /// The chosen voice, or the best installed English voice (premium, then enhanced).
    static func voice(id: String?) -> AVSpeechSynthesisVoice? {
        if let id, let chosen = AVSpeechSynthesisVoice(identifier: id) { return chosen }
        let candidates = availableVoices()
        let preferredLanguage = Locale.current.language.languageCode == .english
            ? Locale.current.identifier(.bcp47) : "en-US"
        let local = candidates.filter { $0.language == preferredLanguage }
        let pool = local.isEmpty ? candidates : local
        return pool.first { $0.quality == .premium }
            ?? pool.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: preferredLanguage)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Installed English voices, without novelty or personal voices.
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.name < rhs.name
            }
    }
}

extension NarratorService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.finished(id) }
    }
}
#endif
