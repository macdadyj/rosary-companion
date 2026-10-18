import Foundation
import Observation

/// What the person chose on the Home screen.
public struct SessionSetup: Hashable, Sendable {
    public var mode: PrayerMode
    public var length: SessionLength
    /// Which decade, for a one-decade session.
    public var decade: Int
    public var mysterySet: MysterySet
    public var family: Bool
    public var starterID: UUID?
    public var intentionIDs: [UUID]

    public init(
        mode: PrayerMode,
        length: SessionLength,
        decade: Int = 1,
        mysterySet: MysterySet,
        family: Bool = false,
        starterID: UUID? = nil,
        intentionIDs: [UUID] = []
    ) {
        self.mode = mode
        self.length = length
        self.decade = decade
        self.mysterySet = mysterySet
        self.family = family
        self.starterID = starterID
        self.intentionIDs = intentionIDs
    }

    public var scope: SessionScope { length.scope(decade: decade) }
}

public struct PreparedSession: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let setup: SessionSetup
    public let configuration: SessionConfiguration
    public let starter: FamilyMember?
    public let lineup: [Int: FamilyMember]
    public let startedAt: Date
}

@MainActor
@Observable
public final class AppModel {
    public private(set) var settings: AppSettings
    public private(set) var sessions: [SessionRecord]
    public private(set) var intentions: [Intention]
    public private(set) var consecration: ConsecrationProgress
    /// Set when the last write to disk failed, so the UI can say so.
    public private(set) var saveError: String?

    @ObservationIgnored private let store: JSONFileStore?
    @ObservationIgnored public let now: () -> Date
    @ObservationIgnored public let calendar: Calendar

    static let settingsFile = "settings.json"
    static let sessionsFile = "sessions.json"
    static let intentionsFile = "intentions.json"
    static let consecrationFile = "consecration.json"

    public init(store: JSONFileStore?, now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.store = store
        self.now = now
        self.calendar = calendar
        settings = (try? store?.load(AppSettings.self, from: Self.settingsFile)) ?? AppSettings()
        sessions = (try? store?.load([SessionRecord].self, from: Self.sessionsFile)) ?? []
        intentions = (try? store?.load([Intention].self, from: Self.intentionsFile)) ?? []
        consecration = (try? store?.load(ConsecrationProgress.self, from: Self.consecrationFile)) ?? ConsecrationProgress()
    }

    // MARK: Settings

    public func update(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        settings = copy
        persist(settings, to: Self.settingsFile)
    }

    // MARK: Family

    public var nextStarter: FamilyMember? { FamilyRotation.nextStarter(settings.family) }

    public func addMember(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { $0.family.members.append(FamilyMember(name: trimmed)) }
    }

    public func renameMember(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update { settings in
            guard let index = settings.family.members.firstIndex(where: { $0.id == id }) else { return }
            settings.family.members[index].name = trimmed
        }
    }

    public func removeMembers(atOffsets offsets: IndexSet) {
        update { settings in
            settings.family.members = settings.family.members.enumerated()
                .filter { !offsets.contains($0.offset) }
                .map(\.element)
        }
    }

    public func moveMembers(fromOffsets source: IndexSet, toOffset destination: Int) {
        update { settings in
            let members = settings.family.members
            let moving = source.sorted().map { members[$0] }
            var remaining = members.enumerated().filter { !source.contains($0.offset) }.map(\.element)
            let insertAt = destination - source.filter { $0 < destination }.count
            remaining.insert(contentsOf: moving, at: max(0, min(insertAt, remaining.count)))
            settings.family.members = remaining
        }
    }

    // MARK: Today

    public var today: CivilDate { CivilDate(now(), calendar: calendar) }

    public var todaysSet: MysterySet {
        MysterySchedule.set(for: today, seasonalSundays: settings.seasonalSundays)
    }

    public var streak: StreakSummary {
        Streaks.summary(sessions: sessions, today: now(), calendar: calendar)
    }

    // MARK: Sessions

    /// For one-decade sessions: the decade after the last one prayed from this set.
    public func suggestedDecade(for set: MysterySet) -> Int {
        let last = sessions
            .filter { $0.mysterySet == set && !$0.decadesCompleted.isEmpty }
            .max { $0.startedAt < $1.startedAt }
        guard let last, case .singleDecade(let decade) = last.scope else { return 1 }
        return decade % 5 + 1
    }

    public func defaultSetup() -> SessionSetup {
        SessionSetup(
            mode: settings.defaultMode,
            length: settings.defaultLength,
            decade: suggestedDecade(for: todaysSet),
            mysterySet: todaysSet,
            family: settings.family.isEnabled && !settings.family.members.isEmpty,
            starterID: nextStarter?.id
        )
    }

    public func prepare(_ setup: SessionSetup) -> PreparedSession {
        let members = settings.family.members
        let decades = setup.scope.decadeNumbers
        var starter: FamilyMember?
        var lineup: [Int: FamilyMember] = [:]
        var nextLeader: FamilyMember?
        if setup.family, !members.isEmpty {
            starter = members.first { $0.id == setup.starterID } ?? nextStarter
            if let starter {
                lineup = FamilyRotation.lineup(starter: starter, decades: decades, members: members)
                nextLeader = FamilyRotation.starterAfter(
                    starter: starter, lastLeader: decades.last.flatMap { lineup[$0] }, family: settings.family
                )
            }
        }

        var timing = EngineTiming()
        timing.announcementHold = max(1, settings.meditationPause)
        timing.guidedResponsePause = max(1, settings.guidedResponsePause)
        let scripts = DecadeReading.scripts(
            content: try? PrayerContent.bundled(),
            saints: try? SaintsLibrary.bundled(),
            day: today
        )
        let configuration = SessionConfiguration(
            scope: setup.scope,
            mysterySet: setup.mysterySet,
            mode: setup.mode,
            openingIntentions: settings.openingIntentions,
            prayerBook: PrayerBook(usesHolyGhost: settings.usesHolyGhost),
            decadeLeaders: lineup.mapValues(\.name),
            nextSessionLeader: nextLeader?.name,
            announceNextLeader: settings.family.announceNextLeader,
            timing: timing,
            readsMeditations: settings.readsMeditationsAloud,
            meditationScripture: scripts.scripture,
            meditationText: scripts.meditation
        )
        return PreparedSession(
            id: UUID(), setup: setup, configuration: configuration,
            starter: starter, lineup: lineup, startedAt: now()
        )
    }

