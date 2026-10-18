import Foundation
import Testing
@testable import RosaryCore

@MainActor
final class FakeNarrationOutput: NarrationOutput {
    struct Call {
        let item: NarrationItem
        let preDelay: TimeInterval
        let completion: @MainActor (Bool) -> Void
    }

    private(set) var calls: [Call] = []
    private(set) var stops = 0

    var items: [NarrationItem] { calls.map(\.item) }

    func play(_ item: NarrationItem, preDelay: TimeInterval, completion: @escaping @MainActor (Bool) -> Void) {
        calls.append(Call(item: item, preDelay: preDelay, completion: completion))
    }

    func stop() { stops += 1 }

    func pause() {}

    func resume() {}

    /// Finishes the most recent item, as the speech synthesizer or audio player would.
    func finish(played: Bool = true) {
        calls.last?.completion(played)
    }

    /// Delivers a completion for an earlier item, e.g. one that arrives after `stop()`.
    func complete(call index: Int, played: Bool = true) {
        calls[index].completion(played)
    }
}

/// Pretends every fixed wording has been recorded.
struct EveryClipRecorded: NarrationRecordings {
    func recording(for clip: NarrationClip) -> URL? {
        URL(fileURLWithPath: "/recordings/\(clip.fileName).m4a")
    }
}

@MainActor
@Suite("Narration sequencer")
struct NarrationSequencerTests {
    let book = PrayerBook()

    private var faithHailMary: Narration {
        Narration([OpeningIntention.faith.spokenPart, book.leaderPart(for: .hailMary)!])
    }

    @Test func playsEachItemInOrderWithThePreDelayOnlyBeforeTheFirst() {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output)
        var completions = 0
        sequencer.speak(faithHailMary, preDelay: 0.8) { completions += 1 }

        #expect(sequencer.isSpeaking)
        #expect(output.calls.map(\.preDelay) == [0.8])
        output.finish()
        output.finish()
        #expect(completions == 0)
        output.finish()

        #expect(output.items == sequencer.planner.items(for: faithHailMary))
        #expect(output.calls.map(\.preDelay) == [0.8, 0, 0])
        #expect(completions == 1)
        #expect(!sequencer.isSpeaking)
    }

    @Test func stoppingMidNarrationCompletesOnceAndIgnoresLateCallbacks() {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output)
        var completions = 0
        sequencer.speak(faithHailMary, preDelay: 0) { completions += 1 }
        output.finish()

        sequencer.stop()
        #expect(completions == 1)
        #expect(output.stops == 1)
        #expect(!sequencer.isSpeaking)

        output.complete(call: 1)
        sequencer.stop()
        #expect(output.calls.count == 2, "nothing more is played after stop")
        #expect(completions == 1)
    }

    @Test func aRecordingThatCannotPlayFallsBackToSpeechWithTheSameDelay() throws {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output, planner: NarrationPlanner(recordings: EveryClipRecorded()))
        var completions = 0
        let hailMary = Narration([book.leaderPart(for: .hailMary)!])
        sequencer.speak(hailMary, preDelay: 0.5) { completions += 1 }

        guard case .recording(_, let fallback, _) = output.items.first else {
            Issue.record("expected the recording to be tried first")
            return
        }
        output.finish(played: false)
        #expect(output.items.last == .synthesized(fallback[0]))
        #expect(output.calls.last?.preDelay == 0.5)

        for _ in fallback { output.finish() }
        #expect(output.items.dropFirst() == ArraySlice(fallback.map(NarrationItem.synthesized)))
        #expect(completions == 1)
    }

    @Test func aRecordingThatPlaysIsNotRepeatedBySpeech() {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output, planner: NarrationPlanner(recordings: EveryClipRecorded()))
        var completions = 0
        sequencer.speak(faithHailMary, preDelay: 0) { completions += 1 }
        output.finish()
        output.finish()
        #expect(output.calls.count == 2)
        #expect(completions == 1)
    }

    @Test func speakingAgainStopsTheCurrentNarrationFirst() {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output)
        var first = 0
        var second = 0
        sequencer.speak(faithHailMary, preDelay: 0) { first += 1 }
        sequencer.speak(Narration("Mom leads the next decade."), preDelay: 0) { second += 1 }

        #expect(first == 1)
        #expect(output.stops == 1)
        output.complete(call: 0)
        #expect(output.calls.count == 2, "the first narration's late callback is ignored")

        output.finish()
        #expect(second == 1)
        #expect(first == 1)
    }

    @Test func aNarrationWithNothingToSayCompletesImmediately() {
        let output = FakeNarrationOutput()
        let sequencer = NarrationSequencer(output: output)
        var completions = 0
        sequencer.speak(Narration("  "), preDelay: 1) { completions += 1 }
        #expect(completions == 1)
        #expect(output.calls.isEmpty)
        #expect(!sequencer.isSpeaking)
    }

    private func makeGuidedController() -> (SessionController, FakeNarrationOutput, FakeListener) {
        let output = FakeNarrationOutput()
        let listener = FakeListener()
        var now = 0.0
        let controller = SessionController(
            configuration: SessionConfiguration(scope: .singleDecade(2), mysterySet: .sorrowful, mode: .guided),
            listener: listener,
            narrator: NarrationSequencer(output: output),
            haptics: FakeHaptics(),
            clock: {
                now += 1
                return now
            }
        )
        return (controller, output, listener)
    }

    @Test func guidedSessionWaitsForEveryPhraseOfTheAnnouncement() {
        let (controller, output, _) = makeGuidedController()
        controller.start(autoTick: false)
        #expect(output.items.count == 1)
        #expect(controller.snapshot.phase == .speaking)

        output.finish()
        #expect(output.items.count == 2, "\"The Second Sorrowful Mystery:\" and its title, with a pause between")
        #expect(controller.snapshot.phase == .speaking)
        output.finish()
        #expect(controller.snapshot.phase == .holding)
    }

    @Test func tappingThroughTheSequencerAdvancesExactlyOnce() {
        let (controller, output, _) = makeGuidedController()
        controller.start(autoTick: false)
        controller.tap()
        #expect(controller.snapshot.title == "Our Father")
        #expect(output.stops >= 1)

        let ourFatherStart = output.calls.count - 1
        output.complete(call: 0)
        #expect(controller.snapshot.title == "Our Father")
        #expect(controller.snapshot.phase == .speaking)
        #expect(output.calls.count == ourFatherStart + 1)
    }
}
