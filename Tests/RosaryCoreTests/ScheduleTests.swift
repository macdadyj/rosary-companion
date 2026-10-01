import Testing
@testable import RosaryCore

@Suite("Mystery schedule")
struct ScheduleTests {
    @Test("Weekday sets: Mon & Sat Joyful, Tue & Fri Sorrowful, Wed & Sun Glorious, Thu Luminous")
    func weekdays() {
        // 2026-09-27 is a Sunday.
        let sunday = CivilDate(year: 2026, month: 9, day: 27)
        let expected: [MysterySet] = [.glorious, .joyful, .sorrowful, .glorious, .luminous, .sorrowful, .joyful]
        for (offset, set) in expected.enumerated() {
            let day = sunday.adding(days: offset)
            #expect(day.weekday == offset + 1)
            #expect(MysterySchedule.set(for: day, seasonalSundays: false) == set)
            #expect(MysterySchedule.set(for: day, seasonalSundays: true) == set, "Ordinary Time is unaffected")
        }
    }

    @Test("Civil dates round-trip and know their weekday")
    func civilDates() {
        let date = CivilDate(year: 2024, month: 2, day: 29)
        #expect(CivilDate(dayNumber: date.dayNumber) == date)
        #expect(CivilDate(year: 1970, month: 1, day: 1).dayNumber == 0)
        #expect(CivilDate(year: 1970, month: 1, day: 1).weekday == 5)
        #expect(CivilDate(year: 2000, month: 1, day: 1).weekday == 7)
        #expect(date.adding(days: 1) == CivilDate(year: 2024, month: 3, day: 1))
    }

    @Test("Easter dates", arguments: [
        (2024, 3, 31), (2025, 4, 20), (2026, 4, 5), (2027, 3, 28), (2038, 4, 25), (2019, 4, 21),
    ])
    func easter(year: Int, month: Int, day: Int) {
        #expect(LiturgicalCalendar.easter(year: year) == CivilDate(year: year, month: month, day: day))
    }

    @Test("First Sunday of Advent")
    func advent() {
        #expect(LiturgicalCalendar.firstSundayOfAdvent(year: 2023) == CivilDate(year: 2023, month: 12, day: 3))
        #expect(LiturgicalCalendar.firstSundayOfAdvent(year: 2024) == CivilDate(year: 2024, month: 12, day: 1))
        #expect(LiturgicalCalendar.firstSundayOfAdvent(year: 2026) == CivilDate(year: 2026, month: 11, day: 29))
        #expect(LiturgicalCalendar.firstSundayOfAdvent(year: 2028) == CivilDate(year: 2028, month: 12, day: 3))
    }

    @Test("Seasonal Sundays: Advent and Christmastide Joyful, Lent Sorrowful")
    func seasonalSundays() {
        let adventSunday = CivilDate(year: 2026, month: 12, day: 6)
        let holyFamily = CivilDate(year: 2026, month: 12, day: 27)
        let baptismSunday = CivilDate(year: 2027, month: 1, day: 10)
        let afterChristmas = CivilDate(year: 2027, month: 1, day: 17)
        let lentSunday = CivilDate(year: 2026, month: 3, day: 1)
        let palmSunday = CivilDate(year: 2026, month: 3, day: 29)
        let easterSunday = CivilDate(year: 2026, month: 4, day: 5)
        let beforeAdvent = CivilDate(year: 2026, month: 11, day: 22)

        for day in [adventSunday, holyFamily, baptismSunday, afterChristmas, lentSunday, palmSunday,
                    easterSunday, beforeAdvent] {
            #expect(day.isSunday, "\(day) should be a Sunday")
            #expect(MysterySchedule.set(for: day, seasonalSundays: false) == .glorious)
        }
        #expect(MysterySchedule.set(for: adventSunday, seasonalSundays: true) == .joyful)
        #expect(MysterySchedule.set(for: holyFamily, seasonalSundays: true) == .joyful)
        #expect(MysterySchedule.set(for: baptismSunday, seasonalSundays: true) == .joyful)
        #expect(MysterySchedule.set(for: afterChristmas, seasonalSundays: true) == .glorious)
        #expect(MysterySchedule.set(for: lentSunday, seasonalSundays: true) == .sorrowful)
        #expect(MysterySchedule.set(for: palmSunday, seasonalSundays: true) == .sorrowful)
        #expect(MysterySchedule.set(for: easterSunday, seasonalSundays: true) == .glorious)
        #expect(MysterySchedule.set(for: beforeAdvent, seasonalSundays: true) == .glorious)

        let lentWeekday = CivilDate(year: 2026, month: 3, day: 5)
        #expect(MysterySchedule.set(for: lentWeekday, seasonalSundays: true) == .luminous, "Only Sundays change")
    }
}

