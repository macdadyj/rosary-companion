import Foundation

/// The Rosary state machine. Feed it events with a timestamp and perform the effects it returns.
///
/// It owns no timers and no audio: the caller sends `.tick` a few times a second and forwards
/// recogniser results as `.transcript`, which is what makes it testable with scripted transcripts.
public final class SessionEngine {
    public let configuration: SessionConfiguration
    public let plan: RosaryPlan
    public private(set) var mode: PrayerMode
    public private(set) var index = 0
    public private(set) var phase: SessionPhase = .notStarted
    public private(set) var completedDecades: [Int] = []
    /// Steps that tracking mode skipped over because a later prayer was heard.
    public private(set) var estimatedSteps: Set<Int> = []
    public private(set) var advances: [AdvanceRecord] = []
    public private(set) var nextLeaderBanner: String?
    public private(set) var startedAt: TimeInterval?
    public private(set) var finishedAt: TimeInterval?
    /// True when the session reached its last prayer, false when it was ended early.
    public private(set) var completedAll = false

    private var timing: EngineTiming { configuration.timing }
    private let detector = AnchorDetector()

    private var epoch = 0
    private var acceptingEpoch: Int?

    private var narrationID = 0
    private var awaitingNarration: Int?
    private var narrationQueue: [Narration] = []
    private var afterNarration = AfterNarration.continueStep

    private var stepEnteredAt: TimeInterval = 0
    private var holdUntil: TimeInterval?
    private var bannerUntil: TimeInterval?
    private var lastAutoAdvanceAt: TimeInterval?
    private var lastProgressAt: TimeInterval = 0

    private var lastTranscriptText = ""
    private var lastTranscriptChangeAt: TimeInterval?
    private var wordsHeard = 0
    /// Highest response fragment heard for the current step (guided), or that the
    /// last prayer of a decade has started (tracking).
    private var heardOrder: Int?
    private var hailMary = HailMaryLatch()
    private var now: TimeInterval = 0

    private enum AfterNarration {
        case continueStep
        case resumeFollowing
    }

    public init(configuration: SessionConfiguration) {
        self.configuration = configuration
        self.plan = RosaryPlan(
            scope: configuration.scope,
            mysterySet: configuration.mysterySet,
            openingIntentions: configuration.openingIntentions
        )
        self.mode = configuration.mode
    }

    public var currentStep: RosaryStep { plan.steps[index] }
    public var isActive: Bool {
        switch phase {
        case .notStarted, .finished: false
        default: true
        }
    }

    // MARK: - Events

    @discardableResult
    public func send(_ event: SessionEvent, at time: TimeInterval) -> [SessionEffect] {
        now = time
        switch event {
        case .start:
            guard phase == .notStarted else { return [] }
            startedAt = time
            lastProgressAt = time
            return enterStep(0)

        case .transcript(let update):
            return receive(update)

        case .narrationFinished(let id):
            return narrationFinished(id)

        case .tap:
            return tap()

        case .back:
            return back()

        case .tick:
            return tick()

        case .switchMode(let newMode):
            return switchMode(to: newMode)

        case .pause(let reason):
            return pause(reason)

        case .resume:
            return resume()

        case .dismissBanner:
            nextLeaderBanner = nil
            bannerUntil = nil
            return []

        case .end:
            guard phase != .finished else { return [] }
            return finish()
        }
    }

    // MARK: - Steps

    private func enterStep(_ newIndex: Int, prelude: [Narration] = []) -> [SessionEffect] {
        index = newIndex
        stepEnteredAt = now
        lastProgressAt = now
        heardOrder = nil
        holdUntil = nil

        switch mode {
        case .guided:
            let lines = prelude + guidedNarration(for: currentStep)
            if lines.isEmpty { return beginAwaitingResponse() }
            return speak(lines, then: .continueStep)
        case .tracking:
            if !prelude.isEmpty { return speak(prelude, then: .resumeFollowing) }
            phase = .following
            return acceptingEpoch == nil ? newEpoch() : []
        }
    }

