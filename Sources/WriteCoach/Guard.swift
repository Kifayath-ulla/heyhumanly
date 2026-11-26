import AppKit
import NaturalLanguage

/// Checks a model rewrite against the original before anything is shown or pasted.
/// Small local models sometimes "improve" a message by changing what it says ("thung" → "file",
/// "gng" → "going"). Every change is looked at on its own; the ones that alter meaning, touch slang,
/// or only restyle something harmless are put back to the writer's own words.
@MainActor
enum RewriteGuard {
    /// Chat shorthand that is never "corrected".
    static let slang: Set<String> = [
        "gng", "ngl", "tbh", "idk", "imo", "imho", "fr", "rn", "btw", "lol", "lmao", "brb", "omg", "ikr", "smh", "fyi", "asap",
        "bro", "bruh", "gonna", "wanna", "gotta", "kinda", "sorta", "yeah", "yep", "yup", "nope", "nah", "ok", "okay", "pls", "plz",
        "thx", "ty", "np", "nvm", "tho", "cuz", "coz", "bc", "idc", "wdym", "hbu", "wyd", "ofc", "afaik", "iirc", "dm", "lmk",
        "ttyl", "gg", "gm", "gn", "dude", "yo", "hey", "hiya", "ya", "yall", "y'all", "ain't", "lemme", "gimme", "dunno", "tldr",
        "tmrw", "tmr", "msg", "pic", "pics", "ppl", "abt", "thru", "bday", "prolly", "rly", "srsly", "gtg", "jk", "wtf", "wth", "af",
        "sus", "lowkey", "highkey", "legit", "fam", "sis", "mate", "hmm", "uh", "um", "haha", "hehe", "aight", "ight", "wassup", "sup",
    ]

    private static let dismissedKey = "heyhumanly.dismissed"
    static var dismissed: Set<String> { Set(UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []) }
    static func key(from: String, to: String) -> String { from.lowercased() + "\u{2192}" + to.lowercased() }
    static func rememberDismissal(from: String, to: String) {
        var list = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        let k = key(from: from, to: to)
        guard !list.contains(k) else { return }
        list.append(k)
        UserDefaults.standard.set(Array(list.suffix(600)), forKey: dismissedKey)
    }
    static func clearDismissals() { UserDefaults.standard.removeObject(forKey: dismissedKey) }

    /// The rewrite with unsafe or unwanted changes reverted.
    /// With `fixOnly`, a rewrite that cuts the writer's words is dropped: only the deterministic fixes are applied to the original.
    static func sanitize(original: String, rewrite: String, preserve: [String], fixOnly: Bool = false) -> String {
        let out = TextSafety.apply(original: original, rewrite: guarded(original: original, rewrite: rewrite, preserve: preserve), preserve: preserve)
        guard fixOnly, TextSafety.cutsWords(original: original, rewrite: out, preserve: preserve) else { return out }
        return TextSafety.apply(original: original, rewrite: original, preserve: preserve)
    }

    private static func guarded(original: String, rewrite: String, preserve: [String]) -> String {
        let set = ChangeSet(original: original, rewrite: rewrite)
        guard !set.changes.isEmpty else { return rewrite }
        let keep = Set(preserve.map { $0.lowercased() })
        // First allow numbers the rewrite moved; if that loses one (its new spot was reverted), keep every number in place.
        let lenient = apply(set, original: original, rewrite: rewrite, keep: keep, allowMoves: true)
        if covers(lenient, original) { return lenient }
        return apply(set, original: original, rewrite: rewrite, keep: keep, allowMoves: false)
    }

    private static func apply(_ set: ChangeSet, original: String, rewrite: String, keep: Set<String>, allowMoves: Bool) -> String {
        let gone = dismissed
        var accepted = Set<UUID>()
        var overrides: [UUID: String] = [:]
        for c in set.changes {
            if gone.contains(key(from: c.from, to: c.to)) { continue }
            let moved = allowMoves && numbersSurvive(c.from, original: original, rewrite: rewrite)
            switch verdict(from: c.from, to: c.to, keep: keep, numbersMoved: moved) {
            case .keep: accepted.insert(c.id)
            case .drop: break
            case .replace(let word): accepted.insert(c.id); overrides[c.id] = word
            }
        }
        if accepted.count == set.changes.count && overrides.isEmpty { return rewrite }
        return set.text(accepted: accepted, overrides: overrides)
    }

    enum Verdict: Equatable { case keep, drop, replace(String) }

