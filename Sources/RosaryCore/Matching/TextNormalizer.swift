import Foundation

/// Turns recogniser output and prayer phrases into a common, error-tolerant form.
public enum TextNormalizer {
    /// Lowercased ASCII word tokens: diacritics stripped, apostrophes dropped,
    /// spoken ordinals normalised, and a few known recogniser substitutions canonicalised.
    public static func words(_ text: String) -> [String] {
        let stripped = text.decomposedStringWithCanonicalMapping.unicodeScalars
            .filter { $0.properties.generalCategory != .nonspacingMark }
        var cleaned = ""
        cleaned.reserveCapacity(stripped.count)
        for scalar in stripped {
            switch scalar {
            case "a"..."z", "0"..."9":
                cleaned.unicodeScalars.append(scalar)
            case "A"..."Z":
                cleaned.unicodeScalars.append(Unicode.Scalar(scalar.value + 32)!)
            case "'", "\u{2019}", "\u{2018}":
                continue
            default:
                cleaned.append(" ")
            }
        }
        return cleaned.split(separator: " ").map { canonical(String($0)) }
    }

    /// Space-free, phonetically folded bytes used for approximate matching.
    public static func folded(_ text: String) -> [UInt8] {
        fold(words: words(text))
    }

    public static func fold(words: [String]) -> [UInt8] {
        var out: [UInt8] = []
        for word in words {
            out.append(contentsOf: foldWord(word))
        }
        return collapseRepeats(out)
    }

    static let substitutions: [String: String] = [
        "1st": "first", "2nd": "second", "3rd": "third", "4th": "fourth", "5th": "fifth",
        "forth": "fourth",
        // Older wording of the Glory Be, Sign of the Cross, and Creed.
        "ghost": "spirit",
        "oh": "o",
    ]

    static func canonical(_ word: String) -> String {
        substitutions[word] ?? word
    }

    private static func foldWord(_ word: String) -> [UInt8] {
        let bytes = Array(word.utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            let c = bytes[i]
            let next: UInt8? = i + 1 < bytes.count ? bytes[i + 1] : nil
            switch (c, next) {
            case (UInt8(ascii: "w"), UInt8(ascii: "h")):
                out.append(UInt8(ascii: "w")); i += 2
            case (UInt8(ascii: "p"), UInt8(ascii: "h")):
                out.append(UInt8(ascii: "f")); i += 2
            case (UInt8(ascii: "c"), UInt8(ascii: "k")):
                out.append(UInt8(ascii: "k")); i += 2
            case (UInt8(ascii: "y"), _):
                out.append(UInt8(ascii: "i")); i += 1
            default:
                out.append(c); i += 1
            }
        }
        return out
    }

    private static func collapseRepeats(_ bytes: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        for b in bytes where out.last != b {
            out.append(b)
        }
        return out
    }
}