    private func guidedNarration(for step: RosaryStep) -> [Narration] {
        switch step.content {
        case .mysteryAnnouncement(let mystery):
            return [Narration([mystery.announcementPart])]
        case .prayer(let id):
            guard let leader = configuration.prayerBook.leaderPart(for: id) else { return [] }
            if let intention = step.intention {
                return [Narration([intention.spokenPart, leader])]
            }
            return [Narration([leader])]
        }
    }

    private func responseText(for step: RosaryStep) -> String {
        guard let id = step.prayerID else { return "" }
        return configuration.prayerBook.text(for: id).response
    }

    private func beginAwaitingResponse() -> [SessionEffect] {
        phase = .awaitingResponse
        return newEpoch()
    }

    private func newEpoch() -> [SessionEffect] {
        epoch += 1
        acceptingEpoch = epoch
        detector.reset()
        lastTranscriptText = ""
        lastTranscriptChangeAt = nil
        wordsHeard = 0
        return [.listen(epoch: epoch)]
    }

    private func speak(_ lines: [Narration], then next: AfterNarration) -> [SessionEffect] {
        guard let first = lines.first else { return [] }
        narrationQueue = Array(lines.dropFirst())
        afterNarration = next
        phase = .speaking
        acceptingEpoch = nil
        narrationID += 1
        awaitingNarration = narrationID
        return [.speak(first, id: narrationID, preDelay: timing.narrationLeadIn)]
    }

    private func narrationFinished(_ id: Int) -> [SessionEffect] {
        guard id == awaitingNarration, phase == .speaking else { return [] }
        if !narrationQueue.isEmpty {
            let remaining = narrationQueue
            return speak(remaining, then: afterNarration)
        }
        awaitingNarration = nil
        lastProgressAt = now

        switch afterNarration {
        case .resumeFollowing:
            phase = .following
            return newEpoch()
        case .continueStep:
            if currentStep.mystery != nil {
                phase = .holding
                holdUntil = now + timing.announcementHold
                return []
            }
            if responseText(for: currentStep).isEmpty {
                return advance(to: index + 1, cause: .narrated)
            }
            return beginAwaitingResponse()
        }
    }

    /// Moves forward to `target`, completing every step in between.
    /// `heardLaterPrayer` means the person has already moved on, so names aren't spoken over them.
    private func advance(to target: Int, cause: AdvanceCause, heardLaterPrayer: Bool = false) -> [SessionEffect] {
        let from = index
        advances.append(AdvanceRecord(from: from, to: target, cause: cause, time: now))
        if cause.isVoice { lastAutoAdvanceAt = now }
        if target > from + 1 {
            for skipped in (from + 1)..<target { estimatedSteps.insert(skipped) }
        }

        var effects: [SessionEffect] = []
        var prelude: [Narration] = []
        var completedDecade = false
        for stepIndex in from..<min(target, plan.steps.count) where plan.isLastStepOfDecade(stepIndex) {
            guard let decade = plan.steps[stepIndex].section.decadeNumber,
                  !completedDecades.contains(decade) else { continue }
            completedDecades.append(decade)
            completedDecade = true
            effects.append(.decadeCompleted(decade: decade))
            if let next = leaderOfDecade(after: decade) {
                nextLeaderBanner = next
                bannerUntil = now + timing.bannerDuration
                if configuration.announceNextLeader && !heardLaterPrayer {
                    prelude.append(Narration("\(next) leads the next decade."))
                }
            }
        }

        if target >= plan.steps.count {
            effects.append(.haptic(.sessionComplete))
            return effects + finish(completed: true)
        }

        if completedDecade {
            effects.append(.haptic(.decadeComplete))
        } else {
            switch cause {
            case .tap: effects.append(.haptic(.tapAdvance))
            case .voice, .voiceSilence, .voiceLenient, .voiceJump: effects.append(.haptic(.voiceAdvance))
            case .narrated, .hold: break
            }
        }

        if phase == .speaking {
            effects.append(.stopSpeaking)
            awaitingNarration = nil
            narrationQueue = []
        }
        return effects + enterStep(target, prelude: prelude)
    }

    private func leaderOfDecade(after decade: Int) -> String? {
        let decades = plan.decadeNumbers
        guard let position = decades.firstIndex(of: decade), position + 1 < decades.count else { return nil }
        return configuration.decadeLeaders[decades[position + 1]]
    }