@Suite("Rosary structure")
struct PlanTests {
    @Test("Twenty mysteries, five per set, in order")
    func mysteries() {
        #expect(Mystery.all.count == 20)
        #expect(Set(Mystery.all.map(\.id)).count == 20)
        for set in MysterySet.allCases {
            #expect(set.mysteries.map(\.number) == [1, 2, 3, 4, 5])
        }
        #expect(Mystery.with(id: .annunciation).announcement == "The First Joyful Mystery: The Annunciation.")
        #expect(Mystery.with(id: .eucharist).heading == "The Fifth Luminous Mystery")
    }

    @Test("A single decade: announcement, Our Father, ten Hail Marys, Glory Be, Fatima Prayer")
    func singleDecade() {
        let plan = RosaryPlan(scope: .singleDecade(3), mysterySet: .sorrowful)
        #expect(plan.steps.count == 14)
        #expect(plan.steps[0].mystery?.id == .crowningWithThorns)
        #expect(plan.steps[1].prayerID == .ourFather)
        #expect(plan.steps[2...11].allSatisfy { $0.prayerID == .hailMary })
        #expect(plan.steps[2...11].map { $0.bead! } == Array(1...10))
        #expect(plan.steps[12].prayerID == .gloryBe)
        #expect(plan.steps[13].prayerID == .fatimaPrayer)
        #expect(plan.isLastStepOfDecade(13))
        #expect(!plan.isLastStepOfDecade(12))
    }

    @Test("Full Rosary: opening, five decades, closing")
    func fullRosary() {
        let plan = RosaryPlan(scope: .fullRosary, mysterySet: .glorious, openingIntentions: true)
        let prayers = plan.steps.map { $0.prayerID }
        #expect(plan.steps.count == 7 + 5 * 14 + 4)
        #expect(Array(prayers.prefix(7)) == [.signOfTheCross, .apostlesCreed, .ourFather,
                                             .hailMary, .hailMary, .hailMary, .gloryBe])
        #expect(plan.steps[3...5].map { $0.intention } == [.faith, .hope, .charity])
        #expect(Array(prayers.suffix(4)) == [.hailHolyQueen, .rosaryVersicle, .closingPrayer, .signOfTheCross])
        #expect(plan.steps.filter { $0.prayerID == .hailMary }.count == 53)
        #expect(plan.steps.compactMap(\.mystery).map(\.number) == [1, 2, 3, 4, 5])

        let noIntentions = RosaryPlan(scope: .fullRosary, mysterySet: .glorious, openingIntentions: false)
        #expect(noIntentions.steps[3...5].allSatisfy { $0.intention == nil })
    }

    @Test("Prayer texts are split for leader and response")
    func prayerTexts() {
        let book = PrayerBook()
        let hailMary = book.text(for: .hailMary)
        #expect(hailMary.leader.hasPrefix("Hail Mary, full of grace"))
        #expect(hailMary.response.hasPrefix("Holy Mary, Mother of God"))
        #expect(book.text(for: .fatimaPrayer).leader.isEmpty)
        #expect(book.text(for: .closingPrayer).leader.contains("O God, whose only-begotten Son"))
        #expect(book.text(for: .hailHolyQueen).response.hasSuffix("O sweet Virgin Mary."))
        #expect(book.text(for: .rosaryVersicle).response == "That we may be made worthy of the promises of Christ.")

        let traditional = PrayerBook(usesHolyGhost: true)
        #expect(traditional.text(for: .gloryBe).leader.contains("Holy Ghost"))
        #expect(!traditional.text(for: .gloryBe).leader.contains("Holy Spirit"))
        for id in PrayerID.allCases {
            #expect(!book.text(for: id).full.isEmpty)
            #expect(!AnchorLibrary.fragments(for: id).isEmpty, "\(id) needs anchor phrases")
        }
    }

    @Test("Bead counter fills through a decade and the opening three")
    func beadProgress() {
        let plan = RosaryPlan(scope: .fullRosary, mysterySet: .joyful)
        let progress = plan.steps.map(BeadProgress.progress(for:))
        #expect(progress[0] == nil)
        #expect(progress[3] == BeadProgress(count: 3, completed: 0, current: 1))
        #expect(progress[5] == BeadProgress(count: 3, completed: 2, current: 3))
        #expect(progress[6] == nil)

        let decade = Array(progress[7..<21])
        #expect(decade[0] == BeadProgress(count: 10, completed: 0, current: nil))
        #expect(decade[1] == BeadProgress(count: 10, completed: 0, current: nil))
        #expect(decade[2] == BeadProgress(count: 10, completed: 0, current: 1))
        #expect(decade[11] == BeadProgress(count: 10, completed: 9, current: 10))
        #expect(decade[12] == BeadProgress(count: 10, completed: 10, current: nil))
        #expect(decade[13] == BeadProgress(count: 10, completed: 10, current: nil))
        #expect(decade[11]?.accessibilityLabel == "Hail Mary 10 of 10")
        #expect(progress.last! == nil)
    }
}
