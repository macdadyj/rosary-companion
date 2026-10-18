import Foundation
import Testing
@testable import RosaryCore

@Suite("Read-aloud meditations and the art gallery")
struct ReadAloudAndGalleryTests {
    @Test func aDecadeOpensWithTheAnnouncementOnlyUntilReadingIsOn() {
        let harness = EngineHarness(mode: .guided)
        harness.start()
        #expect(harness.spoken == ["The First Joyful Mystery: The Annunciation."])
        #expect(harness.phase == .speaking)
    }

    @Test func meditationsAreSpokenBeforeTheHold() throws {
        var configuration = SessionConfiguration(scope: .singleDecade(1), mysterySet: .joyful, mode: .guided)
        configuration.readsMeditations = true
        configuration.meditationScripture[.annunciation] = "Luke 1:26–38. The angel Gabriel was sent."
        configuration.meditationText[.annunciation] = "Humility."
        let harness = EngineHarness(configuration)
        harness.start()
        #expect(harness.spoken == ["The First Joyful Mystery: The Annunciation."])
        harness.finishNarration()
        #expect(harness.spoken[1] == "Luke 1:26–38. The angel Gabriel was sent.")
        harness.finishNarration()
        #expect(harness.spoken[2] == "Humility.")
        harness.finishNarration()
        #expect(harness.phase == .holding)

        harness.send(.setReadsMeditations(false))
        #expect(harness.snapshot.readsMeditations == false)
        #expect(harness.spoken.count == 3)
    }

    @Test func trackingSpeaksTheMeditationThenFollows() {
        var configuration = SessionConfiguration(scope: .singleDecade(1), mysterySet: .joyful, mode: .tracking)
        configuration.readsMeditations = true
        configuration.meditationScripture[.annunciation] = "Luke 1:26–38."
        configuration.meditationText[.annunciation] = "Humility."
        let harness = EngineHarness(configuration)
        harness.start()
        #expect(harness.phase == .speaking)
        harness.finishNarration()
        harness.finishNarration()
        harness.finishNarration()
        #expect(harness.phase == .following)
        #expect(harness.spoken.contains("Humility."))
    }

    @Test func guidedRosaryWaitsForATapOrThePause() {
        var timing = EngineTiming()
        timing.announcementHold = 1
        timing.guidedResponsePause = 6
        let configuration = SessionConfiguration(
            scope: .singleDecade(1), mysterySet: .joyful, mode: .guidedRosary, timing: timing
        )
        let harness = EngineHarness(configuration)
        harness.start()
        harness.finishNarration()
        #expect(harness.phase == .holding)
        harness.wait(1)
        #expect(harness.step.prayerID == .ourFather)
        harness.finishNarration()
        #expect(harness.phase == .holding)
        let index = harness.snapshot.stepIndex
        harness.wait(5.8)
        #expect(harness.snapshot.stepIndex == index)
        harness.send(.tap)
        #expect(harness.engine.advances.last?.cause == .tap)
        #expect(harness.snapshot.stepIndex == index + 1)
    }

    @Test func guidedRosaryAdvancesWhenTheQuietEnds() {
        var timing = EngineTiming()
        timing.announcementHold = 0.4
        timing.guidedResponsePause = 2
        let configuration = SessionConfiguration(
            scope: .singleDecade(1), mysterySet: .joyful, mode: .guidedRosary, timing: timing
        )
        let harness = EngineHarness(configuration)
        harness.start()
        harness.finishNarration()
        harness.wait(0.4)
        harness.finishNarration()
        let index = harness.snapshot.stepIndex
        harness.wait(2)
        #expect(harness.engine.advances.last?.cause == .hold)
        #expect(harness.snapshot.stepIndex == index + 1)
    }

