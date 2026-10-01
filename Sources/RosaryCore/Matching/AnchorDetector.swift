import Foundation

/// One partial or final result from a speech recogniser.
///
/// `epoch` is chosen by the session engine whenever it wants a clean slate (for example after
/// the app finishes narrating). `segment` is bumped by the listener whenever it has to restart
/// recognition on its own. The text of a result is cumulative within its segment.
public struct TranscriptUpdate: Hashable, Sendable {
    public var epoch: Int
    public var segment: Int
    public var text: String
    public var isFinal: Bool

    public init(epoch: Int, segment: Int = 0, text: String, isFinal: Bool = false) {
        self.epoch = epoch
        self.segment = segment
        self.text = text
        self.isFinal = isFinal
    }
}

public struct AnchorHit: Hashable, Sendable {
    public let fragment: AnchorFragment
    public let distance: Int
    public let time: TimeInterval
}

/// Finds anchor phrases in a stream of cumulative partial transcripts.
///
/// - Text that already produced a hit is consumed and never searched again, so one spoken
///   phrase yields at most one hit even as the recogniser keeps re-sending it.
/// - A match must survive two consecutive partials (or a final result, or stay stable for
///   `debounceInterval`) before it fires, which filters out flickering hypotheses.
/// - The same fragment cannot fire twice within `fragmentCooldown`.
public final class AnchorDetector {
    public struct Configuration: Sendable {
        public var confirmations = 2
        public var debounceInterval: TimeInterval = 0.35
        public var positionTolerance = 10
        public var fragmentCooldown: TimeInterval = 1.5
        /// Only this many trailing characters are searched; recognisers only revise recent words.
        public var searchHorizon = 180

        public init() {}
    }

    private struct Pending {
        let fragment: AnchorFragment
        var match: ApproximateMatch
        var seen: Int
        let firstSeen: TimeInterval
    }

    /// The same phrase can legitimately appear twice in one partial (two quick Hail Marys).
    private struct PendingKey: Hashable {
        let fragment: AnchorFragment
        let occurrence: Int
    }

    private struct SegmentKey: Equatable {
        let epoch: Int
        let segment: Int
    }

    public var configuration: Configuration
    private var key: SegmentKey?
    private var cursor = 0
    private var pending: [PendingKey: Pending] = [:]
    private var lastFired: [AnchorFragment: TimeInterval] = [:]
    /// Fragments fired while handling the current update; separate positions in one result
    /// are separate utterances, so the cool-down doesn't apply between them.
    private var firedThisUpdate: Set<AnchorFragment> = []

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Forget the current transcript (cool-downs are kept).
    public func reset() {
        key = nil
        cursor = 0
        pending = [:]
    }

    public func process(_ update: TranscriptUpdate, fragments: [AnchorFragment], now: TimeInterval) -> [AnchorHit] {
        firedThisUpdate = []
        var hits: [AnchorHit] = []
        let updateKey = SegmentKey(epoch: update.epoch, segment: update.segment)
        if key != updateKey {
            // The recogniser restarted by itself: anything that was stable still counts.
            if key != nil { hits += flush(now: now) }
            key = updateKey
            cursor = 0
            pending = [:]
        }

        let text = TextNormalizer.folded(update.text)
        cursor = min(cursor, text.count)
        cursor = max(cursor, text.count - configuration.searchHorizon)

        let matches = Self.findMatches(in: text, from: cursor, fragments: fragments)
        var occurrences: [AnchorFragment: Int] = [:]
        var keys: [PendingKey] = []
        var nextPending: [PendingKey: Pending] = [:]
        for (fragment, match) in matches {
            let occurrence = occurrences[fragment, default: 0]
            occurrences[fragment] = occurrence + 1
            let pendingKey = PendingKey(fragment: fragment, occurrence: occurrence)
            keys.append(pendingKey)
            if var existing = pending[pendingKey],
               abs(existing.match.end - match.end) <= configuration.positionTolerance {
                existing.seen += 1
                existing.match = match
                nextPending[pendingKey] = existing
            } else {
                nextPending[pendingKey] = Pending(fragment: fragment, match: match, seen: 1, firstSeen: now)
            }
        }
        pending = nextPending

        for pendingKey in keys {
            guard let entry = pending[pendingKey] else { continue }
            if update.isFinal || entry.seen >= configuration.confirmations {
                if let hit = fire(entry, key: pendingKey, now: now) { hits.append(hit) }
            }
        }
        return hits
    }

    /// Fires matches that have stayed stable long enough without a newer partial.
    public func tick(now: TimeInterval) -> [AnchorHit] {
        firedThisUpdate = []
        let due = pending
            .filter { now - $0.value.firstSeen >= configuration.debounceInterval }
            .sorted { $0.value.match.start < $1.value.match.start }
        return due.compactMap { fire($0.value, key: $0.key, now: now) }
    }

    private func flush(now: TimeInterval) -> [AnchorHit] {
        pending
            .sorted { $0.value.match.start < $1.value.match.start }
            .compactMap { fire($0.value, key: $0.key, now: now) }
    }

    private func fire(_ entry: Pending, key pendingKey: PendingKey, now: TimeInterval) -> AnchorHit? {
        pending[pendingKey] = nil
        guard entry.match.start >= cursor else { return nil }
        cursor = entry.match.end
        if !firedThisUpdate.contains(entry.fragment),
           let last = lastFired[entry.fragment], now - last < configuration.fragmentCooldown {
            return nil
        }
        lastFired[entry.fragment] = now
        firedThisUpdate.insert(entry.fragment)
        return AnchorHit(fragment: entry.fragment, distance: entry.match.distance, time: now)
    }

    /// Non-overlapping matches in text order. Where candidates overlap, the closest match wins
    /// (so "the fifth mystery" is not taken for "the first mystery").
    static func findMatches(
        in text: [UInt8],
        from start: Int,
        fragments: [AnchorFragment]
    ) -> [(AnchorFragment, ApproximateMatch)] {
        var results: [(AnchorFragment, ApproximateMatch)] = []
        var position = start
        while position < text.count {
            let candidates: [(AnchorFragment, ApproximateMatch)] = fragments.compactMap { fragment in
                ApproximateMatcher.firstMatch(
                    of: fragment.folded, in: text, from: position, maxErrors: fragment.maxErrors
                ).map { (fragment, $0) }
            }
            guard let earliest = candidates.min(by: { $0.1.end < $1.1.end }) else { break }
            let overlapping = candidates.filter {
                $0.1.start < earliest.1.end && earliest.1.start < $0.1.end
            }
            let chosen = overlapping.min { lhs, rhs in
                let l = Double(lhs.1.distance) / Double(lhs.0.folded.count)
                let r = Double(rhs.1.distance) / Double(rhs.0.folded.count)
                if l != r { return l < r }
                return lhs.0.folded.count > rhs.0.folded.count
            }!
            results.append(chosen)
            position = max(chosen.1.end, position + 1)
        }
        return results
    }
}
