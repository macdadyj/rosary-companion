import Foundation
import Testing
@testable import RosaryCore

@MainActor
@Suite("App model and persistence")
struct AppModelTests {
    let directory: URL
    let store: JSONFileStore
    let clock = Clock()

    final class Clock: @unchecked Sendable {
        var now: Date
        init() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            // A Thursday: Luminous mysteries.
            now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 19))!
        }
    }

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RosaryTests-\(UUID().uuidString)", isDirectory: true)
        store = JSONFileStore(directory: directory)
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func makeModel() -> AppModel {
        let clock = clock
        return AppModel(store: store, now: { clock.now }, calendar: calendar)
    }

    @Test func freshInstallHasDefaults() {
        let model = makeModel()
        #expect(model.settings.defaultMode == .guided)
        #expect(model.settings.defaultLength == .oneDecade)
        #expect(model.settings.appearance == .dark)
        #expect(!model.settings.family.isEnabled)
        #expect(model.settings.family.members.map(\.name) == ["Dad", "Mom"])
        #expect(model.sessions.isEmpty)
        #expect(model.intentions.isEmpty)
        #expect(model.todaysSet == .luminous)
        #expect(model.streak == .empty)
    }

    @Test func settingsPersistAcrossLaunches() {
        let model = makeModel()
        model.update {
            $0.defaultMode = .tracking
            $0.seasonalSundays = true
            $0.appearance = .light
        }
        let relaunched = makeModel()
        #expect(relaunched.settings.defaultMode == .tracking)
        #expect(relaunched.settings.seasonalSundays)
        #expect(relaunched.settings.appearance == .light)
    }

    @Test func olderSettingsFileWithMissingKeysStillLoads() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let partial = #"{"defaultMode":"tracking","family":{"isEnabled":true}}"#
        try Data(partial.utf8).write(to: directory.appendingPathComponent(AppModel.settingsFile))
        let model = makeModel()
        #expect(model.settings.defaultMode == .tracking)
        #expect(model.settings.family.isEnabled)
        #expect(model.settings.family.members.map(\.name) == ["Dad", "Mom"])
        #expect(model.settings.narrationRate == AppSettings().narrationRate)
    }

    @Test func corruptFileFallsBackToDefaults() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent(AppModel.sessionsFile))
        #expect(makeModel().sessions.isEmpty)
    }

    @Test func familyMembersCanBeAddedRenamedRemovedAndReordered() {
        let model = makeModel()
        model.addMember(named: "  Anna ")
        model.addMember(named: "   ")
        model.addMember(named: "Ben")
        #expect(model.settings.family.members.map(\.name) == ["Dad", "Mom", "Anna", "Ben"])

        model.renameMember(model.settings.family.members[0].id, to: "Papa")
        model.moveMembers(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(model.settings.family.members.map(\.name) == ["Ben", "Papa", "Mom", "Anna"])

        model.moveMembers(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        #expect(model.settings.family.members.map(\.name) == ["Papa", "Mom", "Anna", "Ben"])

        model.removeMembers(atOffsets: IndexSet(integer: 1))
        #expect(makeModel().settings.family.members.map(\.name) == ["Papa", "Anna", "Ben"])
    }

    @Test func familySessionNamesLeadersAndRemembersRotation() {
        let model = makeModel()
        model.update { $0.family.isEnabled = true }
        model.addMember(named: "Anna")
        let setup = model.defaultSetup()
        #expect(setup.family)
        #expect(setup.mysterySet == .luminous)

        var fiveDecades = setup
        fiveDecades.length = .fiveDecades
        let prepared = model.prepare(fiveDecades)
        #expect(prepared.starter?.name == "Dad")
        #expect(prepared.configuration.decadeLeaders == [1: "Dad", 2: "Mom", 3: "Anna", 4: "Dad", 5: "Mom"])
        #expect(prepared.configuration.nextSessionLeader == "Mom")

        model.record(prepared, completedDecades: [1, 2, 3, 4, 5], completedAll: true)
        let relaunched = makeModel()
        #expect(relaunched.nextStarter?.name == "Mom")
        #expect(relaunched.sessions.first?.leaders == ["Dad", "Mom", "Anna", "Dad", "Mom"])
    }

    @Test func singleDecadeFamilySessionNamesNextPerson() {
        let model = makeModel()
        model.update { $0.family.isEnabled = true }
        let prepared = model.prepare(model.defaultSetup())
        #expect(prepared.configuration.decadeLeaders == [1: "Dad"])
        #expect(prepared.configuration.nextSessionLeader == "Mom")
    }

    @Test func chosenStarterOverridesRotation() {
        let model = makeModel()
        model.update { $0.family.isEnabled = true }
        var setup = model.defaultSetup()
        setup.starterID = model.settings.family.members[1].id
        let prepared = model.prepare(setup)
        #expect(prepared.configuration.decadeLeaders == [1: "Mom"])
        model.record(prepared, completedDecades: [1], completedAll: true)
        #expect(model.nextStarter?.name == "Dad")
    }

    @Test func meditationPauseSetsAnnouncementHold() {
        let model = makeModel()
        model.update { $0.meditationPause = 15 }
        #expect(model.prepare(model.defaultSetup()).configuration.timing.announcementHold == 15)
    }

    @Test func soloSessionHasNoLeaders() {
        let model = makeModel()
        let prepared = model.prepare(model.defaultSetup())
        #expect(!prepared.configuration.isFamily)
        #expect(prepared.starter == nil)
    }

    @Test func recordingBuildsStreakAndJournal() {
        let model = makeModel()
        let prepared = model.prepare(model.defaultSetup())
        let record = model.record(prepared, completedDecades: [1], completedAll: true)
        model.setJournal("  Grateful for a quiet evening.  ", for: record.id)
        #expect(model.streak.current == 1)
        #expect(model.streak.prayedToday)

        clock.now = clock.now.addingTimeInterval(86_400)
        let relaunched = makeModel()
        #expect(relaunched.sessions.first?.journal == "Grateful for a quiet evening.")
        #expect(relaunched.streak.current == 1)
        #expect(!relaunched.streak.prayedToday)
    }

    @Test func intentionsCanBeOfferedAndAnswered() {
        let model = makeModel()
        let healing = model.addIntention("Healing for Grandpa")!
        let work = model.addIntention("A new job for Sam")!
        #expect(model.addIntention("  ") == nil)

        var setup = model.defaultSetup()
        setup.intentionIDs = [healing.id]
        model.record(model.prepare(setup), completedDecades: [1], completedAll: true)
        #expect(model.sessionCount(for: healing.id) == 1)
        #expect(model.sessionCount(for: work.id) == 0)

        model.setStatus(.answered, for: healing.id)
        let relaunched = makeModel()
        #expect(relaunched.intentions(with: .answered).map(\.text) == ["Healing for Grandpa"])
        #expect(relaunched.intentions(with: .answered).first?.answeredAt == clock.now)
        #expect(relaunched.intentions(with: .ongoing).map(\.text) == ["A new job for Sam"])

        relaunched.deleteIntention(healing.id)
        #expect(relaunched.sessions.first?.intentionIDs.isEmpty == true)
    }

    @Test func storeRoundTripsDatesAndScopes() throws {
        let record = SessionRecord(
            startedAt: clock.now, endedAt: clock.now, mode: .tracking, mysterySet: .glorious,
            scope: .singleDecade(4), decadesCompleted: [4], completedAll: true
        )
        try store.save([record], to: "roundtrip.json")
        let loaded = try store.load([SessionRecord].self, from: "roundtrip.json")
        #expect(loaded == [record])
        #expect(try store.load([SessionRecord].self, from: "missing.json") == nil)
    }
}