    @Test func aUserPauseHoldsTheVoiceAndResumeContinuesIt() {
        let harness = EngineHarness(mode: .guided)
        harness.start()
        let paused = harness.send(.pause(.user))
        #expect(paused.contains(.pauseSpeaking))
        #expect(!paused.contains(.stopSpeaking))
        #expect(harness.phase == .paused(.user))
        let resumed = harness.send(.resume)
        #expect(resumed.contains(.resumeSpeaking))
        #expect(!resumed.contains(.speak(Narration("x"), id: 0, preDelay: 0)))
        #expect(harness.spoken.count == 1)
        #expect(harness.phase == .speaking)
    }

    @Test func anInterruptionStillRereadsThePrayer() {
        let harness = EngineHarness(mode: .guided)
        harness.start()
        harness.finishNarration()
        harness.wait(3)
        #expect(harness.phase == .speaking)
        #expect(harness.step.prayerID == .ourFather)
        let before = harness.spoken.count
        let paused = harness.send(.pause(.interruption))
        #expect(paused.contains(.stopSpeaking))
        harness.send(.resume)
        #expect(harness.spoken.count == before + 1)
        #expect(harness.spoken.last?.hasPrefix("Our Father") == true)
    }

    @Test func scriptureAndMeditationLinesCollapseWhitespace() throws {
        let content = try PrayerContent.bundled()
        let saints = try SaintsLibrary.bundled()
        let day = CivilDate(year: 2026, month: 10, day: 18)
        let scripts = DecadeReading.scripts(content: content, saints: saints, day: day)
        let scripture = try #require(scripts.scripture[.annunciation])
        #expect(scripture.contains("Luke"))
        #expect(!scripture.contains("\n"))
        let meditation = try #require(scripts.meditation[.annunciation])
        #expect(!meditation.isEmpty)
        #expect(DecadeReading.scriptureLine(reference: "Luke 1:26–38", body: "") == "Luke 1:26–38")
        #expect(DecadeReading.meditationLine(contemplate: "  Humility. ", quote: nil) == "Humility.")
        let lines = DecadeReading.narrations(
            announcement: Narration("Announced."),
            scripture: "",
            meditation: ""
        )
        #expect(lines.map(\.text) == ["Announced."])
    }

    @Test func theGalleryPagesAcrossMysteriesAndWraps() {
        let annunciation = SacredWork(
            mystery: .annunciation, file: "a.jpg", title: "Annunciation", artist: "Fra Angelico",
            credit: "Painted in 1435.", license: "Public domain", sourceURL: "https://example.test/a",
            commonsSha1: "sha-a", sha1: "file-a"
        )
        let visitation = SacredWork(
            mystery: .visitation, file: "v.jpg", title: "Visitation", artist: "",
            credit: "No year named.", license: "Public domain", sourceURL: "https://example.test/v",
            commonsSha1: "sha-v", sha1: "file-v"
        )
        let cached = SacredArtRecord(
            mystery: .annunciation, tradition: .byzantine, title: "The Annunciation, 12th century icon",
            artist: "Novgorod", license: "Public domain", sourceURL: "https://example.test/icon",
            sha1: "sha-icon", fileName: "icon.jpg", savedAt: Date(timeIntervalSince1970: 10)
        )
        let duplicate = SacredArtRecord(
            mystery: .annunciation, tradition: .western, title: "Same file",
            artist: "Copy", license: "Public domain", sourceURL: "https://example.test/copy",
            sha1: "sha-a", fileName: "copy.jpg", savedAt: Date(timeIntervalSince1970: 20)
        )
        let gallery = ArtGallery.assemble(works: [visitation, annunciation], records: [cached, duplicate], focus: .annunciation)
        #expect(gallery.positionLabel == "1 of 3")
        #expect(gallery.plate?.title == "Annunciation")
        #expect(gallery.plate?.date == "1435")
        #expect(gallery.plate?.caption == "Annunciation · Fra Angelico · 1435 · Public domain")
        let next = gallery.stepped(1)
        #expect(next.plate?.title == "The Annunciation, 12th century icon")
        #expect(next.positionLabel == "2 of 3")
        let wrapped = gallery.stepped(-1)
        #expect(wrapped.plate?.mystery == .visitation)
        #expect(wrapped.plate?.date.isEmpty == true)
        #expect(wrapped.plate?.caption.contains(" ·  · ") == false)
        #expect(ArtCaption.year(in: "about 1892, restored") == "1892")
        #expect(ArtCaption.year(in: "no date") == nil)
        #expect(ArtCaption.line(title: "Icon", artist: "", date: "", source: "Commons") == "Icon · Commons")
    }

