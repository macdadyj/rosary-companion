import Testing
@testable import RosaryCore

/// MVP acceptance: one decade flows end to end in both modes, by voice and by tap.
@Suite("One decade, end to end")
struct DecadeFlowTests {
    // MARK: Guided ("You pray, I listen")

    @Test("Guided: the app leads, the person answers, the decade completes and the next person is named")
    func guidedDecadeByVoice() {
        let h = EngineHarness(mode: .guided, leaders: [1: "Dad"], nextSessionLeader: "Mom")
        h.start()
        #expect(h.spoken.last == "The First Joyful Mystery: The Annunciation.")
        #expect(h.snapshot.mystery?.id == .annunciation)
        #expect(h.snapshot.leader == "Dad")

        h.runUntilListening()
        #expect(h.step.prayerID == .ourFather)
        #expect(h.phase == .awaitingResponse)
        #expect(h.spoken.last?.hasPrefix("Our Father, who art in heaven") == true)
        #expect(h.snapshot.listeningFor == "Give us this day…")
        h.say(h.responseOfCurrentStep)

        for bead in 1...10 {
            h.runUntilListening()
            #expect(h.step.prayerID == .hailMary)
            #expect(h.snapshot.bead == bead)
            #expect(h.spoken.last?.hasPrefix("Hail Mary, full of grace") == true)
            h.say(h.responseOfCurrentStep)
        }

        h.runUntilListening()
        #expect(h.step.prayerID == .gloryBe)
        h.say(h.responseOfCurrentStep)

        h.runUntilListening()
        #expect(h.step.prayerID == .fatimaPrayer)
        #expect(h.phase == .awaitingResponse, "Nothing to narrate: the person prays the Fatima Prayer")
        h.say(h.responseOfCurrentStep)

        #expect(h.phase == .finished)
        #expect(h.decadesCompleted == [1])
        #expect(h.spoken.last == "Next time, Mom begins.")
        #expect(h.engine.advances.allSatisfy { $0.cause != .tap })
        let hailMaryAdvances = h.engine.advances.filter { h.engine.plan.steps[$0.from].prayerID == .hailMary }
        #expect(hailMaryAdvances.count == 10)
        #expect(hailMaryAdvances.allSatisfy { $0.cause == .voice }, "each Hail Mary ends on its closing phrase")
    }

