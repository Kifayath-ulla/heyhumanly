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
    /// `keepSlang` is false only for Professional, which is asked to spell slang out.
    static func apply(original: String, rewrite: String, preserve: [String] = [], keepSlang slang: Bool = true) -> String {
        let keep = Set(preserve.map { $0.lowercased() })
        var fixed = fixGrammar(original: original, rewrite: fixTypos(original: original, rewrite: rewrite, preserve: keep))
        if slang { fixed = keepSlang(original: original, rewrite: fixed) }
        fixed = keepLowercase(original: original, rewrite: fixed)
        return restoreCode(original: original, rewrite: keep.contains("i") ? fixed : capitalizeI(fixed))
    }

    /// Grammar slips a small model often leaves in ("I has", "we was"). Fixed only when the writer's text had them.
    /// Only subject-only pronouns, so "the thing I sent you was" is left alone. Mirrored in extension/core.js (fixGrammar).
    private static let grammarRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: "\\b([Ii]) has\\b"), "$1 have"),
        (try! NSRegularExpression(pattern: "\\b(we|they) was\\b", options: .caseInsensitive), "$1 were"),
        (try! NSRegularExpression(pattern: "\\b(t)heir (is|are|was|were)\\b", options: .caseInsensitive), "$1here $2"),
        (try! NSRegularExpression(pattern: "\\b(should|could|would|must|might) of\\b(?! course)", options: .caseInsensitive), "$1 have"),
        (try! NSRegularExpression(pattern: "\\b(he|she) don(['’]?)t\\b", options: .caseInsensitive), "$1 doesn$2t"),
    ]

    static func fixGrammar(original: String, rewrite: String) -> String {
        var out = keepOfCourse(original: original, rewrite: rewrite)
        for (re, template) in grammarRules
        where re.firstMatch(in: original, range: NSRange(location: 0, length: (original as NSString).length)) != nil {
            out = re.stringByReplacingMatches(in: out, range: NSRange(location: 0, length: (out as NSString).length), withTemplate: template)
        }
        return out
    }

    /// Fix only must not cut the writer's words: true when the rewrite drops two or more of them and is two or more
    /// words shorter than the original with only the deterministic fixes. Mirrored in extension/core.js (cutsWords).
    static func cutsWords(original: String, rewrite: String, preserve: [String] = []) -> Bool {
        let base = tokens(apply(original: original, rewrite: original, preserve: preserve)), after = tokens(rewrite)
        var left: [String: Int] = [:]
        for w in after { left[w, default: 0] += 1 }
        var missing = 0
        for w in base { if let n = left[w], n > 0 { left[w] = n - 1 } else { missing += 1 } }
        return missing >= 2 && base.count - after.count >= 2
    }

    /// Small models invent content: a cause the writer never gave ("late due to a bug") or a whole new sentence ("I apologize for
    /// any confusion."). A new cause falls back to the deterministic fixes; a sentence that shares no content word with the original
    /// is dropped. An apology or assistant line the writer never wrote ("We apologize for the delay.", "Let me know if you need help.")
    /// or a rewrite whose content words are all new (none of the writer's) falls back to the deterministic fixes. Friendly may add warmth and
    /// sentences, so it only gets the assistant and content checks. Mirrored in extension/core.js (dropInvented).
    private static let causal = try! NSRegularExpression(pattern: "\\b(?:due to|because|cuz|coz|bcuz|b/c|therefore|as a result|caused by|so that|hence|thus)\\b", options: .caseInsensitive)
    private static let assistant = try! NSRegularExpression(pattern: "\\b(?:here(?:'|’)?s|here is) (?:a|an|the|your) [^.!?:\\n]*\\b(?:version|rewrite|message)\\b|\\bI(?:'|’)?d be (?:happy|glad) to help\\b|\\bI(?:'|’)?m (?:happy|glad) to help\\b|\\bno problem at all\\b|\\bfeel free to ask\\b|\\bask me again\\b|\\bif you need (?:any )?(?:more|further|additional) (?:help|info|information|assistance)\\b|\\b(?:sorry|sry) to hear\\b|\\bhope this helps\\b", options: .caseInsensitive)
    private static let lowercaseBc = try! NSRegularExpression(pattern: "\\bbc\\b")
    private static let intro = try! NSRegularExpression(pattern: "\\b(?:here(?:'|’)?s|here is) (?:a|an|the|your) [^.!?:\\n]*\\b(?:version|rewrite|message)\\b", options: .caseInsensitive)
    private static let apology = try! NSRegularExpression(pattern: "\\b(?:apologi[sz]e[sd]?|apologies|sorry|sry|srry|soz|my (?:mistake|bad)|oops)\\b", options: .caseInsensitive)
    private static let stop: Set<String> = ["have", "that", "this", "with", "from", "your", "will", "would", "could", "should", "there", "their", "what", "when",
        "been", "were", "they", "just", "more", "need", "also", "about", "into", "them", "then", "than", "some", "please", "thanks", "thank"]
    private static let sentence = try! NSRegularExpression(pattern: "(?:`[^`\\n]+`|[.!?]+(?=\\S)|[^.!?])+(?:[.!?]+|$)\\s*")

    private static func contentWords(_ s: String) -> Set<String> {
        Set(tokens(s).filter { $0.count > 3 && !stop.contains($0) }.map { String($0.prefix(4)) })
    }

    static func dropInvented(original: String, rewrite: String, preserve: [String] = [], keepSlang slang: Bool = true, friendly: Bool = false) -> String {
        func plain(_ s: String) -> String {
            codeRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: " ")
        }
        func hits(_ re: NSRegularExpression, _ s: String) -> Int {
            let p = plain(s)
            return re.numberOfMatches(in: p, range: NSRange(location: 0, length: (p as NSString).length))
        }
        let fallback = codeRanges(original as NSString).isEmpty ? apply(original: original, rewrite: original, preserve: preserve, keepSlang: slang) : original
        // A lowercase "bc" the writer typed is a reason; one in the rewrite may be a lowercased place name (BC).
        if !friendly && hits(causal, rewrite) > hits(causal, original) + hits(lowercaseBc, original) { return fallback }
        let fixed = apply(original: original, rewrite: original, preserve: preserve)
        let seen = contentWords((original + " " + fixed).replacingOccurrences(of: "`", with: " "))
        var out = rewrite
        if !friendly { out = dropAddedSentences(original: original, rewrite: rewrite, seen: seen) }
        // A rewrite that opens with an assistant line ("Sorry to hear that!") is a reply, even if that line gets trimmed below.
        let lead = sentence.firstMatch(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length)).map { (rewrite as NSString).substring(with: $0.range) } ?? rewrite
        let opener = intro.stringByReplacingMatches(in: lead, range: NSRange(location: 0, length: (lead as NSString).length), withTemplate: " ")
        if hits(assistant, opener) > hits(assistant, original) { return fallback }
        if hits(assistant, out) > hits(assistant, original) { return fallback }
        if !friendly && hits(apology, out) > hits(apology, original) { return fallback }
        // A rewrite whose content words are all new replaced the message instead of rewriting it.
        let kept = contentWords(out.replacingOccurrences(of: "`", with: " "))
        if seen.count >= 3 && !kept.isEmpty && seen.isDisjoint(with: kept) { return fallback }
        return out
    }

    private static func dropAddedSentences(original: String, rewrite: String, seen: Set<String>) -> String {
        let ns = rewrite as NSString
        let parts = sentence.matches(in: rewrite, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        guard parts.joined() == rewrite else { return rewrite }
        // Only sentences the model added, and only at the start or end: a rewritten sentence of the writer's always stays.
        var extra = parts.count - max(1, sentence.numberOfMatches(in: original, range: NSRange(location: 0, length: (original as NSString).length)))
        var (a, b) = (0, parts.count)
        func unrelated(_ p: String) -> Bool { let w = contentWords(p); return !w.isEmpty && w.isDisjoint(with: seen) }
        while extra > 0, b - a > 1, unrelated(parts[b - 1]) { b -= 1; extra -= 1 }
        while extra > 0, b - a > 1, unrelated(parts[a]) { a += 1; extra -= 1 }
        return a == 0 && b == parts.count ? rewrite : parts[a..<b].joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Small models sometimes answer the message instead of rewriting it ("thx for the help" -> "No problem at all!", "Can you send
    /// it?" -> "Sure, I can send it."). Every style, Friendly too, then falls back to the deterministic fixes. Mirrored in
    /// extension/core.js (dropReply).
    private static let reply = try! NSRegularExpression(pattern: "^\\W*(sure|no problem|of course|absolutely|certainly|you['’]re welcome|you are welcome|happy to|glad to|great question|my pleasure|anytime|no worries|shoot)\\b", options: .caseInsensitive)
    private static let ack = try! NSRegularExpression(pattern: "^\\W*(?:yep|yeah|yes|yup|ok|okay|sure|np|no prob|will do|got it|sounds good|of course|absolutely|certainly)\\b", options: .caseInsensitive)
    private static let asks = try! NSRegularExpression(pattern: "\\b(?:can|could|would|will) you\\b", options: .caseInsensitive)
    private static let offers = try! NSRegularExpression(pattern: "\\bI(?:['’]ll| will| can(?!['’]t)| could)\\b", options: .caseInsensitive)

    static func dropReply(original: String, rewrite: String, preserve: [String] = [], keepSlang slang: Bool = true) -> String {
        func has(_ re: NSRegularExpression, _ s: String) -> Bool { re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil }
        let lead = reply.firstMatch(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length))
            .map { (rewrite as NSString).substring(with: $0.range(at: 1)).lowercased().replacingOccurrences(of: "’", with: "'") }
        let quoted = original.lowercased().replacingOccurrences(of: "’", with: "'")
        let acked = has(ack, original) && (!original.contains("?") || rewrite.contains("?"))
        let answers = (lead.map { !acked && !quoted.contains($0) } ?? false) || (has(asks, original) && has(offers, rewrite) && !has(offers, original))
        guard answers else { return rewrite }
        return codeRanges(original as NSString).isEmpty ? apply(original: original, rewrite: original, preserve: preserve, keepSlang: slang) : original
    }

    /// Code spans are left out: restoreCode puts them back as written anyway.
    private static func tokens(_ s: String) -> [String] {
        codeRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: " ")
            .lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") }).map(String.init)
    }

    /// "I should of course check" is not a "should of" slip. If the model read it as one ("I should have checked"),
    /// the writer's words go back. Mirrored in extension/core.js (keepOfCourse).
    private static let modalPhrase = try! NSRegularExpression(pattern: "\\b(should|could|would|must|might) (have|of course|of)\\b(?: (\\w+))?", options: .caseInsensitive)

    static func keepOfCourse(original: String, rewrite: String) -> String {
        guard count("of course", in: rewrite) < count("of course", in: original) else { return rewrite }
        let ns = original as NSString, out = rewrite as NSString
        let before = modalPhrase.matches(in: original, range: NSRange(location: 0, length: ns.length))
        let after = modalPhrase.matches(in: rewrite, range: NSRange(location: 0, length: out.length))
        // Paired in order; if the model added or dropped one, the pairing is unclear and nothing changes.
        guard before.count == after.count else { return rewrite }
        var result = out
        for (b, a) in zip(before, after).reversed() {
            let modal = out.substring(with: a.range(at: 1))
            guard ns.substring(with: b.range(at: 2)).lowercased() == "of course", out.substring(with: a.range(at: 2)).lowercased() == "have",
                  ns.substring(with: b.range(at: 1)).lowercased() == modal.lowercased(), b.range(at: 3).location != NSNotFound else { continue }
            result = result.replacingCharacters(in: a.range, with: modal + " of course " + ns.substring(with: b.range(at: 3))) as NSString
        }
        return result as String
    }

    /// Slang the writer typed stays when the model spelled it out ("thx" → "thanks"). Only new expansions are reverted.
    /// Mirrored in extension/core.js (keepSlang).
    static let slang: [(String, [String])] = [
        ("thx", ["thanks", "thank you"]), ("ty", ["thank you"]), ("pls", ["please"]), ("plz", ["please"]), ("btw", ["by the way"]),
        ("idk", ["i don't know", "i do not know"]), ("rn", ["right now"]), ("imo", ["in my opinion"]), ("tbh", ["to be honest"]),
        ("u", ["you"]), ("ur", ["your", "you're"]), ("gonna", ["going to"]), ("wanna", ["want to"]),
        ("sry", ["sorry"]), ("cuz", ["because"]), ("ppl", ["people"]), ("msg", ["message"]), ("tmrw", ["tomorrow"]), ("nvm", ["never mind"]),
        ("lmk", ["let me know"]),
    ]

    static func keepSlang(original: String, rewrite: String) -> String {
        var out = rewrite
        for (short, longs) in slang {
            let prose = { (s: String) in codeRegex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: " ") }
            var missing = count(short, in: prose(original)) - count(short, in: prose(out))
            for long in longs where missing > 0 && count(long, in: original) == 0 {
                let code = codeRanges(out as NSString)
                let matches = wordRegex(long).matches(in: out, range: NSRange(location: 0, length: (out as NSString).length))
                    .filter { m in !code.contains { NSIntersectionRange($0, m.range).length > 0 } }
                for m in matches.prefix(missing).reversed() {
                    let ns = out as NSString
                    out = ns.replacingCharacters(in: m.range, with: matchCase(short, like: ns.substring(with: m.range)))
                }
                missing -= min(missing, matches.count)
            }
        }
        return out
    }

    private static func wordRegex(_ word: String) -> NSRegularExpression {
        let pattern = NSRegularExpression.escapedPattern(for: word).replacingOccurrences(of: "'", with: "['’]")
        return try! NSRegularExpression(pattern: "(?<![A-Za-z]['’])\\b" + pattern + "\\b(?!['’][A-Za-z])", options: .caseInsensitive)
    }

    private static func count(_ word: String, in text: String) -> Int {
        wordRegex(word).numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    /// Inline code spans: text between single backticks on one line.
    static func codeRanges(_ ns: NSString) -> [NSRange] {
        guard ns.range(of: "`").location != NSNotFound else { return [] }
        return codeRegex.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).map(\.range)
    }
    private static let codeRegex = try! NSRegularExpression(pattern: "`[^`\\n]+`")

    /// Puts every backtick span of the original back into the rewrite unchanged, each in place of the rewrite span
    /// closest to it (so reordered spans keep their own code). If the rewrite lost or added a span, the original is returned.
    /// A message typed all in lowercase stays lowercase, even if the model capitalised it.
    static func keepLowercase(original: String, rewrite: String) -> String {
        original == original.lowercased() && original != original.uppercased() ? rewrite.lowercased() : rewrite
    }

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
                let lead = String(c.to.prefix { $0.isPunctuation }), trail = String(c.to.reversed().prefix { $0.isPunctuation }.reversed())
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
    /// One line naming the edits in a rewrite, including cut and added words.
    static func changeSummary(original: String, rewrite: String) -> String {
        let changes = ChangeSet(original: original, rewrite: rewrite).changes
        guard !changes.isEmpty else { return "Only spacing changed. The rest was already clear." }
        let parts = changes.prefix(4).map { c -> String in
            if c.to.isEmpty { return "cut “\(c.from)”" }
            if c.from.isEmpty { return "added “\(c.to)”" }
            return "“\(c.from)” → “\(c.to)”"
        }
        let more = changes.count > 4 ? ", and \(changes.count - 4) more" : ""
        return "Changed " + parts.joined(separator: ", ") + more + ". The rest was already clear."
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
