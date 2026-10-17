import Foundation
import Observation

public enum VoiceIndicator: Hashable, Sendable {
    case speaking
    case listening
    case quiet
    case paused
    case unavailable(String)
}

/// Runs a `SessionEngine` against real (or fake) speech services and publishes its state.
@MainActor
@Observable
public final class SessionController {
    public private(set) var snapshot: SessionSnapshot
    public private(set) var listenerAvailability: ListenerAvailability
    public private(set) var isFinished = false
    /// Last thing the recogniser heard; shown faintly so people can see it's working.
    public private(set) var lastHeard = ""
    public var hapticsEnabled = true

    @ObservationIgnored public let engine: SessionEngine
    @ObservationIgnored private let listener: SpeechListening?
    @ObservationIgnored private let narrator: SpeechNarrating
    @ObservationIgnored private let haptics: HapticsPlaying?
    @ObservationIgnored private let clock: @MainActor () -> TimeInterval
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var activeNarration: Int?

    @ObservationIgnored public var onDecadeCompleted: (@MainActor (Int) -> Void)?
    @ObservationIgnored public var onFinished: (@MainActor () -> Void)?

    public init(
        configuration: SessionConfiguration,
        listener: SpeechListening?,
        narrator: SpeechNarrating,
        haptics: HapticsPlaying? = nil,
        clock: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        let engine = SessionEngine(configuration: configuration)
        self.engine = engine
        self.listener = listener
        self.narrator = narrator
        self.haptics = haptics
        self.clock = clock
        self.snapshot = engine.snapshot
        self.listenerAvailability = listener?.availability ?? .unavailable("Voice tracking is off.")

        listener?.onTranscript = { [weak self] update in
            self?.lastHeard = update.text
            self?.send(.transcript(update))
        }
        listener?.onAvailabilityChange = { [weak self] availability in
            self?.listenerAvailability = availability
        }
    }

    public var voiceIndicator: VoiceIndicator {
        switch snapshot.phase {
        case .paused: return .paused
        case .speaking: return .speaking
        case .finished, .notStarted: return .quiet
        case .holding, .awaitingResponse, .following:
            if case .unavailable(let reason) = listenerAvailability { return .unavailable(reason) }
            return snapshot.phase == .holding ? .quiet : .listening
        }
    }

    public func start(autoTick: Bool = true) {
        send(.start)
        if autoTick { startTicking() }
    }

    public func tap() { send(.tap) }
    public func back() { send(.back) }
    public func switchMode(_ mode: PrayerMode) { send(.switchMode(mode)) }
    public func pause(_ reason: PauseReason = .user) { send(.pause(reason)) }
    public func resume() { send(.resume) }
    public func dismissBanner() { send(.dismissBanner) }
    public func jumpToDecade(_ decade: Int) { send(.jumpToDecade(decade)) }
    public func end() { send(.end) }
    public func tick() { send(.tick) }

    public func send(_ event: SessionEvent) {
        let effects = engine.send(event, at: clock())
        perform(effects)
        let latest = engine.snapshot
        if latest != snapshot { snapshot = latest }
    }

    public func startTicking() {
        guard ticker == nil else { return }
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self else { return }
                self.tick()
            }
        }
    }

    public func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func perform(_ effects: [SessionEffect]) {
        for effect in effects {
            switch effect {
            case .speak(let narration, let id, let preDelay):
                activeNarration = id
                narrator.speak(narration, preDelay: preDelay) { [weak self] in
                    guard let self, self.activeNarration == id else { return }
                    self.activeNarration = nil
                    self.send(.narrationFinished(id: id))
                }
            case .stopSpeaking:
                activeNarration = nil
                narrator.stop()
            case .listen(let epoch):
                listener?.listen(epoch: epoch)
            case .stopListening:
                listener?.stop()
            case .haptic(let event):
                if hapticsEnabled { haptics?.play(event) }
            case .decadeCompleted(let decade):
                onDecadeCompleted?(decade)
            case .finished:
                isFinished = true
                stopTicking()
                onFinished?()
            }
        }
    }
}
