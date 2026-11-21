import Foundation

/// Deterministic clean-ups applied to every model rewrite: code stays as written, well-known typos get the
/// right word, and the pronoun "i" is capitalised. Mirrored in extension/core.js (restoreCode, fixTypos).
enum TextSafety {
    /// Misspellings a small model sometimes "fixes" into the wrong word ("teh" → "tbh").
    static let commonTypos: [String: String] = [
        "teh": "the", "hte": "the", "adn": "and", "nad": "and", "taht": "that", "thta": "that", "wiht": "with", "whit": "with",
        "becuase": "because", "becasue": "because", "recieve": "receive", "recieved": "received", "seperate": "separate",
        "definately": "definitely", "occured": "occurred", "untill": "until", "wich": "which", "thier": "their", "freind": "friend",
        "beleive": "believe", "tommorow": "tomorrow", "tomorow": "tomorrow", "alot": "a lot", "youre": "you're", "dont": "don't",
    ]

    /// All clean-ups for a coaching rewrite (Quick Fix, Teach Me, inline).
    static func apply(original: String, rewrite: String) -> String {
        restoreCode(original: original, rewrite: capitalizeI(fixTypos(original: original, rewrite: rewrite)))
    }

    /// Inline code spans: text between single backticks on one line.
    static func codeRanges(_ ns: NSString) -> [NSRange] {
        guard ns.range(of: "`").location != NSNotFound else { return [] }
        return codeRegex.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).map(\.range)
    }
    private static let codeRegex = try! NSRegularExpression(pattern: "`[^`\\n]+`")

    /// Puts every backtick span of the original back into the rewrite unchanged. If the rewrite lost or added
    /// a span, the spans can't be matched up, so the original is returned as is.
    static func restoreCode(original: String, rewrite: String) -> String {
        let o = original as NSString
        let spans = codeRanges(o)
        guard !spans.isEmpty else { return rewrite }
        let r = rewrite as NSString
        let target = codeRanges(r)
        guard target.count == spans.count else { return original }
        var out = rewrite as NSString
        for (from, to) in zip(spans, target).reversed() { out = out.replacingCharacters(in: to, with: o.substring(with: from)) as NSString }
        return out as String
    }

    /// Where the original had a known typo, the rewrite must use the intended word (not "tbh" for "teh"),
    /// and typos the model left in are corrected.
    static func fixTypos(original: String, rewrite: String) -> String {
        let lowerOriginal = original.lowercased()
        guard commonTypos.keys.contains(where: { lowerOriginal.contains($0) }) else { return rewrite }
        let set = ChangeSet(original: original, rewrite: rewrite)
        var overrides: [UUID: String] = [:]
        for c in set.changes {
            let from = c.from.trimmingCharacters(in: .punctuationCharacters)
            guard let right = commonTypos[from.lowercased()], !from.contains(" ") else { continue }
            let to = c.to.trimmingCharacters(in: .punctuationCharacters)
            if to.lowercased() != right {
                let lead = c.to.prefix { $0.isPunctuation }, trail = String(c.to.reversed().prefix { $0.isPunctuation }.reversed())
                overrides[c.id] = lead + matchCase(right, like: from) + (c.to == lead ? "" : trail)
            }
        }
        var out = overrides.isEmpty ? rewrite : set.text(accepted: Set(set.changes.map(\.id)), overrides: overrides)
        for (typo, right) in commonTypos where out.lowercased().contains(typo) {
            let re = try! NSRegularExpression(pattern: "\\b\(typo)\\b", options: [.caseInsensitive])
            let ns = out as NSString
            for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)).reversed() {
                out = (out as NSString).replacingCharacters(in: m.range, with: matchCase(right, like: ns.substring(with: m.range)))
            }
        }
        return out
    }

    /// The pronoun "i" on its own ("i think", "i'm", "and i") becomes "I". "i.e." and code are left alone.
    static func capitalizeI(_ text: String) -> String {
        guard text.contains("i") else { return text }
        let ns = text as NSString
        let code = codeRanges(ns)
        var out = text as NSString
        for m in pronounRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed()
        where !code.contains(where: { NSLocationInRange(m.range.location, $0) }) {
            out = out.replacingCharacters(in: m.range, with: "I") as NSString
        }
        return out as String
    }
    private static let pronounRegex = try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}'’_.@/`-])i(?=['’](?:m|d|ll|ve)\\b|[\\s,!?;:)]|\\.(?![\\p{L}\\p{N}])|$)")

    /// Single-word fixes in a rewrite ("thung" → "thing"), for showing what changed when no habit was found.
    static func wordFixes(original: String, rewrite: String) -> [(from: String, to: String)] {
        ChangeSet(original: original, rewrite: rewrite).changes
            .filter { !$0.from.isEmpty && !$0.to.isEmpty && !$0.from.contains(" ") && !$0.to.contains(" ") }
            .map { ($0.from, $0.to) }
    }

    private static func matchCase(_ word: String, like sample: String) -> String {
        guard let f = sample.first, f.isUppercase else { return word }
        return sample.count > 1 && sample == sample.uppercased() ? word.uppercased() : word.prefix(1).uppercased() + word.dropFirst()
    }
}