    @Test("Guided: noisy recognition still counts all ten Hail Marys exactly once")
    func guidedNoisy() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.say(Noise.garble(h.responseOfCurrentStep), thenPause: 2.5)
        var counted: [Int] = []
        while h.phase != .finished {
            h.runUntilListening()
            if let bead = h.snapshot.bead, h.step.prayerID == .hailMary { counted.append(bead) }
            h.say(Noise.garble(h.responseOfCurrentStep), thenPause: 2.5)
        }
        #expect(counted == Array(1...10))
        #expect(h.decadesCompleted == [1])
        #expect(h.engine.advances.allSatisfy { $0.cause != .tap })
    }

    @Test("Guided: a response we can't match still counts after a pause")
    func guidedLenient() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.say("mumble something something the bread and the evil things", thenPause: 0.5)
        #expect(h.step.prayerID == .ourFather, "not yet: still within the pause")
        h.wait(2.5)
        #expect(h.step.prayerID == .hailMary)
        #expect(h.engine.advances.last?.cause == .voiceLenient)
    }

    @Test("Guided: the app's own narration is never mistaken for the person's answer")
    func guidedIgnoresNarrationEcho() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.say(h.responseOfCurrentStep)
        #expect(h.step.prayerID == .hailMary)
        #expect(h.phase == .speaking)
        // While the narrator speaks, the microphone hears it (and maybe a stale epoch).
        h.sendRaw("hail mary full of grace holy mary mother of god pray for us sinners now and at the hour of our death",
                  epoch: h.listenEpoch!, isFinal: true)
        h.sendRaw("give us this day our daily bread now and at the hour of our death", epoch: 1, isFinal: true)
        #expect(h.step.bead == 1)
        h.runUntilListening()
        #expect(h.step.bead == 1, "still waiting for the first real answer")
    }

    // MARK: Tracking ("I pray, you track")

    @Test("Tracking: the person prays a whole decade aloud; beads, Glory Be and Fatima are followed")
    func trackingDecadeByVoice() {
        let h = EngineHarness(scope: .fiveDecades, mode: .tracking,
                              leaders: [1: "Dad", 2: "Mom", 3: "Ann", 4: "Dad", 5: "Mom"])
        h.start()
        #expect(h.phase == .following)
        #expect(h.listenEpoch != nil)

        h.say(h.fullTextOfCurrentStep)
        #expect(h.step.mystery?.id == .annunciation)
        h.say(h.book.text(for: .ourFather).full)
        #expect(h.step.prayerID == .ourFather)

        let hailMary = h.book.text(for: .hailMary).full
        for bead in 1...10 {
            h.say(hailMary)
            #expect(h.step.bead == bead, "after Hail Mary \(bead)")
        }
        h.say(h.book.text(for: .gloryBe).full)
        #expect(h.step.prayerID == .gloryBe)
        h.say(h.book.text(for: .fatimaPrayer).full)

        #expect(h.decadesCompleted == [1])
        #expect(h.snapshot.nextLeaderBanner == "Mom")
        #expect(h.spoken.last == "Mom leads the next decade.")
        h.finishNarration()
        #expect(h.phase == .following)
        #expect(h.step.mystery?.id == .visitation)
        #expect(h.engine.estimatedSteps.isEmpty, "nothing had to be skipped")
    }

    @Test("Tracking: noisy recognition still follows the decade to completion")
    func trackingNoisy() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(Noise.garble(h.book.text(for: .ourFather).full))
        for _ in 1...10 { h.say(Noise.garble(h.book.text(for: .hailMary).full)) }
        #expect(h.step.bead == 10)
        h.say(Noise.garble(h.book.text(for: .gloryBe).full))
        h.say(Noise.garble(h.book.text(for: .fatimaPrayer).full), thenPause: 2.5)
        #expect(h.phase == .finished)
        #expect(h.decadesCompleted == [1])
    }

    @Test("Tracking: a missed Hail Mary is an estimate; the Glory Be and Fatima checkpoints still complete the decade")
    func trackingMissedHailMary() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        for bead in 1...10 {
            if bead == 4 {
                h.say("mm mm mm mm mm mm mm mm mm mm")
            } else {
                h.say(h.book.text(for: .hailMary).full)
            }
        }
        #expect(h.step.bead == 9, "one Hail Mary was unrecognisable")
        h.say(h.book.text(for: .gloryBe).full)
        #expect(h.step.prayerID == .gloryBe)
        #expect(h.engine.estimatedSteps.count == 1)
        h.say(h.book.text(for: .fatimaPrayer).full)
        #expect(h.phase == .finished)
    }

    @Test("Tracking: the Fatima Prayer completes the decade on silence even if its ending is missed")
    func trackingFatimaSilence() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        for _ in 1...10 { h.say(h.book.text(for: .hailMary).full) }
        h.say(h.book.text(for: .gloryBe).full)
        h.say("O my Jesus, forgive us our sins, save us from the fires of hell, mm mm mm", thenPause: 1.0)
        #expect(h.phase == .following)
        #expect(h.step.prayerID == .fatimaPrayer)
        h.wait(1.2)
        #expect(h.phase == .finished)
        #expect(h.engine.advances.last?.cause == .voiceSilence)
    }
}

