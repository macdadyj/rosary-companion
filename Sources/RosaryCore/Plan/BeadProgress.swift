import Foundation

/// What the bead counter shows for a step: how many beads, how many are done, and which one
/// is being prayed now.
public struct BeadProgress: Hashable, Sendable {
    public let count: Int
    public let completed: Int
    /// 1-based bead being prayed now, if the step is a Hail Mary.
    public let current: Int?

    public init(count: Int, completed: Int, current: Int?) {
        self.count = count
        self.completed = completed
        self.current = current
    }

    public var accessibilityLabel: String {
        if let current { return "Hail Mary \(current) of \(count)" }
        if completed == count { return "All \(count) Hail Marys prayed" }
        return "\(count) Hail Marys to come"
    }

    /// Nil for steps with no beads to show (the Creed, the closing prayers, ...).
    public static func progress(for step: RosaryStep) -> BeadProgress? {
        if let bead = step.bead, let count = step.beadCount {
            return BeadProgress(count: count, completed: bead - 1, current: bead)
        }
        guard case .decade = step.section else { return nil }
        switch step.content {
        case .mysteryAnnouncement:
            return BeadProgress(count: 10, completed: 0, current: nil)
        case .prayer(let id):
            switch id {
            case .ourFather:
                return BeadProgress(count: 10, completed: 0, current: nil)
            case .gloryBe, .fatimaPrayer:
                return BeadProgress(count: 10, completed: 10, current: nil)
            case .signOfTheCross, .apostlesCreed, .hailMary, .hailHolyQueen, .rosaryVersicle, .closingPrayer:
                return nil
            }
        }
    }
}