    /// Saves the session (and the family rotation, if a decade was prayed).
    @discardableResult
    public func record(_ prepared: PreparedSession, completedDecades: [Int], completedAll: Bool) -> SessionRecord {
        let leaders = completedDecades.compactMap { prepared.lineup[$0]?.name }
        let record = SessionRecord(
            id: prepared.id,
            startedAt: prepared.startedAt,
            endedAt: now(),
            mode: prepared.setup.mode,
            mysterySet: prepared.setup.mysterySet,
            scope: prepared.setup.scope,
            decadesCompleted: completedDecades,
            completedAll: completedAll,
            intentionIDs: prepared.setup.intentionIDs,
            leaders: leaders
        )
        sessions.removeAll { $0.id == record.id }
        sessions.append(record)
        persist(sessions, to: Self.sessionsFile)

        if let starter = prepared.starter {
            let lastLeader = completedDecades.last.flatMap { prepared.lineup[$0] }
            update { settings in
                settings.family = FamilyRotation.recording(
                    starter: starter, lastCompletedLeader: lastLeader, in: settings.family
                )
            }
        }
        return record
    }

    public func setJournal(_ text: String, for sessionID: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[index].journal = trimmed.isEmpty ? nil : trimmed
        persist(sessions, to: Self.sessionsFile)
    }

    public func deleteSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persist(sessions, to: Self.sessionsFile)
    }

    public var sessionsNewestFirst: [SessionRecord] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    // MARK: Intentions

    @discardableResult
    public func addIntention(_ text: String) -> Intention? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let intention = Intention(text: trimmed, createdAt: now())
        intentions.append(intention)
        persist(intentions, to: Self.intentionsFile)
        return intention
    }

    public func setStatus(_ status: IntentionStatus, for id: UUID) {
        guard let index = intentions.firstIndex(where: { $0.id == id }) else { return }
        intentions[index].status = status
        intentions[index].answeredAt = status == .answered ? now() : nil
        persist(intentions, to: Self.intentionsFile)
    }

    public func updateIntention(_ id: UUID, text: String, note: String?) {
        guard let index = intentions.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { intentions[index].text = trimmed }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        intentions[index].note = (trimmedNote?.isEmpty ?? true) ? nil : trimmedNote
        persist(intentions, to: Self.intentionsFile)
    }

    public func deleteIntention(_ id: UUID) {
        intentions.removeAll { $0.id == id }
        for index in sessions.indices {
            sessions[index].intentionIDs.removeAll { $0 == id }
        }
        persist(intentions, to: Self.intentionsFile)
        persist(sessions, to: Self.sessionsFile)
    }

    public func intentions(with status: IntentionStatus) -> [Intention] {
        intentions.filter { $0.status == status }.sorted { $0.createdAt > $1.createdAt }
    }

    public func intention(_ id: UUID) -> Intention? {
        intentions.first { $0.id == id }
    }

    public func beginConsecration(on date: CivilDate) {
        consecration.start = date
        consecration.checked = []
        persist(consecration, to: Self.consecrationFile)
    }

    public func setConsecrationDay(_ day: Int, checked: Bool) {
        guard (1...ConsecrationProgress.length).contains(day) else { return }
        if checked {
            if !consecration.checked.contains(day) { consecration.checked.append(day) }
        } else {
            consecration.checked.removeAll { $0 == day }
        }
        persist(consecration, to: Self.consecrationFile)
    }

    public func sessionCount(for intentionID: UUID) -> Int {
        sessions.filter { $0.intentionIDs.contains(intentionID) }.count
    }

    // MARK: Catalogue

    public func isFavorite(_ id: String) -> Bool {
        settings.favoritePrayerIDs.contains(id)
    }

    public func toggleFavorite(_ id: String) {
        update { settings in
            if let index = settings.favoritePrayerIDs.firstIndex(of: id) {
                settings.favoritePrayerIDs.remove(at: index)
            } else {
                settings.favoritePrayerIDs.append(id)
            }
        }
    }

    public func rememberPrayer(_ id: String) {
        update { settings in
            settings.recentPrayerIDs.removeAll { $0 == id }
            settings.recentPrayerIDs.insert(id, at: 0)
            if settings.recentPrayerIDs.count > 12 {
                settings.recentPrayerIDs = Array(settings.recentPrayerIDs.prefix(12))
            }
        }
    }

    public func beginNovena(intention: String, on date: CivilDate) {
        let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        update { $0.novena = Novena(intention: trimmed, start: date) }
    }

    public func clearNovena() {
        update { $0.novena = nil }
    }

    // MARK: Export

    public func journalExportText(locale: Locale = .current) -> String {
        JournalExport.plainText(
            sessions: sessions, intentions: intentions, exportedAt: now(), calendar: calendar, locale: locale
        )
    }

    private func persist<T: Encodable>(_ value: T, to name: String) {
        guard let store else { return }
        do {
            try store.save(value, to: name)
            saveError = nil
        } catch {
            saveError = "Couldn't save to this iPhone: \(error.localizedDescription)"
        }
    }
}
