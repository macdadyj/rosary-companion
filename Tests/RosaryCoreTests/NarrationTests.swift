import Foundation
import Testing
@testable import RosaryCore

@Suite("Narration: what is said, and which recording could say it")
struct NarrationTests {
    /// Taps through a guided session, collecting everything the app asked to say.
    private func guidedNarrations(
        _ configuration: SessionConfiguration, taps: Int
    ) -> [Narration] {
        let h = EngineHarness(configuration)
        h.start()
        for _ in 0..<taps {
            h.wait(0.5)
            h.tap()
        }
        return h.narrations
    }

    @Test func guidedNarrationTagsFixedWordingWithRecordingSlots() {
        let narrations = guidedNarrations(
            SessionConfiguration(scope: .fullRosary, mysterySet: .sorrowful, mode: .guided), taps: 8
        )
        let book = PrayerBook()

        #expect(narrations.first?.parts == [
            Narration.Part(book.text(for: .signOfTheCross).leader, clip: .leaderPart(.signOfTheCross, holyGhost: false)),
        ])

        let faith = narrations.first { $0.parts.first?.clip == .intention(.faith) }
        #expect(faith?.parts.map(\.clip) == [.intention(.faith), .leaderPart(.hailMary, holyGhost: false)])
        #expect(faith?.text == "For an increase of faith. \(book.text(for: .hailMary).leader)")

        let announcement = narrations.first { $0.parts.first?.clip == .mysteryAnnouncement(.agonyInGarden) }
        #expect(announcement?.text == "The First Sorrowful Mystery: The Agony in the Garden.")
    }

    @Test func holyGhostWordingHasItsOwnRecordingsOnlyWhereTheWordsChange() {
        let book = PrayerBook(usesHolyGhost: true)
        #expect(book.leaderPart(for: .gloryBe)?.clip == .leaderPart(.gloryBe, holyGhost: true))
        #expect(book.leaderPart(for: .gloryBe)?.text.contains("Holy Ghost") == true)
        #expect(book.leaderPart(for: .hailMary)?.clip == .leaderPart(.hailMary, holyGhost: false))
        #expect(book.leaderPart(for: .fatimaPrayer) == nil, "Everyone prays the Fatima Prayer together")
        #expect(PrayerBook().leaderPart(for: .gloryBe)?.clip == .leaderPart(.gloryBe, holyGhost: false))
    }

    @Test func namesAreNeverTaggedForRecording() {
        let narrations = guidedNarrations(
            SessionConfiguration(
                scope: .fiveDecades, mysterySet: .joyful, mode: .guided,
                decadeLeaders: [1: "Dad", 2: "Mom", 3: "Anna", 4: "Dad", 5: "Mom"], nextSessionLeader: "Anna"
            ),
            taps: 20
        )
        let names = narrations.filter { $0.text.contains("leads the next decade") }
        #expect(names.map(\.text) == ["Mom leads the next decade."])
        #expect(names.allSatisfy { $0.parts.allSatisfy { $0.clip == nil } })
    }

    @Test func recordingSlotsHaveUniqueFileNames() {
        let names = NarrationClip.all.map(\.fileName)
        #expect(Set(names).count == names.count)
        #expect(names.count == 34, "8 leader parts, 3 Holy Ghost variants, 3 intentions, 20 mysteries")
        #expect(names.contains("prayer.gloryBe.holyGhost"))
        #expect(names.contains("prayer.apostlesCreed.holyGhost"))
        #expect(!names.contains("prayer.hailMary.holyGhost"))
        #expect(!names.contains { $0.hasPrefix("prayer.fatimaPrayer") })
        #expect(names.contains("intention.faith"))
        #expect(names.contains("mystery.scourging"))
    }
}

@Suite("Speech pacing")
struct SpeechPacingTests {
    let pacing = SpeechPacing()

