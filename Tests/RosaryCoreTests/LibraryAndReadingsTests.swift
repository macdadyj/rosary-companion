import Foundation
import Testing
@testable import RosaryCore

struct MysteryJumpTests {
    @Test func fiveDecadeJumpLandsOnTheOurFather() {
        let harness = EngineHarness(scope: .fiveDecades, set: .sorrowful, mode: .tracking)
        harness.start()
        harness.send(.jumpToDecade(3))
        #expect(harness.step.prayerID == .ourFather)
        #expect(harness.step.section == .decade(3))
        #expect(harness.engine.completedDecades.isEmpty)
        #expect(harness.decadesCompleted.isEmpty)
        let lastOfFirst = harness.engine.plan.lastStepIndex(ofDecade: 1)!
        let again = EngineHarness(scope: .fiveDecades, set: .sorrowful, mode: .tracking)
        again.start()
        while again.engine.index <= lastOfFirst {
            again.send(.tap)
        }
        #expect(again.engine.completedDecades == [1])
        again.send(.jumpToDecade(4))
        #expect(again.step.prayerID == .ourFather)
        #expect(again.step.section == .decade(4))
        #expect(again.engine.completedDecades == [1])
        let progress = BeadProgress.progress(for: harness.step)
        #expect(progress?.count == 10)
        #expect(progress?.completed == 0)
        #expect(progress?.current == nil)
        harness.send(.tap)
        #expect(harness.step.prayerID == .hailMary)
        #expect(harness.step.bead == 1)
        #expect(harness.step.section == .decade(3))
    }

    @Test func oneDecadeSessionCanChangeMystery() {
        let harness = EngineHarness(scope: .singleDecade(1), set: .sorrowful, mode: .tracking)
        harness.start()
        harness.send(.jumpToDecade(4))
        #expect(harness.step.prayerID == .ourFather)
        #expect(harness.step.section == .decade(4))
        #expect(harness.snapshot.mystery?.id == .carryingCross)
        #expect(harness.engine.completedDecades.isEmpty)
        #expect(harness.snapshot.decadeTotal == 1)
        #expect(harness.decadesCompleted.isEmpty)
    }
}

struct PrayerLibraryTests {
    @Test func everyPrayerIsCompleteAndLicensed() throws {
        let content = try PrayerContent.bundled()
        let prayers = PrayerLibrary.catalog(book: PrayerBook(), content: content)
        let categories = Set(prayers.map(\.category))
        #expect(categories == Set(PrayerCategory.allCases))
        #expect(prayers.allSatisfy { $0.body.count > $0.title.count })
        #expect(prayers.allSatisfy { !$0.body.contains("…") })
        #expect(prayers.allSatisfy { !$0.body.hasSuffix("...") })
        let loreto = try #require(prayers.first { $0.id == "litany-loreto" })
        #expect(loreto.body.hasPrefix("Lord have mercy."))
        #expect(loreto.body.contains("May the divine assistance remain always with us."))
        let heart = try #require(prayers.first { $0.id == "litany-sacred-heart" })
        #expect(heart.body.contains("Heart of Jesus, Son of the Eternal Father"))
        #expect(heart.body.contains("delight of all the saints"))
        let joseph = try #require(prayers.first { $0.id == "litany-st-joseph" })
        #expect(joseph.body.contains("Renowned offspring of David"))
        #expect(joseph.body.contains("Protector of Holy Church"))
        let mercy = try #require(prayers.first { $0.id == "divine-mercy" })
        #expect(mercy.body.contains("Marians of the Immaculate Conception"))
        #expect(!mercy.body.localizedCaseInsensitiveContains("For the sake of His sorrowful Passion"))
        #expect(PrayerLibrary.matching("Memorare", in: prayers).contains { $0.id == "memorare" })
    }

    @Test func categoryChipsStayShort() {
        let chips = PrayerCategory.allCases.map(\.chipTitle)
        #expect(Set(chips).count == PrayerCategory.allCases.count)
        #expect(chips.allSatisfy { $0.count <= 12 })
        #expect(PrayerCategory.protection.chipTitle == "Protection")
        #expect(PrayerCategory.protection.title == "Saint Michael and protection")
    }

