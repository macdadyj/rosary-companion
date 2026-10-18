#if os(iOS)
import AVFoundation
import RosaryCore

/// Plays narration on the iPhone: phrases with an on-device voice, recorded prayers with
/// AVAudioPlayer. One item at a time; the pause after each item is timed here so that speech
/// and recordings breathe the same way.
@MainActor
final class SpeechOutput: NSObject, NarrationOutput {
    var voice: AVSpeechSynthesisVoice?

    private let synthesizer = AVSpeechSynthesizer()
    private var utterance: AVSpeechUtterance?
    private var player: AVAudioPlayer?
    private var completion: (@MainActor (Bool) -> Void)?
    private var pauseAfter: TimeInterval = 0
    private var pauseTask: Task<Void, Never>?
    private var held = false

    init(voice: AVSpeechSynthesisVoice?) {
        self.voice = voice
        super.init()
        synthesizer.delegate = self
    }

    func play(_ item: NarrationItem, preDelay: TimeInterval, completion: @escaping @MainActor (Bool) -> Void) {
        stop()
        self.completion = completion
        switch item {
        case .synthesized(let phrase):
            pauseAfter = phrase.pauseAfter
            let utterance = AVSpeechUtterance(string: phrase.text)
            utterance.voice = voice
            utterance.rate = min(max(Float(phrase.rate), AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
            utterance.pitchMultiplier = Float(phrase.pitch)
            utterance.preUtteranceDelay = preDelay
            self.utterance = utterance
            synthesizer.speak(utterance)
        case .recording(let url, _, let pause):
            pauseAfter = pause
            guard let player = try? AVAudioPlayer(contentsOf: url), player.prepareToPlay() else {
                finish(played: false)
                return
            }
            player.delegate = self
            self.player = player
            let started = preDelay > 0 ? player.play(atTime: player.deviceCurrentTime + preDelay) : player.play()
            if !started { finish(played: false) }
        }
    }

    /// Silences everything at once. The pending completion is dropped, as `NarrationOutput` allows.
    func stop() {
        held = false
        completion = nil
        pauseTask?.cancel()
        pauseTask = nil
        if utterance != nil {
            utterance = nil
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.stop()
        player = nil
    }

    /// Holds the current phrase. The completion stays pending so the sequencer can continue later.
    func pause() {
        held = true
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            return
        }
        if player?.isPlaying == true {
            player?.pause()
            return
        }
        pauseTask?.cancel()
        pauseTask = nil
    }

    func resume() {
        guard held else { return }
        held = false
        if synthesizer.isPaused || synthesizer.isSpeaking {
            synthesizer.continueSpeaking()
            return
        }
        if let player, !player.isPlaying {
            player.play()
            return
        }
        pauseAfter = 0
        finish(played: true)
    }

    private func finish(played: Bool) {
        guard let completion else { return }
        self.completion = nil
        utterance = nil
        player = nil
        guard played, pauseAfter > 0 else {
            completion(played)
            return
        }
        let pause = pauseAfter
        pauseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { return }
            completion(true)
        }
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        guard let utterance, ObjectIdentifier(utterance) == id else { return }
        finish(played: true)
    }

    private func playerEnded(_ id: ObjectIdentifier, played: Bool) {
        guard let player, ObjectIdentifier(player) == id else { return }
        finish(played: played)
    }
}

extension SpeechOutput: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }
}

extension SpeechOutput: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.playerEnded(id, played: flag) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let id = ObjectIdentifier(player)
        Task { @MainActor in self.playerEnded(id, played: false) }
    }
}
#endif