@Suite("No double advance")
struct NoDoubleAdvanceTests {
    @Test("Guided: the recogniser repeating the last answer doesn't count it again")
    func repeatedPartials() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.say(h.responseOfCurrentStep)
        h.runUntilListening()
        h.say(h.responseOfCurrentStep)
        #expect(h.step.bead == 2)
        h.repeatLastPartial(times: 10)
        h.runUntilListening()
        #expect(h.step.bead == 2)
        h.repeatLastPartial(times: 10)
        #expect(h.step.bead == 2)
    }

    @Test("A tap right after a voice advance is absorbed; a deliberate later tap advances")
    func tapAfterVoice() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(h.book.text(for: .ourFather).full, thenPause: 0)
        h.say("Hail Mary, full of grace,", thenPause: 0.4)
        #expect(h.step.bead == 1)
        h.tap()
        #expect(h.step.bead == 1, "tap at the same moment the voice advanced")
        h.wait(1.0)
        h.tap()
        #expect(h.step.bead == 2)
    }

    @Test("Tracking: trailing words of the Our Father never skip to the next decade")
    func trailingOurFather() {
        let h = EngineHarness(scope: .fiveDecades, mode: .tracking)
        h.start()
        h.say("Our Father, who art in heaven, hallowed be thy name;", thenPause: 0)
        h.say("Hail Mary, full of grace,", thenPause: 0.4)
        #expect(h.step.bead == 1)
        h.say("but deliver us from evil", thenPause: 0)
        h.say("give us this day our daily bread", thenPause: 1)
        #expect(h.step.bead == 1)
        #expect(h.step.section == .decade(1))
    }

    @Test("Tracking: the end of the Fatima Prayer heard again after the decade completes doesn't skip ahead")
    func lateFatima() {
        let h = EngineHarness(scope: .fiveDecades, mode: .tracking, leaders: [1: "Dad", 2: "Mom"])
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        for _ in 1...10 { h.say(h.book.text(for: .hailMary).full) }
        h.say(h.book.text(for: .gloryBe).full)
        h.say(h.book.text(for: .fatimaPrayer).full)
        #expect(h.decadesCompleted == [1])
        h.finishNarration()
        let index = h.step.id
        h.say("especially those in most need of thy mercy save us from the fires of hell")
        #expect(h.step.id == index)
        #expect(h.decadesCompleted == [1])
    }

    @Test("Tracking: a recogniser restart that re-sends the closing phrase doesn't advance twice")
    func restartEcho() {
        let h = EngineHarness(mode: .tracking, leaders: [1: "Dad"])
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        for _ in 1...10 { h.say(h.book.text(for: .hailMary).full, thenPause: 0) }
        h.say("Glory be to the Father, and to the Son,", thenPause: 0)
        let gloryIndex = h.step.id
        h.restartRecogniserSegment()
        h.say("glory be to the father", thenPause: 0)
        #expect(h.step.id == gloryIndex)
    }
}

@Suite("Tap recovery")
struct TapRecoveryTests {
    @Test("Guided: when nothing is recognised, a hint appears and one tap moves on")
    func guidedSilentMic() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        #expect(h.step.prayerID == .ourFather)
        h.wait(10)
        #expect(h.step.prayerID == .ourFather)
        #expect(h.snapshot.showTapHint)
        h.tap()
        #expect(h.step.prayerID == .hailMary)
        #expect(h.phase == .speaking)
        #expect(h.haptics.last == .tapAdvance)
        #expect(!h.snapshot.showTapHint)
    }

    @Test("Tap during narration skips straight to the next prayer")
    func tapDuringNarration() {
        let h = EngineHarness(mode: .guided)
        h.start()
        #expect(h.phase == .speaking)
        h.tap()
        #expect(h.effects.contains(.stopSpeaking))
        #expect(h.step.prayerID == .ourFather)
        #expect(h.spoken.last?.hasPrefix("Our Father") == true)
    }

    @Test("A whole decade by taps alone (no microphone)")
    func tapsOnly() {
        let h = EngineHarness(mode: .tracking, leaders: [1: "Dad"], nextSessionLeader: "Mom")
        h.start()
        var taps = 0
        while h.phase != .finished {
            h.wait(1)
            h.tap()
            taps += 1
        }
        #expect(taps == 14)
        #expect(h.decadesCompleted == [1])
        #expect(h.spoken.last == "Next time, Mom begins.")
    }

    @Test("Tracking: tapping past a missed Hail Mary doesn't double count when its words arrive")
    func tapThenVoice() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        h.say(h.book.text(for: .hailMary).full)
        #expect(h.step.bead == 1)
        h.say("mm mm mm mm mm mm mm mm", thenPause: 0.5)   // Hail Mary 2, unrecognised
        h.tap()
        #expect(h.step.bead == 2)
        h.say("Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.")
        #expect(h.step.bead == 2, "the rest of the tapped Hail Mary belongs to bead 2")
        h.say(h.book.text(for: .hailMary).full)
        #expect(h.step.bead == 3)
    }

    @Test("Back steps to the previous prayer and re-reads it")
    func back() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.say(h.responseOfCurrentStep)
        h.runUntilListening()
        #expect(h.step.bead == 1)
        h.send(.back)
        #expect(h.step.prayerID == .ourFather)
        #expect(h.spoken.last?.hasPrefix("Our Father") == true)
    }
}