    @Test func novenaDaysAndTheReminder() {
        let start = CivilDate(year: 2026, month: 10, day: 18)
        let novena = Novena(intention: "  for peace  ", start: start)
        #expect(novena.dayNumber(on: start) == 1)
        #expect(novena.dayNumber(on: start.adding(days: 8)) == 9)
        #expect(novena.dayNumber(on: start.adding(days: 9)) == nil)
        #expect(novena.dayNumber(on: start.adding(days: -1)) == nil)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 6, minute: 30))!
        let next = ReminderPlan.nextDate(after: morning, hour: 7, minute: 0, calendar: calendar)
        let parts = calendar.dateComponents([.day, .hour, .minute], from: next)
        #expect(parts.day == 18)
        #expect(parts.hour == 7)
        #expect(parts.minute == 0)
        let evening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 8))!
        let tomorrow = ReminderPlan.nextDate(after: evening, hour: 7, minute: 0, calendar: calendar)
        #expect(calendar.component(.day, from: tomorrow) == 19)

        let message = ReminderPlan.message(
            mysteries: "The Glorious Mysteries",
            feast: "Saint Luke",
            novenaDay: 3,
            intention: "for peace"
        )
        #expect(message.contains("The Glorious Mysteries"))
        #expect(message.contains("Saint Luke"))
        #expect(message.contains("day 3 of 9"))
        #expect(message.contains("for peace"))
    }

    @Test func theWidgetNamesBothCalendars() throws {
        let content = try PrayerContent.bundled()
        let lectionary = try? LectionaryLibrary.bundled()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18))!
        let card = TodayCard.make(date: date, calendar: calendar, content: content, lectionary: lectionary)
        #expect(card.title.contains("Mysteries"))
        #expect(card.detail.contains("Ruthenian"))
        #expect(card.detail.contains("Roman"))
        if lectionary != nil {
            #expect(card.detail.contains("Gospel:") || card.detail.contains("Green") || card.detail.contains("White") || card.detail.contains("Violet") || card.detail.contains("Red") || card.detail.contains("Rose"))
        }
    }

    @Test @MainActor func favoritesAndRecentsRoundTrip() throws {
        let model = AppModel(store: nil, now: { Date(timeIntervalSince1970: 1_700_000_000) })
        #expect(model.settings.readsMeditationsAloud)
        model.toggleFavorite("memorare")
        #expect(model.isFavorite("memorare"))
        model.toggleFavorite("memorare")
        #expect(!model.isFavorite("memorare"))
        model.rememberPrayer("hail-holy-queen")
        model.rememberPrayer("memorare")
        model.rememberPrayer("memorare")
        #expect(model.settings.recentPrayerIDs == ["memorare", "hail-holy-queen"])
        model.beginNovena(intention: "for Jon", on: CivilDate(year: 2026, month: 10, day: 18))
        #expect(model.settings.novena?.dayNumber(on: CivilDate(year: 2026, month: 10, day: 18)) == 1)
        let prepared = model.prepare(model.defaultSetup())
        #expect(prepared.configuration.readsMeditations)
        #expect(prepared.configuration.meditationScripture[.annunciation]?.isEmpty == false)
        let data = try JSONEncoder().encode(model.settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.novena?.intention == "for Jon")
        #expect(decoded.recentPrayerIDs == ["memorare", "hail-holy-queen"])
    }
}
