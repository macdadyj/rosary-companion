import Foundation

/// Nine days of prayer, counted from the day it begins.
public struct Novena: Codable, Hashable, Sendable {
    public var intention: String
    public var start: CivilDate
    public var length: Int

    public init(intention: String, start: CivilDate, length: Int = 9) {
        self.intention = intention
        self.start = start
        self.length = max(1, length)
    }

    /// Day 1 is `start`. Nil before the novena and once the nine days are over.
    public func dayNumber(on date: CivilDate) -> Int? {
        let delta = date.dayNumber - start.dayNumber
        guard delta >= 0, delta < length else { return nil }
        return delta + 1
    }
}

/// The next local reminder, and the sentence it should read.
public enum ReminderPlan {
    public static func nextDate(after now: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        let today = calendar.date(from: parts) ?? now
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(24 * 60 * 60)
    }

    public static func message(mysteries: String, feast: String?, novenaDay: Int?, intention: String?) -> String {
        var parts = ["Today’s mysteries: \(mysteries)."]
        if let feast = cleaned(feast) {
            parts.append(feast)
        }
        if let novenaDay {
            if let intention = cleaned(intention) {
                parts.append("Novena, day \(novenaDay) of 9, for \(intention).")
            } else {
                parts.append("Novena, day \(novenaDay) of 9.")
            }
        }
        return parts.joined(separator: " ")
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Home-screen widget copy: today’s mysteries, both calendars, and the gospel citation.
public struct TodayCard: Hashable, Sendable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    public static func make(
        date: Date,
        calendar: Calendar,
        content: PrayerContent?,
        lectionary: LectionaryLibrary?
    ) -> TodayCard {
        let civil = CivilDate(date, calendar: calendar)
        let set = MysterySchedule.set(for: civil, seasonalSundays: false)
        let liturgical = LiturgicalCalendar.day(civil)
        let ruthenian = content?.feasts(on: civil, rite: .ruthenian).map(\.name).filter { !$0.isEmpty } ?? []
        let western = content?.feasts(on: civil, rite: .western).map(\.name).filter { !$0.isEmpty } ?? []
        var lines: [String] = []
        lines.append(ruthenian.isEmpty ? "Ruthenian: feria" : "Ruthenian: \(ruthenian.joined(separator: ", "))")
        lines.append(western.isEmpty ? "Roman: \(liturgical.title)" : "Roman: \(western.joined(separator: ", "))")
        if let gospel = lectionary?.day(on: civil)?.gospel, !gospel.isEmpty {
            lines.append("Gospel: \(gospel)")
        } else {
            lines.append(liturgical.color.title)
        }
        return TodayCard(title: set.title, detail: lines.joined(separator: "\n"))
    }
}

public enum PrayerCatalogue {
    public static let rosaryID = "rosary"

    public static func rosaryID(for set: MysterySet) -> String {
        "rosary.\(set.rawValue)"
    }

    public static func title(for id: String, prayers: [LibraryPrayer]) -> String {
        if id == rosaryID { return "Pray the Rosary" }
        let prefix = "rosary."
        if id.hasPrefix(prefix), let set = MysterySet(rawValue: String(id.dropFirst(prefix.count))) {
            return "Rosary · \(set.title)"
        }
        return prayers.first { $0.id == id }?.title ?? id
    }
}
