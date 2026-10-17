import Foundation

/// A calendar day without time or time zone, with cheap day arithmetic.
public struct CivilDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public init(dayNumber: Int) {
        // Inverse of `dayNumber` (Howard Hinnant's civil_from_days).
        let z = dayNumber + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.init(year: y, month: m, day: d)
    }

    /// Days since 1970-01-01.
    public var dayNumber: Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// 1 = Sunday ... 7 = Saturday (matches `Calendar.component(.weekday)` for Gregorian).
    public var weekday: Int {
        // 1970-01-01 was a Thursday (weekday 5).
        let offset = (dayNumber + 4) % 7
        return (offset < 0 ? offset + 7 : offset) + 1
    }

    public var isSunday: Bool { weekday == 1 }

    public func adding(days: Int) -> CivilDate {
        CivilDate(dayNumber: dayNumber + days)
    }

    public static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

/// Just enough of the Roman liturgical calendar to place Sundays in Advent, Christmas, and Lent.
public enum LiturgicalCalendar {
    /// Gregorian Easter Sunday (anonymous Gregorian algorithm).
    public static func easter(year: Int) -> CivilDate {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return CivilDate(year: year, month: month, day: day)
    }

    public static func ashWednesday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -46)
    }

    /// The Sunday falling between November 27 and December 3.
    public static func firstSundayOfAdvent(year: Int) -> CivilDate {
        let christmas = CivilDate(year: year, month: 12, day: 25)
        // Sunday on or before Christmas Eve, then back three more weeks.
        let christmasEve = christmas.adding(days: -1)
        let back = christmasEve.weekday - 1
        return christmasEve.adding(days: -back - 21)
    }

    /// First Sunday after January 6. In countries that move Epiphany to a Sunday the feast can
    /// fall on a Monday instead, but every Sunday up to this date is still in Christmastide.
    public static func baptismOfTheLordSunday(year: Int) -> CivilDate {
        let epiphany = CivilDate(year: year, month: 1, day: 6)
        return epiphany.adding(days: 8 - epiphany.weekday)
    }

    public static func isInLent(_ date: CivilDate) -> Bool {
        date >= ashWednesday(year: date.year) && date < easter(year: date.year)
    }

    public static func isInAdvent(_ date: CivilDate) -> Bool {
        date >= firstSundayOfAdvent(year: date.year) && date < CivilDate(year: date.year, month: 12, day: 25)
    }

    public static func isInChristmasSeason(_ date: CivilDate) -> Bool {
        if date.month == 12 { return date.day >= 25 }
        return date.month == 1 && date <= baptismOfTheLordSunday(year: date.year)
    }

    public static func pentecost(year: Int) -> CivilDate {
        easter(year: year).adding(days: 49)
    }

    public static func palmSunday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -7)
    }

    public static func holyThursday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -3)
    }

    public static func goodFriday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -2)
    }

    public static func holySaturday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -1)
    }

    /// Third Sunday of Advent.
    public static func gaudeteSunday(year: Int) -> CivilDate {
        firstSundayOfAdvent(year: year).adding(days: 14)
    }

    /// Fourth Sunday of Lent.
    public static func laetareSunday(year: Int) -> CivilDate {
        easter(year: year).adding(days: -21)
    }

    /// The USCCB readings page for a civil date, for example 17 October 2026 is `101726.cfm`.
    public static func usccbReadingsURL(for date: CivilDate) -> URL {
        let path = String(format: "%02d%02d%02d", date.month, date.day, date.year % 100)
        return URL(string: "https://bible.usccb.org/bible/readings/\(path).cfm")!
    }

    /// Season and color for the Roman calendar. Feasts outside the seasons below stay with the season.
    public static func day(_ date: CivilDate) -> LiturgicalDay {
        let easterSunday = easter(year: date.year)
        let pentecostSunday = pentecost(year: date.year)
        if date == easterSunday {
            return LiturgicalDay(date: date, season: .easter, color: .white, title: "Easter Sunday")
        }
        if date == pentecostSunday {
            return LiturgicalDay(date: date, season: .easter, color: .red, title: "Pentecost")
        }
        if date == CivilDate(year: date.year, month: 12, day: 25) {
            return LiturgicalDay(date: date, season: .christmas, color: .white, title: "Christmas Day")
        }
        if date == ashWednesday(year: date.year) {
            return LiturgicalDay(date: date, season: .lent, color: .violet, title: "Ash Wednesday")
        }
        if date == palmSunday(year: date.year) {
            return LiturgicalDay(date: date, season: .lent, color: .red, title: "Palm Sunday")
        }
        if date == holyThursday(year: date.year) {
            return LiturgicalDay(date: date, season: .triduum, color: .white, title: "Holy Thursday")
        }
        if date == goodFriday(year: date.year) {
            return LiturgicalDay(date: date, season: .triduum, color: .red, title: "Good Friday")
        }
        if date == holySaturday(year: date.year) {
            return LiturgicalDay(date: date, season: .triduum, color: .white, title: "Holy Saturday")
        }
        if date == gaudeteSunday(year: date.year) {
            return LiturgicalDay(date: date, season: .advent, color: .rose, title: "Gaudete Sunday")
        }
        if date == laetareSunday(year: date.year) {
            return LiturgicalDay(date: date, season: .lent, color: .rose, title: "Laetare Sunday")
        }
        if isInAdvent(date) {
            return LiturgicalDay(date: date, season: .advent, color: .violet, title: "Advent")
        }
        if isInChristmasSeason(date) {
            return LiturgicalDay(date: date, season: .christmas, color: .white, title: "Christmas")
        }
        if date > easterSunday && date < pentecostSunday {
            return LiturgicalDay(date: date, season: .easter, color: .white, title: "Easter")
        }
        if isInLent(date) {
            return LiturgicalDay(date: date, season: .lent, color: .violet, title: "Lent")
        }
        return LiturgicalDay(date: date, season: .ordinary, color: .green, title: "Ordinary Time")
    }
}