@Suite("Session controls")
struct SessionControlTests {
    @Test("An interruption pauses everything; resuming re-reads the current prayer")
    func interruption() {
        let h = EngineHarness(mode: .guided)
        h.start()
        h.runUntilListening()
        h.send(.pause(.interruption))
        #expect(h.phase == .paused(.interruption))
        #expect(h.effects.last == .stopListening)
        h.say(h.responseOfCurrentStep)
        #expect(h.step.prayerID == .ourFather, "nothing is heard while paused")
        h.send(.resume)
        #expect(h.phase == .speaking)
        #expect(h.spoken.last?.hasPrefix("Our Father") == true)
    }

    @Test("A tap while paused resumes rather than advancing")
    func tapResumes() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.send(.pause(.background))
        h.tap()
        #expect(h.phase == .following)
        #expect(h.step.id == 0)
    }

    @Test("Switching modes mid-decade keeps your place")
    func switchModes() {
        let h = EngineHarness(mode: .tracking)
        h.start()
        h.say(h.book.text(for: .ourFather).full)
        h.say(h.book.text(for: .hailMary).full)
        h.say(h.book.text(for: .hailMary).full)
        #expect(h.step.bead == 2)
        h.send(.switchMode(.guided))
        #expect(h.step.bead == 2)
        #expect(h.phase == .speaking)
        #expect(h.spoken.last?.hasPrefix("Hail Mary") == true)
        h.runUntilListening()
        h.say(h.responseOfCurrentStep)
        #expect(h.step.bead == 3)
        h.send(.switchMode(.tracking))
        #expect(h.phase == .following)
        #expect(h.effects.contains(.stopSpeaking))
    }

    @Test("Ending early stops listening and reports which decades were completed")
    func endEarly() {
        let h = EngineHarness(scope: .fiveDecades, mode: .tracking)
        h.start()
        for _ in 0..<14 { h.wait(1); h.tap() }
        #expect(h.decadesCompleted == [1])
        h.send(.end)
        #expect(h.phase == .finished)
        #expect(h.effects.contains(.finished))
        #expect(h.engine.completedDecades == [1])
    }

    @Test("The next-person banner dismisses on tap without advancing, and expires on its own")
    func banner() {
        let h = EngineHarness(scope: .fiveDecades, mode: .tracking, leaders: [1: "Dad", 2: "Mom"])
        h.start()
        for _ in 0..<14 { h.wait(1); h.tap() }
        #expect(h.snapshot.nextLeaderBanner == "Mom")
        let index = h.step.id
        h.finishNarration()
        h.wait(1)
        h.tap()
        #expect(h.snapshot.nextLeaderBanner == nil)
        #expect(h.step.id == index)

        for _ in 0..<14 { h.wait(1); h.tap() }
        #expect(h.snapshot.nextLeaderBanner == nil, "decade 3 has no leader configured")
    }
}