    private func finish(completed: Bool = false) -> [SessionEffect] {
        var effects: [SessionEffect] = []
        if phase == .speaking { effects.append(.stopSpeaking) }
        phase = .finished
        finishedAt = now
        completedAll = completed
        acceptingEpoch = nil
        awaitingNarration = nil
        narrationQueue = []
        effects.append(.stopListening)
        if completed, configuration.announceNextLeader, let next = configuration.nextSessionLeader {
            narrationID += 1
            effects.append(.speak(Narration("Next time, \(next) begins."), id: narrationID, preDelay: timing.narrationLeadIn))
        }
        effects.append(.finished)
        return effects
    }

    // MARK: - Taps and controls

    private func tap() -> [SessionEffect] {
        switch phase {
        case .paused:
            return resume()
        case .notStarted, .finished:
            return []
        case .speaking, .holding, .awaitingResponse, .following:
            if nextLeaderBanner != nil {
                nextLeaderBanner = nil
                bannerUntil = nil
                return []
            }
            if let last = lastAutoAdvanceAt, now - last < timing.tapAbsorbWindow {
                return []
            }
            hailMary.clear()
            return advance(to: index + 1, cause: .tap)
        }
    }

    private func back() -> [SessionEffect] {
        guard isActive, index > 0 else { return [] }
        if case .paused = phase { return [] }
        var effects: [SessionEffect] = [.haptic(.stepBack)]
        if phase == .speaking { effects.append(.stopSpeaking) }
        awaitingNarration = nil
        narrationQueue = []
        let target = index - 1
        if plan.isLastStepOfDecade(target), let decade = plan.steps[target].section.decadeNumber {
            completedDecades.removeAll { $0 == decade }
        }
        estimatedSteps.remove(index)
        hailMary.clear()
        lastAutoAdvanceAt = nil
        if mode == .tracking { acceptingEpoch = nil }
        return effects + enterStep(target)
    }

    private func switchMode(to newMode: PrayerMode) -> [SessionEffect] {
        guard newMode != mode else { return [] }
        mode = newMode
        guard isActive else { return [] }
        if case .paused = phase { return [] }
        var effects: [SessionEffect] = []
        if phase == .speaking { effects.append(.stopSpeaking) }
        awaitingNarration = nil
        narrationQueue = []
        acceptingEpoch = nil
        hailMary.clear()
        return effects + enterStep(index)
    }

    private func pause(_ reason: PauseReason) -> [SessionEffect] {
        guard isActive else { return [] }
        if case .paused = phase { return [] }
        var effects: [SessionEffect] = []
        if phase == .speaking { effects.append(.stopSpeaking) }
        awaitingNarration = nil
        narrationQueue = []
        acceptingEpoch = nil
        phase = .paused(reason)
        effects.append(.stopListening)
        return effects
    }

    private func resume() -> [SessionEffect] {
        guard case .paused = phase else { return [] }
        hailMary.clear()
        return enterStep(index)
    }

    // MARK: - Listening

    private func receive(_ update: TranscriptUpdate) -> [SessionEffect] {
        guard let accepting = acceptingEpoch, update.epoch == accepting else { return [] }
        guard phase == .awaitingResponse || phase == .following else { return [] }

        if update.text != lastTranscriptText {
            lastTranscriptText = update.text
            lastTranscriptChangeAt = now
            wordsHeard = TextNormalizer.words(update.text).count
        }
        let hits = detector.process(update, fragments: activeFragments(), now: now)
        return handle(hits)
    }

