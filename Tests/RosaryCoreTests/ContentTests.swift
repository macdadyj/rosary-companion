import Foundation
import Testing
@testable import RosaryCore

struct ContentTests {
    @Test func sha1MatchesKnownVectors() {
        #expect(ContentSHA1.hex("") == "da39a3ee5e6b4b0d3255bfef95601890afd80709")
        #expect(ContentSHA1.hex("abc") == "a9993e364706816aba3e25717850c26c9cd0d89d")
    }

    @Test func bundledTextsMatchTheirHashes() throws {
        let content = try PrayerContent.bundled()
        let problems = content.integrityProblems()
        #expect(problems.isEmpty, "\(problems.joined(separator: ", "))")
        #expect(content.scripture.passages.count == MysteryID.allCases.count)
        #expect(content.fruits.prayers.count == 15)
        #expect(content.litany.rows.count > 40)
        #expect(content.sorrows.sorrows.count == 7)
        #expect(content.art.works.count == MysteryID.allCases.count)
        #expect(content.slots.slots.contains { $0.id == "divine-mercy.decade" })
        #expect(content.passage(for: .annunciation)?.verses.first?.text.contains("angel Gabriel") == true)
        #expect(content.fruitPrayer(for: .baptism) == nil)
        #expect(content.fruitPrayer(for: .annunciation)?.prayer.hasSuffix("Amen.") == true)
    }

    @Test func feastsAndSeasonComeFromTheCalendars() throws {
        let content = try PrayerContent.bundled()
        let nativity = CivilDate(year: 2026, month: 9, day: 8)
        let ruthenian = content.feasts(on: nativity, rite: .ruthenian)
        #expect(ruthenian.contains { $0.name.localizedCaseInsensitiveContains("Nativity of the Theotokos") })
        let maternity = content.feasts(on: CivilDate(year: 2026, month: 12, day: 8), rite: .ruthenian)
        #expect(maternity.contains { $0.name.localizedCaseInsensitiveContains("Maternity") })
        let motherOfGod = content.feasts(on: CivilDate(year: 2026, month: 1, day: 1), rite: .western)
        #expect(motherOfGod.contains { $0.name.contains("Holy Mother of God") })

        #expect(LiturgicalCalendar.easter(year: 2026) == CivilDate(year: 2026, month: 4, day: 5))
        #expect(LiturgicalCalendar.easter(year: 2024) == CivilDate(year: 2024, month: 3, day: 31))
        let holySaturday = CivilDate(year: 2026, month: 4, day: 4)
        let easter = CivilDate(year: 2026, month: 4, day: 5)
        let before = holySaturday.adding(days: -1)
        #expect(MarianHours.usesReginaCaeli(on: holySaturday))
        #expect(MarianHours.usesReginaCaeli(on: easter))
        #expect(!MarianHours.usesReginaCaeli(on: before))

        let motherOfTheChurch = LiturgicalCalendar.easter(year: 2026).adding(days: 50)
        #expect(content.feasts(on: motherOfTheChurch, rite: .western).contains { $0.name.contains("Mother of the Church") })
    }

    @Test func sevenSorrowsAndMercyPlansCountBeads() throws {
        let content = try PrayerContent.bundled()
        let book = PrayerBook()
        let sorrows = DevotionCatalog.sevenSorrows(book: book, content: content)
        let hailMarys = sorrows.beads.filter { $0.prayer == .hailMary }
        #expect(hailMarys.count == 49)
        #expect(sorrows.beads.contains { $0.text?.hasPrefix("MY God") == true })
        #expect(sorrows.beads.allSatisfy { $0.text?.isEmpty == false })

        let mercy = DevotionCatalog.divineMercy(book: book, content: content)
        #expect(mercy.beads.filter { $0.slotID == "divine-mercy.decade" }.count == 50)
        #expect(mercy.beads.contains { $0.prayer == .ourFather && $0.text?.contains("Our Father") == true })
        #expect(mercy.beads.filter { $0.isSlot }.allSatisfy { $0.text == nil })
    }

    @Test func devotionVoiceAdvancesAHailMary() throws {
        let content = try PrayerContent.bundled()
        let plan = DevotionCatalog.sevenSorrows(book: PrayerBook(), content: content)
        let controller = DevotionController(plan: plan)
        while controller.bead?.prayer != .hailMary {
            controller.tap()
        }
        let start = controller.index
        controller.ingest(
            TranscriptUpdate(epoch: 0, segment: 0, text: "pray for us sinners now and at the hour of our death amen", isFinal: true),
            at: 1
        )
        #expect(controller.index == start + 1)
        #expect(controller.haptics.contains(.voiceAdvance))
    }

    @Test func consecrationSpansThirtyThreeDays() {
        let feast = CivilDate(year: 2026, month: 12, day: 8)
        let start = ConsecrationProgress.start(endingOn: feast)
        var progress = ConsecrationProgress(start: start)
        #expect(progress.dayNumber(on: start) == 1)
        #expect(progress.dayNumber(on: feast) == 33)
        #expect(progress.dayNumber(on: feast.adding(days: 1)) == nil)
        progress.checked = [1, 33]
        #expect(progress.finishedCount == 2)
    }

    @Test func watchCounterWrapsADecade() {
        var counter = WatchCounter()
        for _ in 0..<10 { counter.advance() }
        #expect(counter.label == "10 of 10")
        counter.advance()
        #expect(counter.bead == 1)
        #expect(counter.decades == 1)
        counter.back()
        #expect(counter.bead == 0)
        #expect(counter.decades == 1)
        counter.reset()
        #expect(counter.label == "Ready")
    }

    @Test func uiTagsAreUnique() {
        #expect(Set(UITag.all).count == UITag.all.count)
        #expect(UITag.all.count > 40)
    }
}