    @Test func addedPrayersAreComplete() throws {
        let content = try PrayerContent.bundled()
        let prayers = PrayerLibrary.catalog(book: PrayerBook(), content: content)
        let ids = prayers.map(\.id)
        #expect(Set(ids).count == ids.count)
        let faith = try #require(prayers.first { $0.id == "act-of-faith" })
        #expect(faith.body.contains("who canst neither deceive nor be deceived"))
        #expect(!faith.body.contains("Amen"))
        let depths = try #require(prayers.first { $0.id == "de-profundis" })
        #expect(depths.body.contains("Out of the depths I have cried to thee, O Lord"))
        #expect(depths.body.contains("8 And he shall redeem Israel from all his iniquities."))
        let benedictus = try #require(prayers.first { $0.id == "benedictus" })
        #expect(benedictus.body.contains("68 Blessed be the Lord God of Israel"))
        #expect(benedictus.body.contains("79 To enlighten them that sit in darkness"))
        let creed = try #require(prayers.first { $0.id == "apostlesCreed" })
        #expect(creed.body.contains("life everlasting"))
        let tantum = try #require(prayers.first { $0.id == "tantum-ergo" })
        #expect(tantum.body.contains("Genitori, Genitoque"))
        #expect(tantum.body.contains("Panem de coelo praestitisti eis"))
    }

    @Test func saintMichaelChapletPrintsEverySalutation() {
        let plan = DevotionCatalog.stMichaelChaplet(book: PrayerBook())
        let text = plan.fullText
        for choir in ["Seraphim", "Cherubim", "Thrones", "Dominions", "Powers", "Virtues", "Principalities", "Archangels", "Angels"] {
            #expect(text.contains(choir))
        }
        #expect(text.contains("Guardian Angel"))
        #expect(text.contains("defend us in battle"))
        #expect(text.contains("Our Father, who art in heaven"))
        #expect(text.contains("Hail Mary, full of grace"))
        #expect(!text.contains("…"))
        #expect(plan.beads.filter { $0.prayer == .hailMary }.count == 27)
        #expect(plan.beads.contains { $0.hailMaryCount == 3 })
    }
}

struct ReadingsTests {
    @Test func usccbLinkAndColorsFollowTheCalendar() {
        let october = CivilDate(year: 2026, month: 10, day: 17)
        #expect(LiturgicalCalendar.usccbReadingsURL(for: october).absoluteString == "https://bible.usccb.org/bible/readings/101726.cfm")
        #expect(LiturgicalCalendar.day(october).color == .green)
        #expect(LiturgicalCalendar.day(october).season == .ordinary)

        let easter = CivilDate(year: 2026, month: 4, day: 5)
        #expect(LiturgicalCalendar.day(easter).color == .white)
        #expect(LiturgicalCalendar.day(easter).title == "Easter Sunday")
        let goodFriday = CivilDate(year: 2026, month: 4, day: 3)
        #expect(LiturgicalCalendar.day(goodFriday).color == .red)
        let pentecost = LiturgicalCalendar.pentecost(year: 2026)
        #expect(pentecost == CivilDate(year: 2026, month: 5, day: 24))
        #expect(LiturgicalCalendar.day(pentecost).color == .red)
        let ashWednesday = LiturgicalCalendar.ashWednesday(year: 2026)
        #expect(LiturgicalCalendar.day(ashWednesday).color == .violet)
        #expect(LiturgicalCalendar.day(LiturgicalCalendar.laetareSunday(year: 2026)).color == .rose)
        #expect(LiturgicalCalendar.day(CivilDate(year: 2026, month: 12, day: 25)).color == .white)
    }

    @Test func citationsResolveAndDouayTextIsChalloner() throws {
        let magnificat = ScriptureCitation.alternatives(in: "Luke 1:46-55")
        #expect(magnificat.count == 1)
        #expect(magnificat[0].count == 1)
        #expect(magnificat[0][0].book == "Luke")
        #expect(magnificat[0][0].startVerse == 46)
        #expect(magnificat[0][0].endVerse == 55)

        let psalm = ScriptureCitation.alternatives(in: "Psalm 8:2-3ab, 4-5, 6-7")
        #expect(psalm[0].map(\.startVerse) == [2, 4, 6])
        let choice = ScriptureCitation.alternatives(in: "Matthew 4:12-23 or 4:12-17")
        #expect(choice.count == 2)
        #expect(choice[1][0].book == "Matthew")
        #expect(choice[1][0].endVerse == 17)

        let library = try LectionaryLibrary.bundled()
        let day = try #require(library.day(on: CivilDate(year: 2026, month: 10, day: 17)))
        #expect(day.gospel == "Luke 12:8-12")
        #expect(day.firstReading == "Ephesians 1:15-23")
        let gospel = library.text(for: day.gospel!)
        #expect(gospel.contains("Whosoever shall confess me before men"))
        #expect(gospel.contains("For the Holy Ghost shall teach you"))
        let praise = library.text(for: "Luke 1:46-55")
        #expect(praise.contains("My soul doth magnify the Lord"))
        #expect(praise.contains("to Abraham and to his seed for ever"))
    }
}