    private func tick() -> [SessionEffect] {
        var effects: [SessionEffect] = []
        if let until = bannerUntil, now >= until {
            nextLeaderBanner = nil
            bannerUntil = nil
        }

        switch phase {
        case .holding:
            if let until = holdUntil, now >= until {
                effects += advance(to: index + 1, cause: .hold)
            }
        case .awaitingResponse:
            effects += handle(detector.tick(now: now))
            guard phase == .awaitingResponse, let changed = lastTranscriptChangeAt else { break }
            let silence = now - changed
            if let heard = heardOrder {
                let lastOrder = AnchorLibrary.fragments(for: currentStep).last?.order ?? heard
                let needed = heard >= lastOrder - 1 ? timing.responseSilenceNearEnd : timing.responseSilence
                if silence >= needed { effects += advance(to: index + 1, cause: .voiceSilence) }
            } else if wordsHeard >= timing.lenientMinimumWords, silence >= timing.lenientSilence {
                effects += advance(to: index + 1, cause: .voiceLenient)
            }
        case .following:
            effects += handle(detector.tick(now: now))
            guard phase == .following, isCheckpoint(index), heardOrder != nil,
                  let changed = lastTranscriptChangeAt else { break }
            if now - changed >= timing.checkpointSilence {
                effects += advance(to: index + 1, cause: .voiceSilence)
            }
        case .notStarted, .speaking, .paused, .finished:
            break
        }
        return effects
    }

    private func activeFragments() -> [AnchorFragment] {
        switch mode {
        case .guided:
            guard phase == .awaitingResponse else { return [] }
            return AnchorLibrary.fragments(for: currentStep).filter { $0.part == .response }
        case .tracking:
            var seen: Set<AnchorKind> = []
            var fragments: [AnchorFragment] = []
            for step in plan.steps[index..<trackingWindowEnd()] where seen.insert(step.anchor).inserted {
                fragments += AnchorLibrary.fragments(for: step)
            }
            return fragments
        }
    }

    private func handle(_ hits: [AnchorHit]) -> [SessionEffect] {
        var effects: [SessionEffect] = []
        for hit in hits {
            guard phase == .awaitingResponse || phase == .following else { break }
            lastProgressAt = now
            switch mode {
            case .guided: effects += handleGuided(hit)
            case .tracking: effects += handleTracking(hit)
            }
        }
        return effects
    }

    private func handleGuided(_ hit: AnchorHit) -> [SessionEffect] {
        guard hit.fragment.kind == currentStep.anchor, hit.fragment.part == .response else { return [] }
        heardOrder = max(heardOrder ?? hit.fragment.order, hit.fragment.order)
        if hit.fragment.isClosing {
            return advance(to: index + 1, cause: .voice)
        }
        return []
    }

    // MARK: - Tracking mode

    /// The rest of the current section plus the next section up to its first Hail Mary.
    private func trackingWindowEnd() -> Int {
        var end = plan.sectionRange(containing: index).upperBound
        if end < plan.steps.count {
            let nextSection = plan.sectionRange(containing: end)
            if let firstHailMary = plan.steps[nextSection].first(where: { $0.prayerID == .hailMary }) {
                end = firstHailMary.id + 1
            } else {
                end = nextSection.upperBound
            }
        }
        return end
    }

    private func isCheckpoint(_ stepIndex: Int) -> Bool {
        plan.isLastStepOfDecade(stepIndex) || stepIndex == plan.steps.count - 1
    }

    private func plausibleTarget(for kind: AnchorKind) -> Int? {
        let end = trackingWindowEnd()
        guard index + 1 < end,
              let target = ((index + 1)..<end).first(where: { plan.steps[$0].anchor == kind }) else {
            return nil
        }
        let skipped = target - index - 1
        guard now - stepEnteredAt >= Double(skipped) * timing.secondsPerSkippedStep else { return nil }
        return target
    }

    private func handleTracking(_ hit: AnchorHit) -> [SessionEffect] {
        let kind = hit.fragment.kind
        if kind == .prayer(.hailMary) {
            return trackHailMary(hit)
        }
        if kind == currentStep.anchor {
            return continueCurrent(hit)
        }
        guard let target = plausibleTarget(for: kind) else { return [] }
        let cause: AdvanceCause = target == index + 1 ? .voice : .voiceJump
        var effects = advance(to: target, cause: cause, heardLaterPrayer: true)
        if phase == .following || phase == .speaking {
            effects += continueCurrent(hit)
        }
        return effects
    }

    private func continueCurrent(_ hit: AnchorHit) -> [SessionEffect] {
        guard isCheckpoint(index), hit.fragment.kind == currentStep.anchor else { return [] }
        heardOrder = max(heardOrder ?? hit.fragment.order, hit.fragment.order)
        if hit.fragment.isClosing, phase == .following {
            return advance(to: index + 1, cause: .voice)
        }
        return []
    }

