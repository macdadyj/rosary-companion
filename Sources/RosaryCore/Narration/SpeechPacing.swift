import Foundation

/// One stretch of synthesized speech, followed by a moment of quiet.
public struct SpokenPhrase: Hashable, Sendable {
    public var text: String
    /// AVSpeechUtterance rate, 0...1; 0.5 is the system's normal pace.
    public var rate: Double
    /// AVSpeechUtterance pitch multiplier, 0.5...2.
    public var pitch: Double
    public var pauseAfter: TimeInterval

    public init(text: String, rate: Double, pitch: Double, pauseAfter: TimeInterval) {
        self.text = text
        self.rate = rate
        self.pitch = pitch
        self.pauseAfter = pauseAfter
    }
}

/// How synthesized speech is paced. Calm comes mostly from real pauses between phrases rather
/// than from slowing each word down, because stretched words are what make a voice sound robotic.
public struct SpeechPacing: Hashable, Sendable {
    public static let defaultRate = 0.46
    public static let defaultPitch = 0.95
    public static let rateRange: ClosedRange<Double> = 0.34...0.56
    public static let pitchRange: ClosedRange<Double> = 0.85...1.10

    public var rate: Double
    public var pitch: Double
    /// After a full stop, question mark, or exclamation mark.
    public var sentencePause: TimeInterval = 0.45
    /// After a semicolon or colon, e.g. "hallowed be thy name;" in the Our Father.
    public var clausePause: TimeInterval = 0.25
    /// Between the parts of one narration, e.g. an intention and the Hail Mary after it.
    public var partPause: TimeInterval = 0.6

    public init(rate: Double = SpeechPacing.defaultRate, pitch: Double = SpeechPacing.defaultPitch) {
        self.rate = min(max(rate, Self.rateRange.lowerBound), Self.rateRange.upperBound)
        self.pitch = min(max(pitch, Self.pitchRange.lowerBound), Self.pitchRange.upperBound)
    }

    /// Splits `text` at sentence and clause ends. Commas stay inside a phrase; synthesizers
    /// already pause briefly there. The last phrase is followed by `finalPause`.
    public func phrases(in text: String, finalPause: TimeInterval = 0) -> [SpokenPhrase] {
        let characters = Array(text)
        var phrases: [SpokenPhrase] = []
        var start = 0
        var index = 0

        func add(_ range: Range<Int>, pause: TimeInterval) {
            let phrase = String(characters[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard phrase.contains(where: { $0.isLetter || $0.isNumber }) else { return }
            phrases.append(SpokenPhrase(text: phrase, rate: rate, pitch: pitch, pauseAfter: pause))
        }

        while index < characters.count {
            guard let pause = boundaryPause(after: characters[index]) else {
                index += 1
                continue
            }
            var end = index + 1
            while end < characters.count, Self.closingMarks.contains(characters[end]) { end += 1 }
            let atBreak = end == characters.count || characters[end].isWhitespace
            let isAbbreviation = characters[index] == "." && Self.endsWithAbbreviation(characters[start..<index])
            if atBreak && !isAbbreviation {
                add(start..<end, pause: pause)
                start = end
            }
            index = end
        }
        if start < characters.count { add(start..<characters.count, pause: 0) }

        if !phrases.isEmpty { phrases[phrases.count - 1].pauseAfter = finalPause }
        return phrases
    }

    private func boundaryPause(after character: Character) -> TimeInterval? {
        switch character {
        case ".", "!", "?": sentencePause
        case ";", ":": clausePause
        default: nil
        }
    }

    private static let closingMarks: Set<Character> = ["\"", "”", "’", "'", ")", "]"]
    private static let abbreviations: Set<String> = [
        "st", "sts", "dr", "mr", "mrs", "ms", "fr", "sr", "br", "jr", "msgr", "rev", "mt",
    ]

    /// "St." or "Dr." or an initial ("J.") doesn't end a sentence.
    private static func endsWithAbbreviation(_ characters: ArraySlice<Character>) -> Bool {
        let lastWord = String(characters)
            .split(whereSeparator: \.isWhitespace).last
            .map { $0.trimmingCharacters(in: .punctuationCharacters) } ?? ""
        guard !lastWord.isEmpty else { return false }
        return lastWord.count == 1 && lastWord.first!.isLetter || abbreviations.contains(lastWord.lowercased())
    }
}