    @Test func pausesAtClauseAndSentenceEndsButNotCommas() {
        let phrases = pacing.phrases(in: PrayerBook().text(for: .ourFather).leader, finalPause: 0.6)
        #expect(phrases.map(\.text) == [
            "Our Father, who art in heaven, hallowed be thy name;",
            "thy kingdom come, thy will be done on earth as it is in heaven.",
        ])
        #expect(phrases.map(\.pauseAfter) == [pacing.clausePause, 0.6])
    }

    @Test func announcementPausesAfterTheHeading() {
        let phrases = pacing.phrases(in: Mystery.with(id: .scourging).announcement)
        #expect(phrases.map(\.text) == ["The Second Sorrowful Mystery:", "The Scourging at the Pillar."])
        #expect(phrases.map(\.pauseAfter) == [pacing.clausePause, 0])
    }

    @Test func sentencesGetTheLongerPause() {
        let phrases = pacing.phrases(in: PrayerBook().text(for: .closingPrayer).leader)
        #expect(phrases.first?.text == "Let us pray.")
        #expect(phrases.first?.pauseAfter == pacing.sentencePause)
        #expect(phrases.last?.text.hasSuffix("through the same Christ our Lord. Amen.") == false)
        #expect(phrases.last?.text == "Amen.")
    }

    @Test func abbreviationsInitialsAndNumbersDoNotEndASentence() {
        #expect(pacing.phrases(in: "St. Joseph leads the next decade.").count == 1)
        #expect(pacing.phrases(in: "Fr. J. Smith begins.").count == 1)
        #expect(pacing.phrases(in: "Psalm 3.5 says so.").count == 1)
        #expect(pacing.phrases(in: "Mary said yes. Then she went.").count == 2)
    }

    @Test func closingQuotesStayWithTheirSentence() {
        let phrases = pacing.phrases(in: #"He said, "Behold the man!" Then silence."#)
        #expect(phrases.map(\.text) == [#"He said, "Behold the man!""#, "Then silence."])
    }

    @Test func nothingToSayGivesNoPhrases() {
        #expect(pacing.phrases(in: "").isEmpty)
        #expect(pacing.phrases(in: "  ;  . ").isEmpty)
    }

    @Test func rateAndPitchAreCarriedAndKeptInRange() {
        let phrase = SpeechPacing(rate: 0.5, pitch: 1).phrases(in: "Amen.").first
        #expect(phrase?.rate == 0.5)
        #expect(phrase?.pitch == 1)
        let extreme = SpeechPacing(rate: 2, pitch: 0)
        #expect(extreme.rate == SpeechPacing.rateRange.upperBound)
        #expect(extreme.pitch == SpeechPacing.pitchRange.lowerBound)
    }

    @Test func defaultPaceIsCalmButNotDragging() {
        let calm = SpeechPacing()
        #expect(calm.rate < 0.5, "a little slower than conversation")
        #expect(calm.rate > 0.4, "slowing words further is what makes voices sound robotic")
        #expect(calm.pitch < 1)
    }
}

@Suite("Narration planner and recordings")
struct NarrationPlannerTests {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("rosary-recordings-\(UUID().uuidString)")

    private var faithHailMary: Narration {
        let book = PrayerBook()
        return Narration([OpeningIntention.faith.spokenPart, book.leaderPart(for: .hailMary)!])
    }

    private func addRecording(_ name: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data([0]).write(to: url)
        return url
    }

    @Test func withoutRecordingsEverythingIsSynthesizedWithPausesBetweenParts() {
        let planner = NarrationPlanner()
        let items = planner.items(for: faithHailMary)
        let phrases = items.compactMap { item -> SpokenPhrase? in
            if case .synthesized(let phrase) = item { phrase } else { nil }
        }
        #expect(phrases.count == items.count)
        #expect(phrases.map(\.text) == [
            "For an increase of faith.",
            "Hail Mary, full of grace, the Lord is with thee;",
            "blessed art thou among women, and blessed is the fruit of thy womb, Jesus.",
        ])
        #expect(phrases.map(\.pauseAfter) == [planner.pacing.partPause, planner.pacing.clausePause, 0])
    }

    @Test func aRecordingReplacesItsPartAndKeepsSpeechAsAFallback() throws {
        let url = try addRecording("prayer.hailMary.m4a")
        let planner = NarrationPlanner(recordings: RecordingFolder(directory: directory))
        let items = planner.items(for: faithHailMary)
        #expect(items.count == 2)
        #expect(items.first == .synthesized(SpokenPhrase(
            text: "For an increase of faith.", rate: planner.pacing.rate, pitch: planner.pacing.pitch,
            pauseAfter: planner.pacing.partPause
        )))
        guard case .recording(let found, let fallback, let pause) = items.last else {
            Issue.record("expected the Hail Mary to be played from its recording")
            return
        }
        #expect(found.standardizedFileURL == url.standardizedFileURL)
        #expect(fallback.map(\.text) == planner.pacing.phrases(in: PrayerBook().text(for: .hailMary).leader).map(\.text))
        #expect(pause == 0)
    }

    @Test func recordingFolderFindsAnySupportedFormat() throws {
        _ = try addRecording("mystery.scourging.caf")
        _ = try addRecording("notes.txt")
        let folder = RecordingFolder(directory: directory)
        #expect(folder.recording(for: .mysteryAnnouncement(.scourging))?.pathExtension == "caf")
        #expect(folder.recording(for: .mysteryAnnouncement(.resurrection)) == nil)
        #expect(RecordingFolder(directory: directory.appendingPathComponent("missing")).recording(for: .intention(.hope)) == nil)
    }

    @Test func namesAreAlwaysSynthesizedEvenIfAFileMatches() throws {
        _ = try addRecording("Mom leads the next decade..m4a")
        let planner = NarrationPlanner(recordings: RecordingFolder(directory: directory))
        let items = planner.items(for: Narration("Mom leads the next decade."))
        #expect(items.allSatisfy { if case .synthesized = $0 { true } else { false } })
    }

    @Test func bundledRecordingsFolderExists() {
        #expect(RecordingFolder.bundled != nil)
    }
}
