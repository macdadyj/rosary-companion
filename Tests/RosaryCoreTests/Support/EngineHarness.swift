@testable import RosaryCore

/// Drives a `SessionEngine` like the app does: a fake clock, a pretend narrator that finishes
/// speaking after a realistic delay, and a scripted recogniser that streams partial results.
final class EngineHarness {
    let engine: SessionEngine
    private(set) var now: Double = 0
    private(set) var effects: [SessionEffect] = []
    private(set) var narrations: [Narration] = []
    private(set) var listenEpoch: Int?
    private var script = TranscriptScript(epoch: 0)
    private var narration: Int?

    let book = PrayerBook()

    init(_ configuration: SessionConfiguration) {
        engine = SessionEngine(configuration: configuration)
    }

    convenience init(
        scope: SessionScope = .singleDecade(1),
        set: MysterySet = .joyful,
        mode: PrayerMode,
        leaders: [Int: String] = [:],
        nextSessionLeader: String? = nil
    ) {
        self.init(SessionConfiguration(
            scope: scope, mysterySet: set, mode: mode,
            decadeLeaders: leaders, nextSessionLeader: nextSessionLeader
        ))
    }

    var spoken: [String] { narrations.map(\.text) }
    var snapshot: SessionSnapshot { engine.snapshot }
    var step: RosaryStep { engine.currentStep }
    var phase: SessionPhase { engine.phase }
    var stopListeningCount: Int { effects.filter { $0 == .stopListening }.count }
    var decadesCompleted: [Int] {
        effects.compactMap { if case .decadeCompleted(let d) = $0 { d } else { nil } }
    }
    var haptics: [HapticEvent] {
        effects.compactMap { if case .haptic(let h) = $0 { h } else { nil } }
    }

    @discardableResult
    func send(_ event: SessionEvent) -> [SessionEffect] {
        let produced = engine.send(event, at: now)
        for effect in produced {
            switch effect {
            case .speak(let spokenNarration, let id, _):
                narrations.append(spokenNarration)
                narration = id
            case .stopSpeaking:
                narration = nil
            case .listen(let epoch):
                listenEpoch = epoch
                script = TranscriptScript(epoch: epoch)
            default:
                break
            }
        }
        effects += produced
        return produced
    }

    func start() { send(.start) }

    /// Lets time pass, ticking like the app's 5 Hz timer.
    func wait(_ seconds: Double) {
        let end = now + seconds
        while now < end {
            now = min(end, now + 0.2)
            send(.tick)
        }
    }

    /// The narrator finishes the current utterance (about 2.5 words per second).
    func finishNarration() {
        guard let id = narration, let text = spoken.last else { return }
        now += max(1, Double(text.split(separator: " ").count) / 2.5)
        narration = nil
        send(.narrationFinished(id: id))
    }

    /// Plays narration and pauses until the person is expected to speak (or the session ends).
    func runUntilListening(limit: Int = 50) {
        for _ in 0..<limit {
            switch phase {
            case .speaking: finishNarration()
            case .holding: wait(0.2)
            default: return
            }
        }
    }

    /// The person says `sentence`; partial results arrive every 0.3 s, two words at a time.
    func say(_ sentence: String, thenPause pause: Double = 0.6) {
        for update in script.say(sentence) {
            now += 0.3
            send(.transcript(update))
            send(.tick)
        }
        if pause > 0 { wait(pause) }
    }

    /// The recogniser resends its last result (it often does while someone is quiet).
    func repeatLastPartial(times: Int) {
        guard let text = lastText else { return }
        for _ in 0..<times {
            now += 0.25
            send(.transcript(TranscriptUpdate(epoch: script.epoch, segment: script.segment, text: text)))
            send(.tick)
        }
    }

    /// Sends a raw transcript in an explicit (possibly stale) epoch.
    func sendRaw(_ text: String, epoch: Int, segment: Int = 0, isFinal: Bool = false) {
        now += 0.3
        send(.transcript(TranscriptUpdate(epoch: epoch, segment: segment, text: text, isFinal: isFinal)))
    }

    func restartRecogniserSegment() { script.restartSegment() }

    func tap() { send(.tap) }

    private var lastText: String? { script.spoken.isEmpty ? nil : script.spoken }

    /// What the person says aloud for the current step when they pray it all themselves.
    var fullTextOfCurrentStep: String {
        switch step.content {
        case .mysteryAnnouncement(let mystery): mystery.announcement
        case .prayer(let id): book.text(for: id).full
        }
    }

    var responseOfCurrentStep: String {
        guard let id = step.prayerID else { return "" }
        return book.text(for: id).response
    }
}

/// Recogniser-style mistakes: homophones, dropped words, and split words.
enum Noise {
    static let substitutions: [String: String] = [
        "Mary,": "Marry", "grace,": "grays", "thee;": "the", "thou": "now", "womb,": "room",
        "Holy": "wholly", "sinners,": "centers", "hour": "our", "death.": "deaf", "Glory": "gloria",
        "beginning,": "begin in", "sins,": "since", "souls": "soles", "mercy.": "mercies",
        "trespasses,": "trespassers", "temptation,": "temptations", "heaven,": "haven",
        "hallowed": "hollowed", "Father,": "farther", "fires": "fire", "Amen.": "",
        "evil.": "evil", "end.": "and", "O": "oh", "Jesus,": "Jesús", "daily": "daley",
    ]

    static func garble(_ text: String) -> String {
        text.split(separator: " ")
            .map { substitutions[String($0)] ?? String($0) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
