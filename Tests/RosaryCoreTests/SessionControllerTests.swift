import Testing
@testable import RosaryCore

@MainActor
final class FakeListener: SpeechListening {
    var availability: ListenerAvailability = .ready
    var onTranscript: (@MainActor (TranscriptUpdate) -> Void)?
    var onAvailabilityChange: (@MainActor (ListenerAvailability) -> Void)?
    private(set) var epochs: [Int] = []
    private(set) var stops = 0

    func listen(epoch: Int) { epochs.append(epoch) }
    func stop() { stops += 1 }

    func hear(_ text: String, final: Bool = true) {
        onTranscript?(TranscriptUpdate(epoch: epochs.last ?? 0, text: text, isFinal: final))
    }

    func becomeUnavailable(_ reason: String) {
        availability = .unavailable(reason)
        onAvailabilityChange?(availability)
    }
}

@MainActor
final class FakeNarrator: SpeechNarrating {
    private(set) var spoken: [String] = []
    private(set) var stops = 0
    private var completion: (@MainActor () -> Void)?

    func speak(_ text: String, preDelay: Double, completion: @escaping @MainActor () -> Void) {
        spoken.append(text)
        self.completion = completion
    }

    func stop() {
        stops += 1
        let pending = completion
        completion = nil
        pending?()
    }

    func finish() {
        let pending = completion
        completion = nil
        pending?()
    }
}

@MainActor
final class FakeHaptics: HapticsPlaying {
    private(set) var played: [HapticEvent] = []
    func play(_ event: HapticEvent) { played.append(event) }
}

@MainActor
@Suite("Session controller")
struct SessionControllerTests {
    final class Clock {
        var now: Double = 0
    }

    private func makeController(
        mode: PrayerMode,
        leaders: [Int: String] = [:]
    ) -> (SessionController, FakeListener, FakeNarrator, FakeHaptics, Clock) {
        let listener = FakeListener()
        let narrator = FakeNarrator()
        let haptics = FakeHaptics()
        let clock = Clock()
        let controller = SessionController(
            configuration: SessionConfiguration(
                scope: .singleDecade(2), mysterySet: .sorrowful, mode: mode, decadeLeaders: leaders,
                nextSessionLeader: leaders.isEmpty ? nil : "Mom"
            ),
            listener: listener,
            narrator: narrator,
            haptics: haptics,
            clock: { clock.now }
        )
        return (controller, listener, narrator, haptics, clock)
    }

    @Test("Guided decade through the controller with fake speech services")
    func guidedThroughController() {
        let (controller, listener, narrator, haptics, clock) = makeController(mode: .guided, leaders: [2: "Dad"])
        var finished = false
        var decades: [Int] = []
        controller.onFinished = { finished = true }
        controller.onDecadeCompleted = { decades.append($0) }

        controller.start(autoTick: false)
        #expect(narrator.spoken == ["The Second Sorrowful Mystery: The Scourging at the Pillar."])
        #expect(controller.voiceIndicator == .speaking)
        clock.now += 3
        narrator.finish()
        #expect(controller.snapshot.phase == .holding)
        clock.now += 3
        controller.tick()
        #expect(controller.snapshot.title == "Our Father")
        clock.now += 4
        narrator.finish()
        #expect(controller.snapshot.phase == .awaitingResponse)
        #expect(controller.voiceIndicator == .listening)
        #expect(listener.epochs.count == 1)

        listener.hear("give us this day our daily bread and forgive us our trespasses but deliver us from evil")
        #expect(controller.snapshot.bead == 1)
        #expect(controller.lastHeard.hasPrefix("give us this day"))
        for bead in 1...10 {
            #expect(controller.snapshot.bead == bead)
            clock.now += 4
            narrator.finish()
            clock.now += 3
            listener.hear("holy mary mother of god pray for us sinners now and at the hour of our death amen")
        }
        #expect(controller.snapshot.title == "Glory Be")
        clock.now += 3
        narrator.finish()
        listener.hear("as it was in the beginning is now and ever shall be world without end amen")
        #expect(controller.snapshot.title == "Fatima Prayer")
        listener.hear("o my jesus forgive us our sins save us from the fires of hell lead all souls to heaven " +
                      "especially those in most need of thy mercy")

        #expect(finished)
        #expect(controller.isFinished)
        #expect(decades == [2])
        #expect(narrator.spoken.last == "Next time, Mom begins.")
        #expect(haptics.played.filter { $0 == .voiceAdvance }.count == 12)
        #expect(haptics.played.last == .sessionComplete)
        #expect(listener.stops >= 1)
        #expect(Set(listener.epochs).count == listener.epochs.count, "a fresh epoch for every answer")
    }

    @Test("Stopping the narrator (tap to skip) doesn't trigger a second advance")
    func skipNarration() {
        let (controller, _, narrator, haptics, clock) = makeController(mode: .guided)
        controller.start(autoTick: false)
        clock.now += 1
        controller.tap()
        #expect(controller.snapshot.title == "Our Father")
        #expect(narrator.stops == 1)
        #expect(controller.snapshot.phase == .speaking)
        #expect(haptics.played == [.tapAdvance])
    }

    @Test("Without voice tracking the session still runs on taps, and says why")
    func unavailableListener() {
        let (controller, listener, _, _, clock) = makeController(mode: .tracking)
        controller.start(autoTick: false)
        listener.becomeUnavailable("Speech recognition permission was declined.")
        #expect(controller.voiceIndicator == .unavailable("Speech recognition permission was declined."))
        for _ in 0..<14 {
            clock.now += 1
            controller.tap()
        }
        #expect(controller.isFinished)
    }

    @Test("Haptics can be turned off")
    func hapticsOff() {
        let (controller, _, _, haptics, clock) = makeController(mode: .tracking)
        controller.hapticsEnabled = false
        controller.start(autoTick: false)
        clock.now += 1
        controller.tap()
        #expect(haptics.played.isEmpty)
    }
}
