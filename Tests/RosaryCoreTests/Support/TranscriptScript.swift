@testable import RosaryCore

/// Simulates a speech recogniser: turns spoken sentences into the cumulative partial
/// results SFSpeechRecognizer delivers, a few words at a time.
struct TranscriptScript {
    var epoch: Int
    var segment = 0
    private(set) var spoken = ""

    init(epoch: Int) {
        self.epoch = epoch
    }

    /// Partials for `sentence`, appended to what was already said in this segment.
    mutating func say(_ sentence: String, wordsPerPartial: Int = 2) -> [TranscriptUpdate] {
        let words = sentence.split(separator: " ").map(String.init)
        var updates: [TranscriptUpdate] = []
        var index = 0
        while index < words.count {
            index = min(words.count, index + wordsPerPartial)
            let chunk = words[0..<index].joined(separator: " ")
            let text = spoken.isEmpty ? chunk : spoken + " " + chunk
            updates.append(TranscriptUpdate(epoch: epoch, segment: segment, text: text))
        }
        spoken = spoken.isEmpty ? sentence : spoken + " " + sentence
        return updates
    }

    /// The recogniser finished on its own and started a new segment.
    mutating func restartSegment() {
        segment += 1
        spoken = ""
    }
}
