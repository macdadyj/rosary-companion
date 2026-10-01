#if os(iOS)
import AVFoundation
import Foundation
import RosaryCore
import Speech

/// Feeds microphone audio to on-device speech recognition and reports what it hears.
///
/// Recognition never leaves the iPhone: if the on-device model isn't available, voice
/// tracking is reported as unavailable (taps still work) rather than falling back to a server.
@MainActor
final class SpeechRecognitionService: SpeechListening {
    private(set) var availability: ListenerAvailability {
        didSet {
            if availability != oldValue { onAvailabilityChange?(availability) }
        }
    }
    var onTranscript: (@MainActor @Sendable (TranscriptUpdate) -> Void)?
    var onAvailabilityChange: (@MainActor @Sendable (ListenerAvailability) -> Void)?

    private let recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private let sink = RecognitionAudioSink()
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var wantsListening = false
    private var epoch = 0
    private var segment = 0
    /// Permission or capability problem that a retry can't fix.
    private var blockedReason: String?
    private var recentFailures: [Date] = []
    private var restartTask: Task<Void, Never>?
    private var configurationObserver: NSObjectProtocol?

    init() {
        let english = Locale.current.language.languageCode == .english ? Locale.current : Locale(identifier: "en-US")
        recognizer = SFSpeechRecognizer(locale: english) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        availability = .ready
        blockedReason = Self.capabilityProblem(for: recognizer)
        if let blockedReason { availability = .unavailable(blockedReason) }

        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.audioConfigurationChanged() }
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
    }

    /// Asks for microphone and speech permission if needed. Returns the resulting availability.
    @discardableResult
    func requestAccess() async -> ListenerAvailability {
        if let problem = Self.capabilityProblem(for: recognizer) {
            block(problem)
            return availability
        }

        let speechStatus = await Self.speechAuthorization()
        guard speechStatus == .authorized else {
            block(speechStatus == .restricted
                ? "Speech recognition is restricted on this iPhone. Tap to move through the prayers."
                : "Speech recognition is turned off for Rosary. You can allow it in Settings › Rosary, or tap to move through the prayers.")
            return availability
        }

        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard micAllowed else {
            block("Microphone access is turned off for Rosary. You can allow it in Settings › Rosary, or tap to move through the prayers.")
            return availability
        }

        blockedReason = nil
        if case .unavailable = availability { availability = .ready }
        return availability
    }

    func listen(epoch: Int) {
        self.epoch = epoch
        wantsListening = true
        guard blockedReason == nil, let recognizer else { return }
        do {
            try startAudioIfNeeded()
            startRecognition(with: recognizer)
            availability = .listening
        } catch {
            availability = .unavailable("The microphone couldn't start. Tap to continue.")
            scheduleRestart(after: 1.5)
        }
    }

    func stop() {
        wantsListening = false
        restartTask?.cancel()
        restartTask = nil
        endRecognition()
        stopAudio()
        if blockedReason == nil { availability = .ready }
    }

    /// Call after the audio session is reset by the system.
    func rebuildAudioEngine() {
        let resume = wantsListening
        stop()
        audioEngine = AVAudioEngine()
        if resume { listen(epoch: epoch) }
    }

    // MARK: - Recognition

    private func startRecognition(with recognizer: SFSpeechRecognizer) {
        endRecognition()
        segment += 1

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.addsPunctuation = false
        request.contextualStrings = Self.contextualStrings
        sink.setRequest(request)

        task = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.resultHandler(service: self, epoch: epoch, segment: segment)
        )
    }

    private func endRecognition() {
        sink.setRequest(nil)?.endAudio()
        task?.cancel()
        task = nil
    }

    /// Built outside the main actor: Speech calls this on its own queue.
    private nonisolated static func resultHandler(
        service: SpeechRecognitionService, epoch: Int, segment: Int
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak service] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                service?.received(text: text, isFinal: isFinal, failed: failed, epoch: epoch, segment: segment)
            }
        }
    }

    private func received(text: String?, isFinal: Bool, failed: Bool, epoch: Int, segment: Int) {
        guard wantsListening, segment == self.segment else { return }
        if let text, !text.isEmpty {
            recentFailures.removeAll()
            onTranscript?(TranscriptUpdate(epoch: epoch, segment: segment, text: text, isFinal: isFinal))
        }
        guard isFinal || failed else { return }

        // The recogniser ends a segment after a final result, a long silence, or an error.
        // Keep listening with a fresh segment, but give up if it keeps failing with no speech.
        if failed {
            let now = Date()
            recentFailures = recentFailures.filter { now.timeIntervalSince($0) < 20 } + [now]
            if recentFailures.count >= 6 {
                availability = .unavailable("Voice tracking stopped responding. Tap to continue.")
                scheduleRestart(after: 5)
                return
            }
        }
        scheduleRestart(after: failed ? 0.5 : 0.05)
    }

    private func scheduleRestart(after delay: TimeInterval) {
        restartTask?.cancel()
        restartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, !Task.isCancelled, self.wantsListening else { return }
            self.listen(epoch: self.epoch)
        }
    }

    // MARK: - Audio

    private func startAudioIfNeeded() throws {
        guard !audioEngine.isRunning else { return }
        let input = audioEngine.inputNode
        if !tapInstalled {
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw ServiceError.noMicrophone }
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(sink))
            tapInstalled = true
        }
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func stopAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    /// Runs on the real-time audio thread, so it must not touch the main actor.
    private nonisolated static func tapBlock(_ sink: RecognitionAudioSink) -> AVAudioNodeTapBlock {
        { buffer, _ in sink.append(buffer) }
    }

    private func audioConfigurationChanged() {
        guard wantsListening else { return }
        stopAudio()
        listen(epoch: epoch)
    }

    private func block(_ reason: String) {
        blockedReason = reason
        availability = .unavailable(reason)
    }

    // MARK: - Helpers

    private enum ServiceError: Error { case noMicrophone }

    private static func capabilityProblem(for recognizer: SFSpeechRecognizer?) -> String? {
        guard let recognizer else {
            return "Speech recognition isn't available for English on this iPhone. Tap to move through the prayers."
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return "On-device speech recognition isn't installed on this iPhone, and Rosary never sends audio online. Turning on Dictation in Settings › General › Keyboard downloads it. Until then, tap to move through the prayers."
        }
        return nil
    }

    private static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    /// Words the recogniser should favour.
    static let contextualStrings = [
        "Hail Mary", "full of grace", "Holy Mary", "Mother of God", "pray for us sinners",
        "Glory be to the Father", "as it was in the beginning", "world without end",
        "O my Jesus", "forgive us our sins", "fires of hell", "lead all souls to Heaven",
        "Our Father", "who art in heaven", "hallowed be thy name", "trespasses",
        "the fruit of thy womb", "Amen", "mystery", "Annunciation", "Visitation", "Nativity",
        "Presentation", "Transfiguration", "Eucharist", "Agony in the Garden", "Scourging",
        "Crowning with Thorns", "Carrying of the Cross", "Crucifixion", "Resurrection",
        "Ascension", "Descent of the Holy Spirit", "Assumption", "Coronation",
        "Hail, holy Queen", "Salve Regina", "only-begotten Son",
    ]
}

/// Hands audio buffers from the audio thread to whichever recognition request is current.
final class RecognitionAudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?

    /// Replaces the current request and returns the previous one.
    @discardableResult
    func setRequest(_ newRequest: SFSpeechAudioBufferRecognitionRequest?) -> SFSpeechAudioBufferRecognitionRequest? {
        lock.lock()
        defer { lock.unlock() }
        let old = request
        request = newRequest
        return old
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let current = request
        lock.unlock()
        current?.append(buffer)
    }
}
#endif
