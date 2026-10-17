import Foundation

/// One inclusive span of a biblical book, in Douay-Rheims chapter and verse numbers.
public struct ScriptureRange: Hashable, Sendable {
    public let book: String
    public let startChapter: Int
    public let startVerse: Int
    public let endChapter: Int
    public let endVerse: Int
}

/// Turns a lectionary citation into Douay-Rheims ranges.
///
/// The same rules build the offline verse index. Letter suffixes (`3ab`, `19A`) are dropped.
/// A list written `9-10-11-12` is the span from the first number to the last.
/// An alternative after `or` keeps the book already named. A citation that is only
/// numbers is read as a psalm.
public enum ScriptureCitation {
    public static func alternatives(in citation: String) -> [[ScriptureRange]] {
        var text = normalize(citation)
        if text.range(of: #"^\d"#, options: .regularExpression) != nil,
           text.range(of: #"[A-Za-z]"#, options: .regularExpression) == nil {
            text = "Psalm " + text
        }
        let alternatives = splitOr(text)
        var parsed: [[ScriptureRange]] = []
        var carryBook: String?
        for alternative in alternatives {
            var group: [ScriptureRange] = []
            for rawClause in alternative.split(separator: ";") {
                let clause = rawClause.trimmingCharacters(in: .whitespaces)
                guard !clause.isEmpty else { continue }
                let (book, rest) = splitBook(clause, carry: carryBook)
                if let book { carryBook = book }
                guard let book, !rest.isEmpty else { continue }
                let body = rest.replacingOccurrences(of: " and ", with: ",", options: .caseInsensitive)
                var chapter: Int?
                for rawPiece in body.split(separator: ",") {
                    let piece = rawPiece.trimmingCharacters(in: .whitespaces)
                    guard !piece.isEmpty else { continue }
                    let (span, nextChapter) = parsePiece(piece, book: book, chapter: chapter)
                    chapter = nextChapter
                    if let span { group.append(span) }
                }
            }
            parsed.append(group)
        }
        return parsed
    }

    private static func splitOr(_ text: String) -> [String] {
        var results: [String] = []
        var current = ""
        var index = text.startIndex
        let token = " or "
        while index < text.endIndex {
            let remaining = text[index...]
            if remaining.lowercased().hasPrefix(token) {
                results.append(current)
                current = ""
                index = text.index(index, offsetBy: token.count)
            } else {
                current.append(text[index])
                index = text.index(after: index)
            }
        }
        results.append(current)
        return results.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func normalize(_ citation: String) -> String {
        var text = citation
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func splitBook(_ clause: String, carry: String?) -> (String?, String) {
        let lowered = clause.lowercased()
        for (alias, name) in aliases {
            guard lowered.hasPrefix(alias) else { continue }
            let next = lowered.index(lowered.startIndex, offsetBy: alias.count, limitedBy: lowered.endIndex) ?? lowered.endIndex
            if next != lowered.endIndex, lowered[next].isLetter { continue }
            let restIndex = clause.index(clause.startIndex, offsetBy: alias.count)
            let rest = clause[restIndex...].trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            return (name, rest)
        }
        return (carry, clause.trimmingCharacters(in: .whitespaces))
    }

    private static func parsePiece(_ raw: String, book: String, chapter: Int?) -> (ScriptureRange?, Int?) {
        let stripped = stripLetters(raw).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if let match = firstMatch(#"(\d+)\s*:\s*(\d+)\s*-\s*(\d+)\s*:\s*(\d+)"#, stripped), match.count == 5 {
            let startChapter = Int(match[1])!
            let endChapter = Int(match[3])!
            return (ScriptureRange(book: book, startChapter: startChapter, startVerse: Int(match[2])!, endChapter: endChapter, endVerse: Int(match[4])!), endChapter)
        }
        if let match = firstMatch(#"(\d+)\s*:\s*(\d+(?:\s*-\s*\d+)+)"#, stripped), match.count == 3 {
            let startChapter = Int(match[1])!
            let numbers = match[2].split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces))! }
            return (ScriptureRange(book: book, startChapter: startChapter, startVerse: numbers[0], endChapter: startChapter, endVerse: numbers[numbers.count - 1]), startChapter)
        }
        if let match = firstMatch(#"(\d+)\s*:\s*(\d+)"#, stripped), match.count == 3 {
            let startChapter = Int(match[1])!
            let verse = Int(match[2])!
            return (ScriptureRange(book: book, startChapter: startChapter, startVerse: verse, endChapter: startChapter, endVerse: verse), startChapter)
        }
        if let match = firstMatch(#"(\d+(?:\s*-\s*\d+)+)"#, stripped), match.count == 2 {
            let current = chapter ?? 1
            let numbers = match[1].split(separator: "-").map { Int($0.trimmingCharacters(in: .whitespaces))! }
            return (ScriptureRange(book: book, startChapter: current, startVerse: numbers[0], endChapter: current, endVerse: numbers[numbers.count - 1]), current)
        }
        if let match = firstMatch(#"(\d+)"#, stripped), match.count == 2 {
            let current = chapter ?? 1
            let verse = Int(match[1])!
            return (ScriptureRange(book: book, startChapter: current, startVerse: verse, endChapter: current, endVerse: verse), current)
        }
        return (nil, chapter)
    }

