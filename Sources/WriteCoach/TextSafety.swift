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
    /// Words in `preserve` (the user's dictionary) are never corrected.
    static func apply(original: String, rewrite: String, preserve: [String] = []) -> String {
        let keep = Set(preserve.map { $0.lowercased() })
        let fixed = fixTypos(original: original, rewrite: rewrite, preserve: keep)
        return restoreCode(original: original, rewrite: keep.contains("i") ? fixed : capitalizeI(fixed))
    }

    /// Inline code spans: text between single backticks on one line.
    static func codeRanges(_ ns: NSString) -> [NSRange] {
        guard ns.range(of: "`").location != NSNotFound else { return [] }
        return codeRegex.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).map(\.range)
    }
    private static let codeRegex = try! NSRegularExpression(pattern: "`[^`\\n]+`")

    /// Puts every backtick span of the original back into the rewrite unchanged, each in place of the rewrite span
    /// closest to it (so reordered spans keep their own code). If the rewrite lost or added a span, the original is returned.
    static func restoreCode(original: String, rewrite: String) -> String {
        let o = original as NSString
        let spans = codeRanges(o)
        guard !spans.isEmpty else { return rewrite }
        let r = rewrite as NSString
        let target = codeRanges(r)
        guard target.count == spans.count else { return original }
        let originals = spans.map { o.substring(with: $0) }
        var unused = Array(originals.indices)
        var picks: [Int] = []
        for t in target {
            let s = r.substring(with: t)
            let best = unused.min { distance(originals[$0], s) < distance(originals[$1], s) }!
            picks.append(best); unused.removeAll { $0 == best }
        }
        var out = rewrite as NSString
        for (t, pick) in zip(target, picks).reversed() { out = out.replacingCharacters(in: t, with: originals[pick]) as NSString }
        return out as String
    }

    /// Where the original had a known typo, the rewrite must use the intended word (not "tbh" for "teh"),
    /// and typos the model left in are corrected.
    static func fixTypos(original: String, rewrite: String, preserve: Set<String> = []) -> String {
        let lowerOriginal = original.lowercased()
        let typos = commonTypos.filter { !preserve.contains($0.key) && lowerOriginal.contains($0.key) }
        guard !typos.isEmpty else { return rewrite }
        let set = ChangeSet(original: original, rewrite: rewrite)
        var overrides: [UUID: String] = [:]
        for c in set.changes {
            let from = c.from.trimmingCharacters(in: .punctuationCharacters)
            guard let right = typos[from.lowercased()], !from.contains(" ") else { continue }
            let to = c.to.trimmingCharacters(in: .punctuationCharacters)
            if to.lowercased() != right {
                let lead = c.to.prefix { $0.isPunctuation }, trail = String(c.to.reversed().prefix { $0.isPunctuation }.reversed())
                overrides[c.id] = lead + matchCase(right, like: from) + (c.to == lead ? "" : trail)
            }
        }
        var out = overrides.isEmpty ? rewrite : set.text(accepted: Set(set.changes.map(\.id)), overrides: overrides)
        for (typo, right) in typos where out.lowercased().contains(typo) {
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

    /// Character edit distance, for matching short code spans.
    private static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var prev = Array(0...b.count)
        for i in 1...max(1, a.count) where i <= a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...max(1, b.count) where j <= b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }

    private static func matchCase(_ word: String, like sample: String) -> String {
        guard let f = sample.first, f.isUppercase else { return word }
        return sample.count > 1 && sample == sample.uppercased() ? word.uppercased() : word.prefix(1).uppercased() + word.dropFirst()
    }
}