    private func trackHailMary(_ hit: AnchorHit) -> [SessionEffect] {
        let order = hit.fragment.order
        guard currentStep.prayerID == .hailMary else {
            guard let target = plausibleTarget(for: .prayer(.hailMary)) else { return [] }
            let effects = advance(
                to: target, cause: target == index + 1 ? .voice : .voiceJump, heardLaterPrayer: true
            )
            hailMary.start(order: order, at: now)
            return effects
        }
        guard hailMary.isActive else {
            hailMary.start(order: order, at: now)
            return []
        }
        guard hailMary.isNewRepetition(order: order, at: now, maxDuration: timing.maxHailMaryDuration) else {
            hailMary.update(order: order)
            return []
        }
        let next = index + 1
        guard next < plan.steps.count,
              plan.steps[next].prayerID == .hailMary,
              plan.steps[next].section == currentStep.section else {
            // An extra Hail Mary beyond the group: keep the count where it is.
            hailMary.start(order: order, at: now)
            return []
        }
        let effects = advance(to: next, cause: .voice)
        hailMary.start(order: order, at: now)
        return effects
    }

    // MARK: - Snapshot

    public var snapshot: SessionSnapshot {
        let step = currentStep
        let decade = step.section.decadeNumber
        let decadeMystery = decade.map { plan.mysterySet.mysteries[$0 - 1] }
        let title: String
        var leader = ""
        var response = ""
        switch step.content {
        case .mysteryAnnouncement(let mystery):
            title = mystery.heading
            leader = mystery.title
        case .prayer(let id):
            let text = configuration.prayerBook.text(for: id)
            title = text.title
            leader = text.leader
            response = text.response
        }

        let waitingFor: String?
        if mode == .guided, phase == .awaitingResponse, !response.isEmpty {
            waitingFor = Self.opening(of: response)
        } else {
            waitingFor = nil
        }

        let stalled = now - lastProgressAt >= timing.tapHintDelay
        let showHint: Bool
        switch phase {
        case .awaitingResponse, .following: showHint = stalled
        default: showHint = false
        }

        return SessionSnapshot(
            mode: mode,
            phase: phase,
            stepIndex: index,
            stepCount: plan.steps.count,
            step: step,
            section: step.section,
            title: title,
            leaderText: leader,
            responseText: response,
            intention: step.intention,
            mysterySet: plan.mysterySet,
            mystery: decadeMystery,
            decadePosition: decade.flatMap { plan.decadeNumbers.firstIndex(of: $0) }.map { $0 + 1 },
            decadeTotal: plan.decadeNumbers.count,
            bead: step.bead,
            beadCount: step.beadCount,
            isEstimate: mode == .tracking,
            completedDecades: completedDecades,
            leader: decade.flatMap { configuration.decadeLeaders[$0] },
            nextLeaderBanner: nextLeaderBanner,
            nextSessionLeader: configuration.nextSessionLeader,
            showTapHint: showHint,
            listeningFor: waitingFor
        )
    }

    static func opening(of text: String) -> String {
        let words = text.split(separator: " ").prefix(4).joined(separator: " ")
        let trimmed = words.trimmingCharacters(in: CharacterSet(charactersIn: ",;:."))
        return trimmed + "…"
    }
}

/// Tells one Hail Mary from the next in tracking mode: fragments arrive in order within a
/// single Hail Mary, so hearing an earlier fragment again means a new one has begun.
struct HailMaryLatch {
    private var lastOrder: Int?
    private var startedAt: TimeInterval?

    var isActive: Bool { lastOrder != nil }

    func isNewRepetition(order: Int, at time: TimeInterval, maxDuration: TimeInterval) -> Bool {
        guard let lastOrder, let startedAt else { return true }
        return order <= lastOrder || time - startedAt > maxDuration
    }

    mutating func start(order: Int, at time: TimeInterval) {
        lastOrder = order
        startedAt = time
    }

    mutating func update(order: Int) {
        lastOrder = max(lastOrder ?? order, order)
    }

    mutating func clear() {
        lastOrder = nil
        startedAt = nil
    }
}