public enum LiturgicalSeason: String, Hashable, Sendable {
    case advent, christmas, lent, triduum, easter, ordinary

    public var title: String {
        switch self {
        case .advent: "Advent"
        case .christmas: "Christmas"
        case .lent: "Lent"
        case .triduum: "Paschal Triduum"
        case .easter: "Easter"
        case .ordinary: "Ordinary Time"
        }
    }
}

public enum LiturgicalColor: String, Hashable, Sendable {
    case green, violet, white, red, rose

    public var title: String {
        switch self {
        case .green: "Green"
        case .violet: "Violet"
        case .white: "White"
        case .red: "Red"
        case .rose: "Rose"
        }
    }
}

public struct LiturgicalDay: Hashable, Sendable {
    public let date: CivilDate
    public let season: LiturgicalSeason
    public let color: LiturgicalColor
    public let title: String
}

public enum MysterySchedule {
    /// Mon & Sat Joyful, Tue & Fri Sorrowful, Wed & Sun Glorious, Thu Luminous.
    /// With `seasonalSundays`, Sundays of Advent and Christmastide are Joyful and Sundays of Lent Sorrowful.
    public static func set(for date: CivilDate, seasonalSundays: Bool) -> MysterySet {
        if seasonalSundays, date.isSunday {
            if LiturgicalCalendar.isInAdvent(date) || LiturgicalCalendar.isInChristmasSeason(date) {
                return .joyful
            }
            if LiturgicalCalendar.isInLent(date) {
                return .sorrowful
            }
        }
        return weekdaySet(date.weekday)
    }

    public static func set(for date: Date, calendar: Calendar = .current, seasonalSundays: Bool) -> MysterySet {
        set(for: CivilDate(date, calendar: calendar), seasonalSundays: seasonalSundays)
    }

    public static func weekdaySet(_ weekday: Int) -> MysterySet {
        switch weekday {
        case 2, 7: .joyful
        case 3, 6: .sorrowful
        case 5: .luminous
        default: .glorious
        }
    }
}
