#if os(iOS)
import Foundation
import Observation
import RosaryCore
import SwiftUI

/// One prayer session on screen: the engine's controller plus the real speech, narration,
/// haptics, and audio-session plumbing around it.
@MainActor
@Observable
final class ActiveSession: Identifiable {
    let id: UUID
    let prepared: PreparedSession
    let controller: SessionController
    let meditationDay: CivilDate
    /// Set once the session ends and has been saved (nil if no decade was completed).
    private(set) var record: SessionRecord?
    private(set) var hasEnded = false
    /// Who begins next time, after the rotation has been saved.
    private(set) var nextStarterName: String?
    private(set) var isPreparing = true
    /// Tracking mode: whether the meditation panel is open. Remembered for next time.
    private(set) var showsMeditation: Bool

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let speech: SpeechRecognitionService?
    @ObservationIgnored private let narrator: NarrationSequencer
    @ObservationIgnored private let audio = AudioSessionCoordinator()
    @ObservationIgnored private let nowPlaying = NowPlaying()
    @ObservationIgnored private var listeningSuspended = false

    init(prepared: PreparedSession, model: AppModel) {
        let settings = model.settings
        let testing = UITestLaunch.isEnabled
        let speech = settings.voiceTracking && !testing ? SpeechRecognitionService() : nil
        let output: NarrationOutput = testing
            ? HoldingNarration()
            : SpeechOutput(voice: InstalledVoices.voice(selectedID: settings.narratorVoiceID))
        let narrator = NarrationSequencer(
            output: output,
            planner: NarrationPlanner(recordings: ActiveSession.recordings, pacing: settings.pacing)
        )
        let controller = SessionController(
            configuration: prepared.configuration,
            listener: speech,
            narrator: narrator,
            haptics: HapticsService()
        )
        controller.hapticsEnabled = settings.haptics

        self.id = prepared.id
        self.prepared = prepared
        self.controller = controller
        self.meditationDay = model.today
        self.model = model
        self.speech = speech
        self.narrator = narrator
        self.showsMeditation = settings.showsMeditationWhileTracking
        // The end control has to be on the first frame the UI test looks at.
        self.isPreparing = !testing

        controller.onFinished = { [weak self] in self?.sessionFinished() }
        nowPlaying.install { [weak self] in self?.toggleFromRemote() }
        audio.onInterruptionBegan = { [weak self] in self?.controller.pause(.interruption) }
        audio.onMediaServicesReset = { [weak self] in
            guard let self else { return }
            self.controller.pause(.interruption)
            self.speech?.rebuildAudioEngine()
        }
    }

    var usesVoice: Bool { speech != nil }

    var streak: StreakSummary { model.streak }

    var offeredIntentions: [Intention] {
        prepared.setup.intentionIDs.compactMap(model.intention)
    }

    /// Shows the prayer controls immediately for UI tests, without the microphone.
    func revealForUITest() {
        guard !hasEnded else { return }
        isPreparing = false
        if case .notStarted = controller.snapshot.phase {
            controller.start()
        }
    }

    /// Asks for permissions (first time only), then starts praying.
    func begin() async {
        guard isPreparing else { return }
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        if let speech, !testing { await speech.requestAccess() }
        if !testing {
            audio.activate(listening: wantsMicrophone)
            audio.keepScreenAwake(true)
        }
        isPreparing = false
        controller.start()
        refreshNowPlaying()
    }

    private var wantsMicrophone: Bool {
        speech != nil && controller.snapshot.mode != .guidedRosary && controller.engine.mode != .guidedRosary
    }

    func tap() {
        if case .paused = controller.snapshot.phase, !UITestLaunch.isEnabled {
            audio.activate(listening: wantsMicrophone)
        }
        controller.tap()
        refreshNowPlaying()
    }

