/// Approximate substring search (Sellers' algorithm): finds where `pattern` occurs in `text`
/// with at most `maxErrors` insertions, deletions, or substitutions.
public struct ApproximateMatch: Hashable, Sendable {
    /// Half-open byte range in the searched text.
    public let start: Int
    public let end: Int
    public let distance: Int
}

public enum ApproximateMatcher {
    /// The earliest-ending occurrence at or after `from`, refined to the best distance
    /// among the next few end positions so the match is not cut short.
    public static func firstMatch(
        of pattern: [UInt8],
        in text: [UInt8],
        from: Int = 0,
        maxErrors: Int
    ) -> ApproximateMatch? {
        let m = pattern.count
        guard m > 0, from < text.count else { return nil }

        // cost[i] = edit distance of pattern[0..<i] against the best text substring ending here.
        var cost = Array(0...m)
        var start = Array(repeating: from, count: m + 1)
        var newCost = cost
        var newStart = start

        var best: ApproximateMatch?
        var lookahead = 0

        for j in from..<text.count {
            let ch = text[j]
            newCost[0] = 0
            newStart[0] = j + 1
            for i in 1...m {
                let substitution = cost[i - 1] + (pattern[i - 1] == ch ? 0 : 1)
                let skipText = cost[i] + 1
                let skipPattern = newCost[i - 1] + 1
                if substitution <= skipText && substitution <= skipPattern {
                    newCost[i] = substitution
                    newStart[i] = start[i - 1]
                } else if skipText <= skipPattern {
                    newCost[i] = skipText
                    newStart[i] = start[i]
                } else {
                    newCost[i] = skipPattern
                    newStart[i] = newStart[i - 1]
                }
            }
            swap(&cost, &newCost)
            swap(&start, &newStart)

            let distance = cost[m]
            if let current = best {
                if distance < current.distance {
                    best = ApproximateMatch(start: start[m], end: j + 1, distance: distance)
                }
                lookahead -= 1
                if lookahead <= 0 || distance == 0 { break }
            } else if distance <= maxErrors {
                best = ApproximateMatch(start: start[m], end: j + 1, distance: distance)
                if distance == 0 { break }
                lookahead = maxErrors
            }
        }
        return best
    }
}
