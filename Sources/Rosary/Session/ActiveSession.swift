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

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let speech: SpeechRecognitionService?
    @ObservationIgnored private let narrator: NarratorService
    @ObservationIgnored private let audio = AudioSessionCoordinator()

    init(prepared: PreparedSession, model: AppModel) {
        let settings = model.settings
        let speech = settings.voiceTracking ? SpeechRecognitionService() : nil
        let narrator = NarratorService(voiceID: settings.narratorVoiceID, rate: settings.narrationRate)
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

        controller.onFinished = { [weak self] in self?.sessionFinished() }
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

    /// Asks for permissions (first time only), then starts praying.
    func begin() async {
        guard isPreparing else { return }
        if let speech { await speech.requestAccess() }
        audio.activate(listening: speech != nil)
        audio.keepScreenAwake(true)
        isPreparing = false
        controller.start()
    }

    func tap() {
        if case .paused = controller.snapshot.phase { audio.activate(listening: speech != nil) }
        controller.tap()
    }

    func togglePause() {
        if case .paused = controller.snapshot.phase {
            audio.activate(listening: speech != nil)
            controller.resume()
        } else {
            controller.pause(.user)
        }
    }

    func back() { controller.back() }

    func switchMode(_ mode: PrayerMode) { controller.switchMode(mode) }

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
        if phase == .background { controller.pause(.background) }
    }

    /// Releases the microphone, audio session, and screen-awake flag.
    func close() {
        controller.stopTicking()
        speech?.stop()
        narrator.stop()
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
        if prepared.starter != nil { nextStarterName = model.nextStarter?.name }
        audio.keepScreenAwake(false)
    }
}
#endif
