import Foundation

/// A 33-day count. Daily readings and Montfort’s formula are slots until a sourced text is added.
/// Day 33 can show the 1883 Act of Consecration, which is a different prayer and is labeled as such.
public struct ConsecrationProgress: Codable, Hashable, Sendable {
    public static let length = 33

    public var start: CivilDate?
    /// Days the person has marked, from 1 through 33.
    public var checked: [Int]

    public init(start: CivilDate? = nil, checked: [Int] = []) {
        self.start = start
        self.checked = checked
    }

    public func dayNumber(on date: CivilDate) -> Int? {
        guard let start else { return nil }
        let number = date.dayNumber - start.dayNumber + 1
        guard (1...Self.length).contains(number) else { return nil }
        return number
    }

    public func isChecked(_ day: Int) -> Bool { checked.contains(day) }

    public var finishedCount: Int { Set(checked.filter { (1...Self.length).contains($0) }).count }

    /// The first day, when day 33 should fall on `feast`.
    public static func start(endingOn feast: CivilDate) -> CivilDate {
        feast.adding(days: -(length - 1))
    }
}
