import Foundation

/// A decade counter for the Watch. Ten beads, then the next tap starts another decade.
public struct WatchCounter: Hashable, Sendable {
    public var bead: Int
    public var decades: Int

    public static let beadsInDecade = 10

    public init(bead: Int = 0, decades: Int = 0) {
        self.bead = bead
        self.decades = decades
    }

    public var label: String {
        if bead == 0, decades == 0 { return "Ready" }
        if bead == 0 { return "\(decades) decades" }
        return "\(bead) of \(Self.beadsInDecade)"
    }

    public mutating func advance() {
        if bead >= Self.beadsInDecade {
            decades += 1
            bead = 1
        } else {
            bead += 1
        }
    }

    public mutating func back() {
        if bead > 0 {
            bead -= 1
        } else if decades > 0 {
            decades -= 1
            bead = Self.beadsInDecade
        }
    }

    public mutating func reset() {
        bead = 0
        decades = 0
    }
}
