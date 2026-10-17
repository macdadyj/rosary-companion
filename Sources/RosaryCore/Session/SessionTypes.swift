import Foundation

public enum PrayerMode: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// "You pray, I listen": the app leads each prayer aloud and listens for the response.
    case guided
    /// "I pray, you track": the person prays everything; the app follows along.
    case tracking

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .guided: "You pray, I listen"
        case .tracking: "I pray, you track"
        }
    }

    public var summary: String {
        switch self {
        case .guided: "I'll lead each prayer aloud and you answer. I'll count the Hail Marys."
        case .tracking: "Pray at your own pace. I'll follow along and keep your place."
        }
    }
}

public enum PauseReason: String, Hashable, Sendable {
    case user
    case interruption
    case background
}

public enum SessionPhase: Hashable, Sendable {
    case notStarted
    /// The app is reading a leader part, an announcement, or a name aloud.
    case speaking
    /// A short silence after a mystery is announced, to settle into the meditation.
    case holding
    /// Guided mode: the person's turn to say the response.
    case awaitingResponse
    /// Tracking mode: listening along.
    case following
    case paused(PauseReason)
    case finished
}

public enum HapticEvent: Hashable, Sendable {
    case tapAdvance
    case voiceAdvance
    case decadeComplete
    case sessionComplete
    case stepBack
}

public enum AdvanceCause: Hashable, Sendable {
    case tap
    /// The closing phrase of the prayer was heard.
    case voice
    /// Part of the prayer was heard, followed by silence.
    case voiceSilence
    /// Speech we couldn't match, followed by silence (guided mode only).
    case voiceLenient
    /// Tracking mode skipped ahead because a later prayer was heard.
    case voiceJump
    /// Nothing to answer: the app finished narrating.
    case narrated
    /// The pause after a mystery announcement elapsed.
    case hold

    var isVoice: Bool {
        switch self {
        case .voice, .voiceSilence, .voiceLenient, .voiceJump: true
        case .tap, .narrated, .hold: false
        }
    }
}

public struct AdvanceRecord: Hashable, Sendable {
    public let from: Int
    public let to: Int
    public let cause: AdvanceCause
    public let time: TimeInterval
}

public enum SessionEffect: Hashable, Sendable {
    case speak(Narration, id: Int, preDelay: TimeInterval)
    case stopSpeaking
    /// Start listening (or restart recognition) and tag results with `epoch`.
    case listen(epoch: Int)
    case stopListening
    case haptic(HapticEvent)
    case decadeCompleted(decade: Int)
    case finished
}

public enum SessionEvent: Hashable, Sendable {
    case start
    case transcript(TranscriptUpdate)
    case narrationFinished(id: Int)
    case tap
    case back
    case tick
    case switchMode(PrayerMode)
    case pause(PauseReason)
    case resume
    case dismissBanner
    case end
    /// Land on that decade's Our Father. Decades are numbered 1...5 inside the mystery set.
    case jumpToDecade(Int)
}

public struct EngineTiming: Hashable, Sendable {
    /// Guided: once the response has started, this much silence means it's finished.
    public var responseSilence: TimeInterval = 1.6
    /// Guided: shorter wait once the response is nearly done.
    public var responseSilenceNearEnd: TimeInterval = 1.0
    /// Guided: speech we couldn't match at all still counts after this much silence.
    public var lenientSilence: TimeInterval = 2.2
    public var lenientMinimumWords = 5
    /// Tracking: silence that completes the last prayer of a decade (or of the session).
    public var checkpointSilence: TimeInterval = 1.8
    /// Guided: pause after announcing a mystery.
    public var announcementHold: TimeInterval = 2.5
    /// A tap this soon after a voice advance confirms it instead of advancing again.
    public var tapAbsorbWindow: TimeInterval = 0.6
    /// Tracking: skipping ahead requires at least this much time per skipped step,
    /// so stray late words can never fling the counter forward.
    public var secondsPerSkippedStep: TimeInterval = 3
    /// Tracking: a Hail Mary longer than this must be the next one.
    public var maxHailMaryDuration: TimeInterval = 22
    /// Show "tap to continue" after this long without progress.
    public var tapHintDelay: TimeInterval = 8
    public var bannerDuration: TimeInterval = 5
    public var narrationLeadIn: TimeInterval = 0.35

    public init() {}
}

public struct SessionConfiguration: Hashable, Sendable {
    public var scope: SessionScope
    public var mysterySet: MysterySet
    public var mode: PrayerMode
    public var openingIntentions: Bool
    public var prayerBook: PrayerBook
    /// Family mode: who leads each decade, keyed by decade number.
    public var decadeLeaders: [Int: String]
    /// Family mode: who begins next time.
    public var nextSessionLeader: String?
    public var announceNextLeader: Bool
    public var timing: EngineTiming

    public init(
        scope: SessionScope,
        mysterySet: MysterySet,
        mode: PrayerMode,
        openingIntentions: Bool = true,
        prayerBook: PrayerBook = PrayerBook(),
        decadeLeaders: [Int: String] = [:],
        nextSessionLeader: String? = nil,
        announceNextLeader: Bool = true,
        timing: EngineTiming = EngineTiming()
    ) {
        self.scope = scope
        self.mysterySet = mysterySet
        self.mode = mode
        self.openingIntentions = openingIntentions
        self.prayerBook = prayerBook
        self.decadeLeaders = decadeLeaders
        self.nextSessionLeader = nextSessionLeader
        self.announceNextLeader = announceNextLeader
        self.timing = timing
    }

    public var isFamily: Bool { !decadeLeaders.isEmpty }
}

/// Everything the prayer screen needs to draw the current moment.
public struct SessionSnapshot: Hashable, Sendable {
    public var mode: PrayerMode
    public var phase: SessionPhase
    public var stepIndex: Int
    public var stepCount: Int
    public var step: RosaryStep
    public var section: RosarySection
    public var title: String
    public var leaderText: String
    public var responseText: String
    public var intention: OpeningIntention?
    public var mysterySet: MysterySet
    /// The mystery being meditated on (while inside a decade).
    public var mystery: Mystery?
    /// 1-based position of the current decade within this session, and how many there are.
    public var decadePosition: Int?
    public var decadeTotal: Int
    public var bead: Int?
    public var beadCount: Int?
    /// Tracking mode counts are estimates; shown with "≈".
    public var isEstimate: Bool
    public var completedDecades: [Int]
    public var leader: String?
    public var nextLeaderBanner: String?
    public var nextSessionLeader: String?
    public var showTapHint: Bool
    /// What we're waiting to hear in guided mode, e.g. "Holy Mary, Mother of God…"
    public var listeningFor: String?
}
