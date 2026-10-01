import Foundation

public struct SessionRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date
    public var mode: PrayerMode
    public var mysterySet: MysterySet
    public var scope: SessionScope
    public var decadesCompleted: [Int]
    public var completedAll: Bool
    public var journal: String?
    public var intentionIDs: [UUID]
    /// Who led each completed decade, in order (family mode).
    public var leaders: [String]

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        mode: PrayerMode,
        mysterySet: MysterySet,
        scope: SessionScope,
        decadesCompleted: [Int],
        completedAll: Bool,
        journal: String? = nil,
        intentionIDs: [UUID] = [],
        leaders: [String] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.mysterySet = mysterySet
        self.scope = scope
        self.decadesCompleted = decadesCompleted
        self.completedAll = completedAll
        self.journal = journal
        self.intentionIDs = intentionIDs
        self.leaders = leaders
    }

    /// A day counts toward the streak once at least one decade was prayed.
    public var countsTowardStreak: Bool { !decadesCompleted.isEmpty }

    public var summary: String {
        let count = decadesCompleted.count
        if scope == .fullRosary && completedAll { return "Full Rosary · \(mysterySet.adjective)" }
        let decades = count == 1 ? "1 decade" : "\(count) decades"
        return "\(decades) · \(mysterySet.adjective)"
    }
}

public enum IntentionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case ongoing
    case answered

    public var title: String {
        switch self {
        case .ongoing: "Ongoing"
        case .answered: "Answered"
        }
    }
}

public struct Intention: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var createdAt: Date
    public var status: IntentionStatus
    public var answeredAt: Date?
    public var note: String?

    public init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date,
        status: IntentionStatus = .ongoing,
        answeredAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.status = status
        self.answeredAt = answeredAt
        self.note = note
    }
}

public struct StreakSummary: Hashable, Sendable {
    public var current: Int
    public var longest: Int
    public var prayedToday: Bool
    public var totalDays: Int

    public static let empty = StreakSummary(current: 0, longest: 0, prayedToday: false, totalDays: 0)
}

public enum Streaks {
    /// The current streak survives until the end of today: praying yesterday keeps it alive.
    public static func summary(days: Set<CivilDate>, today: CivilDate) -> StreakSummary {
        guard !days.isEmpty else { return .empty }
        let numbers = Set(days.map(\.dayNumber))
        let todayNumber = today.dayNumber
        let prayedToday = numbers.contains(todayNumber)

        var current = 0
        var cursor = prayedToday ? todayNumber : todayNumber - 1
        while numbers.contains(cursor) {
            current += 1
            cursor -= 1
        }

        var longest = 0
        var run = 0
        var previous: Int?
        for number in numbers.sorted() {
            run = (previous.map { number == $0 + 1 } ?? false) ? run + 1 : 1
            longest = max(longest, run)
            previous = number
        }
        return StreakSummary(current: current, longest: longest, prayedToday: prayedToday, totalDays: numbers.count)
    }

    public static func summary(sessions: [SessionRecord], today: Date, calendar: Calendar) -> StreakSummary {
        let days = Set(sessions.filter(\.countsTowardStreak).map { CivilDate($0.startedAt, calendar: calendar) })
        return summary(days: days, today: CivilDate(today, calendar: calendar))
    }
}

public enum JournalExport {
    public static func plainText(
        sessions: [SessionRecord],
        intentions: [Intention],
        exportedAt: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        let byID = Dictionary(uniqueKeysWithValues: intentions.map { ($0.id, $0) })
        var lines = ["Rosary Journal", "Exported \(formatter.string(from: exportedAt))", ""]

        for session in sessions.sorted(by: { $0.startedAt > $1.startedAt }) {
            lines.append("\(formatter.string(from: session.startedAt)) — \(session.summary)")
            if let journal = session.journal?.trimmingCharacters(in: .whitespacesAndNewlines), !journal.isEmpty {
                lines.append("  \(journal)")
            }
            let offered = session.intentionIDs.compactMap { byID[$0]?.text }
            if !offered.isEmpty {
                lines.append("  Offered for: \(offered.joined(separator: "; "))")
            }
            if !session.leaders.isEmpty {
                lines.append("  Led by: \(session.leaders.joined(separator: ", "))")
            }
            lines.append("")
        }

        if !intentions.isEmpty {
            lines.append("Intentions")
            for intention in intentions.sorted(by: { $0.createdAt < $1.createdAt }) {
                var line = "  [\(intention.status.title)] \(intention.text)"
                if let answered = intention.answeredAt, intention.status == .answered {
                    line += " (answered \(formatter.string(from: answered)))"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}