    private static func stripLetters(_ part: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\s*[A-Za-z]+\b"#) else { return part }
        let range = NSRange(part.startIndex..., in: part)
        return regex.stringByReplacingMatches(in: part, options: [], range: range, withTemplate: "$1")
    }

    private static func firstMatch(_ pattern: String, _ text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: "^(?:\(pattern))$") else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let found = match.range(at: index)
            guard found.location != NSNotFound, let swiftRange = Range(found, in: text) else { return "" }
            return String(text[swiftRange])
        }
    }

    /// Longest alias first. The Douay-Rheims book name is the value.
    private static let aliases: [(String, String)] = unsortedAliases.sorted { $0.0.count > $1.0.count }

    private static let unsortedAliases: [(String, String)] = [
        ("phiippians", "Philippians"),
        ("philippians", "Philippians"),
        ("song of songs", "Song of Solomon"),
        ("song of solomon", "Song of Solomon"),
        ("revelation of john", "Revelation of John"),
        ("revelation", "Revelation of John"),
        ("apocalypse", "Revelation of John"),
        ("sirarch", "Sirach"),
        ("ecclesiasticus", "Sirach"),
        ("sirach", "Sirach"),
        ("1 chronicles", "I Chronicles"),
        ("2 chronicles", "II Chronicles"),
        ("1 corinthians", "I Corinthians"),
        ("2 corinthians", "II Corinthians"),
        ("1 thessalonians", "I Thessalonians"),
        ("2 thessalonians", "II Thessalonians"),
        ("1 timothy", "I Timothy"),
        ("2 timothy", "II Timothy"),
        ("1 samuel", "I Samuel"),
        ("2 samuel", "II Samuel"),
        ("1 kings", "I Kings"),
        ("2 kings", "II Kings"),
        ("1 maccabees", "I Maccabees"),
        ("2 maccabees", "II Maccabees"),
        ("1 peter", "I Peter"),
        ("2 peter", "II Peter"),
        ("1 john", "I John"),
        ("2 john", "II John"),
        ("3 john", "III John"),
        ("psalms", "Psalms"),
        ("psalm", "Psalms"),
        ("genesis", "Genesis"),
        ("exodus", "Exodus"),
        ("leviticus", "Leviticus"),
        ("numbers", "Numbers"),
        ("deuteronomy", "Deuteronomy"),
        ("joshua", "Joshua"),
        ("judges", "Judges"),
        ("ruth", "Ruth"),
        ("ezra", "Ezra"),
        ("nehemiah", "Nehemiah"),
        ("tobit", "Tobit"),
        ("judith", "Judith"),
        ("esther", "Esther"),
        ("job", "Job"),
        ("proverbs", "Proverbs"),
        ("ecclesiastes", "Ecclesiastes"),
        ("wisdom", "Wisdom"),
        ("isaiah", "Isaiah"),
        ("jeremiah", "Jeremiah"),
        ("lamentations", "Lamentations"),
        ("baruch", "Baruch"),
        ("ezekiel", "Ezekiel"),
        ("daniel", "Daniel"),
        ("hosea", "Hosea"),
        ("joel", "Joel"),
        ("amos", "Amos"),
        ("obadiah", "Obadiah"),
        ("jonah", "Jonah"),
        ("micah", "Micah"),
        ("nahum", "Nahum"),
        ("habakkuk", "Habakkuk"),
        ("zephaniah", "Zephaniah"),
        ("haggai", "Haggai"),
        ("zechariah", "Zechariah"),
        ("malachi", "Malachi"),
        ("matthew", "Matthew"),
        ("mark", "Mark"),
        ("luke", "Luke"),
        ("john", "John"),
        ("acts", "Acts"),
        ("romans", "Romans"),
        ("galatians", "Galatians"),
        ("ephesians", "Ephesians"),
        ("colossians", "Colossians"),
        ("titus", "Titus"),
        ("philemon", "Philemon"),
        ("hebrews", "Hebrews"),
        ("james", "James"),
        ("jude", "Jude"),
    ]
}