    func togglePause() {
        if case .paused = controller.snapshot.phase {
            if !UITestLaunch.isEnabled { audio.activate(listening: wantsMicrophone) }
            controller.resume()
        } else {
            controller.pause(.user)
        }
        refreshNowPlaying()
    }

    func toggleFromRemote() {
        guard !hasEnded, !isPreparing else { return }
        togglePause()
    }

    func back() { controller.back() }

    func jumpToDecade(_ decade: Int) { controller.jumpToDecade(decade) }

    func switchMode(_ mode: PrayerMode) {
        controller.switchMode(mode)
        guard !UITestLaunch.isEnabled, !isPreparing else { return }
        if mode == .guidedRosary { speech?.stop() }
        audio.activate(listening: wantsMicrophone)
        refreshNowPlaying()
    }

    func setReadsMeditations(_ enabled: Bool) {
        controller.setReadsMeditations(enabled)
        model.update { $0.readsMeditationsAloud = enabled }
    }

    func setNarrationRate(_ rate: Double) {
        model.update { $0.narrationRate = rate }
        narrator.planner.pacing = SpeechPacing(rate: rate, pitch: model.settings.narrationPitch)
    }

    func setShowsMeditation(_ shows: Bool) {
        showsMeditation = shows
        model.update { $0.showsMeditationWhileTracking = shows }
    }

    func endEarly() {
        if isPreparing {
            isPreparing = false
            hasEnded = true
            return
        }
        controller.end()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        guard !hasEnded, !isPreparing else { return }
        switch phase {
        case .background:
            // Speech keeps going with the screen locked. The microphone does not.
            controller.suspendListening()
            listeningSuspended = true
            if speech != nil, !UITestLaunch.isEnabled {
                audio.activate(listening: false)
            }
            refreshNowPlaying()
        case .active:
            guard listeningSuspended else { return }
            listeningSuspended = false
            if !UITestLaunch.isEnabled {
                audio.activate(listening: wantsMicrophone)
            }
            if wantsMicrophone { controller.resumeListeningIfNeeded() }
            refreshNowPlaying()
        case .inactive:
            refreshNowPlaying()
        @unknown default:
            break
        }
    }

    func refreshNowPlaying() {
        let playing: Bool
        switch controller.snapshot.phase {
        case .speaking: playing = true
        case .notStarted, .holding, .awaitingResponse, .following, .paused, .finished:
            playing = false
        }
        nowPlaying.publish(title: controller.snapshot.title, playing: playing)
    }

    /// Releases the microphone, audio session, and screen-awake flag.
    func close() {
        controller.stopTicking()
        speech?.stop()
        narrator.stop()
        nowPlaying.clear()
        audio.keepScreenAwake(false)
        audio.deactivate()
    }

    func saveJournal(_ text: String) {
        guard let record else { return }
        model.setJournal(text, for: record.id)
    }

    private func sessionFinished() {
        hasEnded = true
        let engine = controller.engine
        if !engine.completedDecades.isEmpty {
            record = model.record(prepared, completedDecades: engine.completedDecades, completedAll: engine.completedAll)
        }
        model.rememberPrayer(PrayerCatalogue.rosaryID(for: prepared.setup.mysterySet))
        if prepared.starter != nil { nextStarterName = model.nextStarter?.name }
        audio.keepScreenAwake(false)
    }

    /// Recorded prayers shipped in the app replace the synthesized voice part by part.
    private static var recordings: any NarrationRecordings {
        if let bundled = RecordingFolder.bundled { return bundled }
        return NoRecordings()
    }
}

/// UI tests stay on the first prayer. A simulator voice that finishes immediately
/// would otherwise run the whole decade before XCTest looks for the end control.
@MainActor
private final class HoldingNarration: NarrationOutput {
    func play(_ item: NarrationItem, preDelay: TimeInterval, completion: @escaping @MainActor (Bool) -> Void) {}

    func stop() {}

    func pause() {}

    func resume() {}
}
#endif