    static func verdict(from: String, to: String, keep: Set<String> = [], numbersMoved: Bool = false) -> Verdict {
        let fromWords = words(from), toWords = Set(words(to))
        // Slang, shorthand and the user's own dictionary words stay as written.
        for w in fromWords where !toWords.contains(w) {
            if slang.contains(w) || keep.contains(w) { return .drop }
        }
        // Numbers are facts: a changed or dropped number ("4,200" → "4,000") is never accepted.
        let fromDigits = from.filter(\.isNumber)
        if !numbersMoved, !fromDigits.isEmpty, fromDigits != to.filter(\.isNumber) { return .drop }
        if from.isEmpty || to.isEmpty { return .keep }
        // "5pm" → "5 p.m.", "10k" → "10K": formatting taste, not a mistake.
        let a = alnum(from), b = alnum(to)
        if a == b, a.contains(where: \.isNumber), a.contains(where: \.isLetter) { return .drop }
        // "I will" → "I'll", "do not" → "don't": both are right.
        if a != b || from.contains(" ") != to.contains(" "), expand(from) == expand(to) { return .drop }
        // One word swapped for another.
        guard fromWords.count == 1, toWords.count == 1, let f = fromWords.first, let t = toWords.first, f != t,
              f.allSatisfy(\.isLetter), t.allSatisfy(\.isLetter) else { return .keep }
        let distance = ChangeSet.levenshtein(f, t)
        let similar = distance <= max(1, min(f.count, t.count) / 2)
        if !isWord(f) {
            // A typo. The fix must be the word they meant, not a "better" word.
            if similar { return .keep }
            if let guess = bestGuess(for: f) { return .replace(matchCase(guess, like: to)) }
            return .drop
        }
        // Both are real words. A noun, adjective or adverb replaced by an unrelated one changes the meaning
        // ("thing" → "document"). Verbs, pronouns and small grammar words are left to the grammar check.
        if !similar, f.count >= 4, t.count >= 4, lemma(f) != lemma(t),
           let cf = lexicalClass(f), let ct = lexicalClass(t), cf == ct, [.noun, .adjective, .adverb].contains(cf) { return .drop }
        return .keep
    }

    // MARK: Helpers

    /// Whole numbers as written: "12.50", "4,200", "10:30" and "12/3" are one token each.
    private static func numbers(_ s: String) -> [String] {
        let re = try! NSRegularExpression(pattern: "\\d+(?:[.,:/]\\d+)*")
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { Range($0.range, in: s).map { String(s[$0]) } }
    }
    private static func count(_ n: String, in list: [String]) -> Int { list.filter { $0 == n }.count }
    private static func numbersSurvive(_ cut: String, original: String, rewrite: String) -> Bool {
        let runs = numbers(cut)
        guard !runs.isEmpty else { return false }
        let before = numbers(original), after = numbers(rewrite)
        return runs.allSatisfy { count($0, in: after) >= count($0, in: before) }
    }
    private static func covers(_ text: String, _ original: String) -> Bool {
        let before = numbers(original), after = numbers(text)
        return before.allSatisfy { count($0, in: after) >= count($0, in: before) }
    }

    private static func words(_ s: String) -> [String] {
        s.lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }.filter { !$0.isEmpty }
    }

    private static func alnum(_ s: String) -> String { String(s.lowercased().filter { $0.isLetter || $0.isNumber }) }

    private static let contractions: [(String, String)] = [
        ("won't", "will not"), ("can't", "can not"), ("cannot", "can not"), ("shan't", "shall not"), ("let's", "let us"),
        ("n't", " not"), ("'ll", " will"), ("'re", " are"), ("'ve", " have"), ("'m", " am"), ("'d", " would"),
        ("it's", "it is"), ("that's", "that is"), ("there's", "there is"), ("what's", "what is"), ("he's", "he is"), ("she's", "she is"),
    ]
    private static func expand(_ s: String) -> String {
        var t = s.lowercased().replacingOccurrences(of: "’", with: "'")
        for (short, long) in contractions { t = t.replacingOccurrences(of: short, with: long) }
        return String(t.filter { $0.isLetter || $0.isNumber })
    }

    private static func isWord(_ w: String) -> Bool {
        NSSpellChecker.shared.checkSpelling(of: w, startingAt: 0, language: "en", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil).location == NSNotFound
    }

    private static func bestGuess(for w: String) -> String? {
        let guesses = NSSpellChecker.shared.guesses(forWordRange: NSRange(location: 0, length: (w as NSString).length), in: w, language: "en", inSpellDocumentWithTag: 0) ?? []
        return guesses.first { !$0.contains(" ") && ChangeSet.levenshtein(w, $0.lowercased()) <= max(1, w.count / 2) }
    }

    private static func matchCase(_ word: String, like sample: String) -> String {
        let trailing = String(sample.reversed().prefix { !$0.isLetter && !$0.isNumber }.reversed())
        let leading = String(sample.prefix { !$0.isLetter && !$0.isNumber })
        let core = sample.first(where: \.isLetter)?.isUppercase == true ? word.prefix(1).uppercased() + word.dropFirst() : word
        return leading + core + trailing
    }

    private static func lemma(_ w: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma]); tagger.string = w
        return tagger.tag(at: w.startIndex, unit: .word, scheme: .lemma).0?.rawValue.lowercased() ?? w
    }

    private static func lexicalClass(_ w: String) -> NLTag? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass]); tagger.string = w
        return tagger.tag(at: w.startIndex, unit: .word, scheme: .lexicalClass).0
    }
}
