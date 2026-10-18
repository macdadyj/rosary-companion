import Foundation

/// Plays one `NarrationItem` at a time. On iOS this is AVSpeechSynthesizer for phrases and
/// AVAudioPlayer for recordings; tests use a fake.
@MainActor
public protocol NarrationOutput: AnyObject {
    /// Calls `completion` when the item and its pause are over: `true` if it played, `false` if
    /// it couldn't (an unreadable recording, say). Calls that arrive after `stop()` are ignored.
    func play(_ item: NarrationItem, preDelay: TimeInterval, completion: @escaping @MainActor (_ played: Bool) -> Void)
    func stop()
    /// Hold the current utterance. The completion stays pending.
    func pause()
    /// Continue an utterance held by `pause()`.
    func resume()
}

/// The app's narrator: plans each narration into items and plays them in order, reporting
/// completion exactly once. A recording that fails to play is replaced by synthesized speech.
@MainActor
public final class NarrationSequencer: SpeechNarrating {
    public var planner: NarrationPlanner

    private let output: NarrationOutput
    private var queue: [NarrationItem] = []
    private var completion: (@MainActor () -> Void)?
    private var generation = 0

    public init(output: NarrationOutput, planner: NarrationPlanner = NarrationPlanner()) {
        self.output = output
        self.planner = planner
    }

    public var isSpeaking: Bool { completion != nil }

    /// A narration with nothing to say completes immediately.
    public func speak(_ narration: Narration, preDelay: TimeInterval, completion: @escaping @MainActor () -> Void) {
        if isSpeaking { stop() }
        generation += 1
        queue = planner.items(for: narration)
        self.completion = completion
        playNext(preDelay: preDelay, generation: generation)
    }

    public func stop() {
        generation += 1
        queue.removeAll()
        output.stop()
        finish()
    }

    /// Holds the voice without dropping the queue or the completion.
    public func pause() {
        output.pause()
    }

    public func resume() {
        output.resume()
    }

    private func playNext(preDelay: TimeInterval, generation: Int) {
        guard generation == self.generation else { return }
        guard !queue.isEmpty else {
            finish()
            return
        }
        let item = queue.removeFirst()
        output.play(item, preDelay: preDelay) { [weak self] played in
            guard let self, generation == self.generation else { return }
            if !played, case .recording(_, let fallback, _) = item {
                self.queue.insert(contentsOf: fallback.map(NarrationItem.synthesized), at: 0)
                self.playNext(preDelay: preDelay, generation: generation)
            } else {
                self.playNext(preDelay: 0, generation: generation)
            }
        }
    }

    private func finish() {
        let done = completion
        completion = nil
        done?()
    }
}
