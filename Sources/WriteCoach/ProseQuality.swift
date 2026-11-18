import Foundation

/// Prose-quality checks: passive voice, wordy phrases with shorter replacements, repeated sentence openers,
/// and a Flesch-Kincaid readability grade.
///
/// The approach, the phrase list and the formulas are adapted from Lexicon by Aashish Harishchandre
/// (https://github.com/AashishH15/Lexicon, MIT License). See THIRD_PARTY_NOTICES.md.
enum ProseQuality {
    struct Hit { let text: String; let replacements: [String] }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    // MARK: Wordy phrases

    static let wordy: [(pattern: String, replacements: [String])] = [
        ("at the end of the day", ["ultimately", "finally"]), ("in order to", ["to"]), ("due to the fact that", ["because"]),
        ("in the event that", ["if"]), ("in spite of the fact that", ["although", "despite"]), ("the reason why is that", ["because"]),
        ("on a daily basis", ["daily"]), ("on a weekly basis", ["weekly"]), ("on a monthly basis", ["monthly"]),
        ("by means of", ["by", "via"]), ("in the vicinity of", ["near", "about"]), ("until such time as", ["until"]),
        ("all things considered", ["overall"]), ("the bottom line is that", ["essentially"]), ("in a nutshell", ["briefly", "in short"]),
        ("as a matter of fact", ["in fact"]), ("the fact of the matter is", ["the truth is"]), ("it goes without saying", ["clearly"]),
        ("last but not least", ["finally"]), ("but at the same time", ["however", "yet"]), ("each and every", ["each", "every"]),
        ("first and foremost", ["first"]), ("at this point in time", ["now"]), ("for the purpose of", ["for", "to"]),
        ("with regard to", ["about"]), ("in the near future", ["soon"]), ("a large number of", ["many"]), ("has the ability to", ["can"]),
        ("is able to", ["can"]), ("in my opinion", [""]), ("needless to say", [""]),
    ]

    static func wordyHits(in text: String) -> [Hit] {
        var out: [Hit] = []
        for entry in wordy {
            for m in matches("\\b" + NSRegularExpression.escapedPattern(for: entry.pattern) + "\\b", in: text) {
                out.append(Hit(text: m, replacements: entry.replacements))
            }
        }
        return out
    }

    // MARK: Passive voice

    private static let aux = "am|is|are|was|were|be|been|being"
    private static let irregular = ["built", "made", "written", "taken", "broken", "given", "driven", "known", "shown", "spoken", "bought", "caught",
        "taught", "thought", "brought", "kept", "left", "sent", "lost", "met", "said", "seen", "told", "understood", "won", "begun", "chosen",
        "drawn", "eaten", "fallen", "forgotten", "frozen", "grown", "hidden", "held", "led", "meant", "stolen", "found", "spent", "sold"]

    /// Passive constructions, skipping "is excited about"-style adjectives that only look passive.
    static func passiveHits(in text: String) -> [String] {
        let pattern = "\\b(\(aux))\\s+(\\w+ed|\(irregular.joined(separator: "|")))\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        var out: [String] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let after = ns.substring(from: m.range.location + m.range.length)
            let before = ns.substring(with: NSRange(location: max(0, m.range.location - 15), length: min(15, m.range.location)))
            let compound = before.range(of: "\\b(being|been)\\s+$", options: [.regularExpression, .caseInsensitive]) != nil
            let agent = after.range(of: "^\\s+by\\s+[a-z]+", options: [.regularExpression, .caseInsensitive]) != nil
            let stative = after.range(of: "^\\s+(about|in|with|at|of|for|to)\\b", options: [.regularExpression, .caseInsensitive]) != nil
            if stative && !compound && !agent { continue }
            out.append(ns.substring(with: m.range))
        }
        return out
    }

    // MARK: Repeated openers

    /// Three or more consecutive sentences that start with the same word.
    static func repeatedOpener(in text: String) -> String? {
        let sentences = text.split(whereSeparator: { ".!?".contains($0) }).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard sentences.count >= 3 else { return nil }
        let firsts = sentences.map { s in (s.split(separator: " ").first.map(String.init) ?? "").filter { $0.isLetter }.lowercased() }
        for i in 0...(firsts.count - 3) where !firsts[i].isEmpty && firsts[i] == firsts[i + 1] && firsts[i] == firsts[i + 2] {
            return sentences[i].split(separator: " ").first.map(String.init)
        }
        return nil
    }

    // MARK: Readability (Flesch-Kincaid)

    private static func syllables(_ word: String) -> Int {
        let w = word.lowercased().filter { $0.isLetter && $0.isASCII }
        if w.count <= 3 { return w.isEmpty ? 0 : 1 }
        var count = 0, prevVowel = false
        for ch in w { let v = "aeiouy".contains(ch); if v && !prevVowel { count += 1 }; prevVowel = v }
        if w.hasSuffix("e") && !w.hasSuffix("le") && count > 1 { count -= 1 }
        return max(1, count)
    }

    struct Readability { let words: Int; let grade: Double?; let gradeLabel: String; let readSeconds: Int }

    static func readability(_ text: String) -> Readability {
        let words = text.split { $0.isWhitespace }
        guard !words.isEmpty else { return Readability(words: 0, grade: nil, gradeLabel: "-", readSeconds: 0) }
        let sentences = max(1, text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count)
        let syl = words.reduce(0) { $0 + syllables(String($1)) }
        let grade = 0.39 * Double(words.count) / Double(sentences) + 11.8 * Double(syl) / Double(words.count) - 15.59
        let label = grade <= 12 ? "Grade \(max(1, Int(grade.rounded())))" : (grade <= 16 ? "College" : "Graduate")
        return Readability(words: words.count, grade: grade, gradeLabel: label, readSeconds: Int((Double(words.count) / 250 * 60).rounded()))
    }

    static func clock(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
