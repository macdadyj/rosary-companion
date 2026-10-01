import Foundation
import Testing
@testable import RosaryCore

private let dad = FamilyMember(name: "Dad")
private let mom = FamilyMember(name: "Mom")
private let anna = FamilyMember(name: "Anna")
private let ben = FamilyMember(name: "Ben")

private func family(_ members: [FamilyMember], policy: RotationPolicy = .newStarterEachSession) -> FamilySettings {
    var settings = FamilySettings()
    settings.isEnabled = true
    settings.members = members
    settings.policy = policy
    return settings
}

@Suite("Family rotation")
struct FamilyRotationTests {
    @Test func firstSessionStartsWithFirstMember() {
        #expect(FamilyRotation.nextStarter(family([dad, mom, anna])) == dad)
        #expect(FamilyRotation.nextStarter(family([])) == nil)
    }

    @Test func lineupTakesTurnsAndWraps() {
        let lineup = FamilyRotation.lineup(starter: mom, decades: [1, 2, 3, 4, 5], members: [dad, mom, anna])
        #expect(lineup[1] == mom)
        #expect(lineup[2] == anna)
        #expect(lineup[3] == dad)
        #expect(lineup[4] == mom)
        #expect(lineup[5] == anna)
    }

    @Test func singleDecadeLineupUsesDecadeNumber() {
        let lineup = FamilyRotation.lineup(starter: anna, decades: [3], members: [dad, mom, anna])
        #expect(lineup == [3: anna])
    }

    @Test func newStarterEachSessionMovesStarterByOne() {
        var settings = family([dad, mom, anna])
        settings = FamilyRotation.recording(starter: dad, lastCompletedLeader: mom, in: settings)
        #expect(FamilyRotation.nextStarter(settings) == mom)
        settings = FamilyRotation.recording(starter: mom, lastCompletedLeader: dad, in: settings)
        #expect(FamilyRotation.nextStarter(settings) == anna)
        settings = FamilyRotation.recording(starter: anna, lastCompletedLeader: anna, in: settings)
        #expect(FamilyRotation.nextStarter(settings) == dad)
    }

    @Test func continueWhereLeftOffFollowsLastLeader() {
        var settings = family([dad, mom, anna, ben], policy: .continueWhereLeftOff)
        // Five decades from Dad: Dad, Mom, Anna, Ben, Dad. Next is Mom.
        settings = FamilyRotation.recording(starter: dad, lastCompletedLeader: dad, in: settings)
        #expect(FamilyRotation.nextStarter(settings) == mom)
        // Stopped after Mom and Anna led: next is Ben.
        settings = FamilyRotation.recording(starter: mom, lastCompletedLeader: anna, in: settings)
        #expect(FamilyRotation.nextStarter(settings) == ben)
    }

    @Test func sessionWithNoCompletedDecadeDoesNotMoveRotation() {
        let settings = family([dad, mom])
        let after = FamilyRotation.recording(starter: dad, lastCompletedLeader: nil, in: settings)
        #expect(after == settings)
        #expect(FamilyRotation.nextStarter(after) == dad)
    }

    @Test func removedLastStarterFallsBackToFirstMember() {
        var settings = family([dad, mom, anna])
        settings = FamilyRotation.recording(starter: mom, lastCompletedLeader: mom, in: settings)
        settings.members = [dad, anna]
        #expect(FamilyRotation.nextStarter(settings) == dad)
    }

    @Test func starterAfterPredictsNextSession() {
        let settings = family([dad, mom, anna], policy: .continueWhereLeftOff)
        let next = FamilyRotation.starterAfter(starter: dad, lastLeader: anna, family: settings)
        #expect(next == dad)
    }
}

@Suite("Streaks")
struct StreakTests {
    let today = CivilDate(year: 2026, month: 10, day: 1)

    @Test func emptyHistory() {
        #expect(Streaks.summary(days: [], today: today) == .empty)
    }

    @Test func consecutiveDaysEndingToday() {
        let days: Set = [today, today.adding(days: -1), today.adding(days: -2)]
        let summary = Streaks.summary(days: days, today: today)
        #expect(summary.current == 3)
        #expect(summary.prayedToday)
        #expect(summary.longest == 3)
        #expect(summary.totalDays == 3)
    }

    @Test func streakSurvivesUntilEndOfToday() {
        let days: Set = [today.adding(days: -1), today.adding(days: -2)]
        let summary = Streaks.summary(days: days, today: today)
        #expect(summary.current == 2)
        #expect(!summary.prayedToday)
    }

    @Test func missedDayResetsCurrentButKeepsLongest() {
        let days: Set = [
            today.adding(days: -2),
            today.adding(days: -10), today.adding(days: -11), today.adding(days: -12), today.adding(days: -13),
        ]
        let summary = Streaks.summary(days: days, today: today)
        #expect(summary.current == 0)
        #expect(summary.longest == 4)
    }

    @Test func streakCrossesMonthAndYearBoundaries() {
        let newYear = CivilDate(year: 2027, month: 1, day: 1)
        let days: Set = [newYear, CivilDate(year: 2026, month: 12, day: 31), CivilDate(year: 2026, month: 12, day: 30)]
        #expect(Streaks.summary(days: days, today: newYear).current == 3)
    }

    @Test func sessionsWithoutACompletedDecadeDoNotCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 20))!
        let yesterday = now.addingTimeInterval(-86_400)
        let sessions = [
            record(at: yesterday, decades: [1]),
            record(at: now, decades: []),
        ]
        let summary = Streaks.summary(sessions: sessions, today: now, calendar: calendar)
        #expect(summary.current == 1)
        #expect(!summary.prayedToday)
    }

    @Test func lateNightSessionCountsForLocalDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 11:30 PM local on Sep 30 is already Oct 1 in UTC.
        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 30))!
        let nextMorning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 7))!
        let sessions = [record(at: lateNight, decades: [1]), record(at: nextMorning, decades: [1])]
        let summary = Streaks.summary(sessions: sessions, today: nextMorning, calendar: calendar)
        #expect(summary.current == 2)
    }

    private func record(at date: Date, decades: [Int]) -> SessionRecord {
        SessionRecord(
            startedAt: date, endedAt: date.addingTimeInterval(600), mode: .guided, mysterySet: .joyful,
            scope: .singleDecade(1), decadesCompleted: decades, completedAll: !decades.isEmpty
        )
    }
}

@Suite("Journal export")
struct JournalExportTests {
    @Test func includesJournalIntentionsAndLeaders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 19))!
        let intention = Intention(text: "Grandma's surgery", createdAt: date)
        let session = SessionRecord(
            startedAt: date, endedAt: date, mode: .tracking, mysterySet: .luminous, scope: .fiveDecades,
            decadesCompleted: [1, 2, 3, 4, 5], completedAll: true, journal: "Peaceful tonight.",
            intentionIDs: [intention.id], leaders: ["Dad", "Mom"]
        )
        let text = JournalExport.plainText(
            sessions: [session], intentions: [intention], exportedAt: date, calendar: calendar,
            locale: Locale(identifier: "en_US")
        )
        #expect(text.contains("Thursday, October 1, 2026 — 5 decades · Luminous"))
        #expect(text.contains("  Peaceful tonight."))
        #expect(text.contains("  Offered for: Grandma's surgery"))
        #expect(text.contains("  Led by: Dad, Mom"))
        #expect(text.contains("[Ongoing] Grandma's surgery"))
    }
}
