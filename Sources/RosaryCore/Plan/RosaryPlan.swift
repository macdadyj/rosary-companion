import Foundation

public enum SessionScope: Hashable, Codable, Sendable {
    /// One decade of the chosen set (1...5).
    case singleDecade(Int)
    /// All five decades without the opening and closing prayers.
    case fiveDecades
    /// Sign of the Cross through the closing blessing.
    case fullRosary

    public var label: String {
        switch self {
        case .singleDecade(let n): "Decade \(n)"
        case .fiveDecades: "Five decades"
        case .fullRosary: "Full Rosary"
        }
    }

    public var decadeNumbers: [Int] {
        switch self {
        case .singleDecade(let n): [n]
        case .fiveDecades, .fullRosary: Array(1...5)
        }
    }
}

public enum RosarySection: Hashable, Sendable {
    case opening
    case decade(Int)
    case closing

    public var decadeNumber: Int? {
        if case .decade(let n) = self { return n }
        return nil
    }
}

public enum StepContent: Hashable, Sendable {
    case prayer(PrayerID)
    case mysteryAnnouncement(Mystery)
}

public struct RosaryStep: Hashable, Sendable, Identifiable {
    public let id: Int
    public let section: RosarySection
    public let content: StepContent
    /// For Hail Marys: 1-based position within its group of 3 or 10.
    public let bead: Int?
    public let beadCount: Int?
    public let intention: OpeningIntention?

    public var prayerID: PrayerID? {
        if case .prayer(let id) = content { return id }
        return nil
    }

    public var mystery: Mystery? {
        if case .mysteryAnnouncement(let m) = content { return m }
        return nil
    }

    public var anchor: AnchorKind {
        switch content {
        case .prayer(let id): .prayer(id)
        case .mysteryAnnouncement(let m): .announcement(decade: m.number)
        }
    }
}

public struct RosaryPlan: Hashable, Sendable {
    public let scope: SessionScope
    public let mysterySet: MysterySet
    public let steps: [RosaryStep]

    public init(scope: SessionScope, mysterySet: MysterySet, openingIntentions: Bool = true) {
        self.scope = scope
        self.mysterySet = mysterySet

        var builder: [(RosarySection, StepContent, Int?, Int?, OpeningIntention?)] = []
        func add(_ section: RosarySection, _ prayer: PrayerID) {
            builder.append((section, .prayer(prayer), nil, nil, nil))
        }

        if scope == .fullRosary {
            add(.opening, .signOfTheCross)
            add(.opening, .apostlesCreed)
            add(.opening, .ourFather)
            for (i, intention) in OpeningIntention.allCases.enumerated() {
                builder.append((.opening, .prayer(.hailMary), i + 1, 3, openingIntentions ? intention : nil))
            }
            add(.opening, .gloryBe)
        }

        let mysteries = mysterySet.mysteries
        for n in scope.decadeNumbers {
            let section = RosarySection.decade(n)
            builder.append((section, .mysteryAnnouncement(mysteries[n - 1]), nil, nil, nil))
            add(section, .ourFather)
            for bead in 1...10 {
                builder.append((section, .prayer(.hailMary), bead, 10, nil))
            }
            add(section, .gloryBe)
            add(section, .fatimaPrayer)
        }

        if scope == .fullRosary {
            add(.closing, .hailHolyQueen)
            add(.closing, .rosaryVersicle)
            add(.closing, .closingPrayer)
            add(.closing, .signOfTheCross)
        }

        steps = builder.enumerated().map { index, item in
            RosaryStep(id: index, section: item.0, content: item.1, bead: item.2, beadCount: item.3, intention: item.4)
        }
    }

    public var decadeNumbers: [Int] { scope.decadeNumbers }

    /// Index of the last step of the given decade (its Fatima Prayer).
    public func lastStepIndex(ofDecade decade: Int) -> Int? {
        steps.lastIndex { $0.section == .decade(decade) }
    }

    public func isLastStepOfDecade(_ index: Int) -> Bool {
        guard let decade = steps[index].section.decadeNumber else { return false }
        return lastStepIndex(ofDecade: decade) == index
    }

    /// Indices of the steps belonging to the section of `index`, plus the following section.
    public func sectionRange(containing index: Int) -> Range<Int> {
        let section = steps[index].section
        let start = steps.firstIndex { $0.section == section } ?? index
        let end = (steps.lastIndex { $0.section == section } ?? index) + 1
        return start..<end
    }
}
