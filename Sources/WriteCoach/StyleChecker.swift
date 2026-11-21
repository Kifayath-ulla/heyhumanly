import SwiftUI
import Foundation

/// Writing-quality suggestions beyond corrections ("make it better"), from deterministic rules
/// ported from MIT-licensed checkers (retext-simplify, write-good family) plus a repetition detector.
enum StyleKind: String, Codable, CaseIterable, Identifiable {
    case repetition, doubledWord, passive, longSentence, wordy, cliche, weasel, filler
    var id: String { rawValue }

    var title: String {
        switch self {
        case .repetition: return "Repeated phrase"
        case .doubledWord: return "Doubled word"
        case .passive: return "Passive voice"
        case .longSentence: return "Long sentence"
        case .wordy: return "Wordy"
        case .cliche: return "Cliché"
        case .weasel: return "Vague intensifier"
        case .filler: return "Filler word"
        }
    }
    var icon: String {
        switch self {
        case .repetition: return "arrow.triangle.2.circlepath"
        case .doubledWord: return "textformat.alt"
        case .passive: return "arrow.uturn.left.circle"
        case .longSentence: return "text.alignleft"
        case .wordy: return "scissors"
        case .cliche: return "quote.bubble"
        case .weasel: return "waveform.path.ecg"
        case .filler: return "bubble.left"
        }
    }
    var color: Color { .teach }

    /// One-paragraph lesson shown when the user taps "Why?". Written once, so it is always correct.
    var lesson: String {
        switch self {
        case .repetition: return "Saying the same phrase twice in a row makes writing sound unsure and wastes the reader's time. Say it once, then add what's new."
        case .doubledWord: return "The same word twice in a row (\"the the\") is easy to miss when you reread, because the brain skips it."
        case .passive: return "Passive voice hides who did the action (\"the report was sent\"). Active voice is clearer and shorter: say who did it (\"I sent the report\")."
        case .longSentence: return "Sentences over about 25–30 words are hard to follow. Split at the natural break, usually a comma before \"and\", \"but\" or \"so\"."
        case .wordy: return "A shorter, plainer phrase says the same thing faster. Readers skim; every extra word is a chance to lose them."
        case .cliche: return "Clichés are phrases readers have seen so often they skip them. Say the specific thing you mean."
        case .weasel: return "Words like \"very\", \"quite\" and \"extremely\" add emphasis without information. Use a stronger word or a concrete detail."
        case .filler: return "Fillers like \"basically\", \"literally\" and \"just\" are fine in speech but make writing sound less sure. Most sentences read better without them."
        }
    }
    var example: (before: String, after: String) {
        switch self {
        case .repetition: return ("I don't know, I don't know what to do.", "I don't know what to do.")
        case .doubledWord: return ("Send the the file.", "Send the file.")
        case .passive: return ("The mistake was made by our team.", "Our team made the mistake.")
        case .longSentence: return ("We met on Monday and talked about the launch and the budget and then agreed to move the date.", "We met on Monday to discuss the launch and budget. We agreed to move the date.")
        case .wordy: return ("In order to finish, we need to…", "To finish, we need to…")
        case .cliche: return ("At the end of the day, it works.", "In the end, it works.")
        case .weasel: return ("It was very good.", "It was excellent.")
        case .filler: return ("I basically just need the file.", "I need the file.")
        }
    }
    /// Kinds that need a sentence-level rewrite rather than a word swap.
    var needsRewrite: Bool { [.repetition, .passive, .longSentence, .cliche].contains(self) }
}

struct StyleFinding: Identifiable, Equatable {
    let id = UUID()
    let kind: StyleKind
    /// Range of the flagged words in the checked text (UTF-16).
    var location: Int
    var length: Int
    let matched: String
    let message: String
    /// Word-level replacements; empty means a sentence rewrite is offered instead.
    let replacements: [String]
    /// The sentence the finding is in (UTF-16 range), used for rewrites.
    var sentenceLocation: Int
    var sentenceLength: Int
    /// A deterministic edit (range in the checked text + replacement) when one is known to be right.
    var quickEdit: (location: Int, length: Int, text: String)? = nil
    static func == (a: StyleFinding, b: StyleFinding) -> Bool { a.id == b.id }
}

enum StyleChecker {
    static let extraCliches = ["at the end of the day", "circle back", "touch base", "low-hanging fruit", "move the needle",
                               "think outside the box", "it is what it is", "going forward", "deep dive", "game changer"]
    static let fillers = ["basically", "literally", "actually", "honestly", "totally", "kinda", "sort of", "i mean", "just"]

    static func check(_ text: String, style: WritingStyle = .fixOnly, limit: Int = 6) -> [StyleFinding] {
        let ns = text as NSString
        let sentences = sentenceRanges(ns)
        func sentence(for loc: Int) -> NSRange {
            sentences.first { NSLocationInRange(loc, $0) } ?? NSRange(location: 0, length: ns.length)
        }
        var out: [StyleFinding] = []
        let code = TextSafety.codeRanges(ns)
        func add(_ kind: StyleKind, _ r: NSRange, _ message: String, _ replacements: [String] = []) {
            guard r.location != NSNotFound, r.length > 0 else { return }
            if code.contains(where: { NSIntersectionRange($0, r).length > 0 }) { return }   // code in backticks is not prose
            // One finding per span; earlier (higher-priority) rules win.
            if out.contains(where: { NSIntersectionRange(NSRange(location: $0.location, length: $0.length), r).length > 0 }) { return }
            let s = sentence(for: r.location)
            out.append(StyleFinding(kind: kind, location: r.location, length: r.length, matched: ns.substring(with: r), message: message,
                                    replacements: replacements, sentenceLocation: s.location, sentenceLength: s.length))
        }
        let words = wordRanges(ns)

        // 1. Doubled word: "the the" (write-good lexical illusions).
        for i in 1..<max(1, words.count) where i < words.count {
            let a = ns.substring(with: words[i - 1]).lowercased(), b = ns.substring(with: words[i]).lowercased()
            if a == b, a.rangeOfCharacter(from: .letters) != nil, !["had", "that"].contains(a) {
                add(.doubledWord, NSRange(location: words[i - 1].location, length: NSMaxRange(words[i]) - words[i - 1].location),
                    "“\(a) \(a)”: the word is doubled.", [ns.substring(with: words[i - 1])])
            }
        }

        // 2. Repeated phrase within ~30 words: "I don't know …, I don't know …".
        let lower = words.map { ns.substring(with: $0).lowercased().trimmingCharacters(in: .punctuationCharacters) }
        let stop: Set<String> = ["the", "a", "an", "and", "to", "of", "in", "on", "it", "is", "i", "you", "we", "that", "for", "at", "be", "but", "or", "so", "with"]
        var reported = Set<String>()
        outer: for n in stride(from: 5, through: 2, by: -1) where words.count >= n * 2 {
            for i in 0...(words.count - n) {
                let gram = lower[i..<(i + n)]
                if gram.allSatisfy({ stop.contains($0) }) { continue }
                let key = gram.joined(separator: " ")
                guard !reported.contains(where: { $0.contains(key) }) else { continue }
                let j0 = i + n
                guard j0 <= words.count - n else { continue }
                for j in j0...min(words.count - n, i + 30) where Array(lower[j..<(j + n)]) == Array(gram) {
                    let r = NSRange(location: words[j].location, length: NSMaxRange(words[j + n - 1]) - words[j].location)
                    add(.repetition, r, "You say “\(ns.substring(with: r))” twice. Say it once.")
                    // Keep the second (usually complete) occurrence: drop everything from the first one up to it.
                    if let last = out.indices.last, out[last].kind == .repetition, out[last].location == r.location {
                        let start = words[i].location
                        out[last].quickEdit = (start, words[j].location - start, "")
                    }
                    reported.insert(key)
                    continue outer
                }
            }
        }

        // 3. Passive voice (passive-voice rules: form of "be" + past participle).
        let participles = StyleRulesData.irregularParticiples.joined(separator: "|")
        regexMatches(#"\b(am|are|were|being|is|been|was|be)\s+(\w+ed|"# + participles + #")\b"#, in: text).forEach {
            add(.passive, $0, "Passive voice: “\(ns.substring(with: $0))”. Say who did it.")
        }

        // 4. Long sentences.
        for s in sentences {
            let count = ns.substring(with: s).split(whereSeparator: \.isWhitespace).count
            if count > 30 { add(.longSentence, s, "This sentence is \(count) words. Try splitting it.") }
        }

        // 5. Wordy / plainer phrases (retext-simplify). Single formal words only when the style aims for clarity.
        let allowSingle = style != .fixOnly && style != .friendly
        for (phrase, alt) in StyleRulesData.simplify where phrase.contains(" ") || (allowSingle && phrase.count >= 8) {
            regexMatches(#"\b"# + NSRegularExpression.escapedPattern(for: phrase) + #"\b"#, in: text).forEach {
                let options = alt.replace.prefix(2).map { "“\($0)”" }.joined(separator: " or ")
                add(.wordy, $0, "“\(ns.substring(with: $0))” can be shorter: \(options)\(alt.omit ? ", or remove it" : "").", Array(alt.replace.prefix(3)))
            }
        }

        // 6. Clichés (no-cliches, plus common workplace ones).
        for phrase in StyleRulesData.cliches + extraCliches {
            regexMatches(#"\b"# + NSRegularExpression.escapedPattern(for: phrase) + #"\b"#, in: text).forEach {
                add(.cliche, $0, "“\(ns.substring(with: $0))” is a cliché. Say exactly what you mean.")
            }
        }

        // 7. Vague intensifiers (weasel-words) — not in casual chat styles.
        if style != .friendly {
            for w in StyleRulesData.weasel {
                regexMatches(#"\b"# + w + #"\b"#, in: text).forEach {
                    add(.weasel, $0, "“\(ns.substring(with: $0))” adds emphasis but no information.", [""])
                }
            }
        }

        // 8. Fillers.
        for w in fillers {
            regexMatches(#"\b"# + NSRegularExpression.escapedPattern(for: w) + #"\b"#, in: text).forEach {
                add(.filler, $0, "“\(ns.substring(with: $0))” is a filler. The sentence works without it.", [""])
            }
        }

        let order = StyleKind.allCases
        return Array(out.sorted { (order.firstIndex(of: $0.kind)!, $0.location) < (order.firstIndex(of: $1.kind)!, $1.location) }.prefix(limit))
    }

    static func sentenceRanges(_ ns: NSString) -> [NSRange] {
        var out: [NSRange] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .bySentences) { _, range, _, _ in out.append(range) }
        return out
    }

    static func wordRanges(_ ns: NSString) -> [NSRange] {
        var out: [NSRange] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { _, range, _, _ in out.append(range) }
        return out
    }

    private static func regexMatches(_ pattern: String, in text: String) -> [NSRange] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }

    /// Applies a word-level replacement (empty string removes the words and tidies spaces).
    static func apply(_ finding: StyleFinding, replacement: String, to text: String) -> String {
        let ns = text as NSString
        var result = ns.replacingCharacters(in: NSRange(location: finding.location, length: finding.length), with: replacement)
        while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
        return result.replacingOccurrences(of: " ,", with: ",").replacingOccurrences(of: " .", with: ".")
    }

    /// Drops an immediate repeated phrase ("I don't know, I don't know" → "I don't know").
    /// Only back-to-back copies, so "I don't know what I don't know" stays.
    static func collapseRepetitions(_ text: String) -> String {
        let ns = text as NSString
        let words = wordRanges(ns)
        guard words.count >= 2 else { return text }
        let lower = words.map { ns.substring(with: $0).lowercased() }
        let keepDoubled: Set<String> = ["had", "that"]
        var cuts: [NSRange] = []
        var i = 0
        while i < words.count {
            var jumped = false
            let maxN = min(6, (words.count - i) / 2)
            if maxN >= 1 {
                for n in stride(from: maxN, through: 1, by: -1) {
                    let bStart = i + n
                    guard bStart + n <= words.count else { continue }
                    let a = Array(lower[i..<(i + n)])
                    let b = Array(lower[bStart..<(bStart + n)])
                    guard a == b else { continue }
                    if n == 1 && keepDoubled.contains(a[0]) { continue }
                    if a.allSatisfy({ $0.count < 2 }) { continue }
                    let gapStart = NSMaxRange(words[i + n - 1])
                    let gapEnd = words[bStart].location
                    guard gapEnd >= gapStart else { continue }
                    let gap = ns.substring(with: NSRange(location: gapStart, length: gapEnd - gapStart))
                    if gap.contains(where: { $0.isLetter || $0.isNumber }) || gap.count > 6 { continue }
                    cuts.append(NSRange(location: words[i].location, length: words[bStart].location - words[i].location))
                    i = bStart + n
                    jumped = true
                    break
                }
            }
            if !jumped { i += 1 }
        }
        guard !cuts.isEmpty else { return text }
        var s = text as NSString
        for cut in cuts.reversed() where cut.location + cut.length <= s.length {
            s = s.replacingCharacters(in: cut, with: "") as NSString
        }
        var out = s as String
        while out.contains("  ") { out = out.replacingOccurrences(of: "  ", with: " ") }
        out = out.replacingOccurrences(of: ", ,", with: ", ")
        out = out.replacingOccurrences(of: ",,", with: ",")
        out = out.replacingOccurrences(of: " ,", with: ",")
        out = out.replacingOccurrences(of: " .", with: ".")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CoachService {
    /// Rewrites one sentence to fix a style issue, keeping the writer's voice and language mix.
    /// Results that still contain the problem are rejected and retried once.
    static func rewriteSentence(_ sentence: String, issue: StyleFinding, endpoint: String, model: String) async -> String? {
        let task: String
        switch issue.kind {
        case .repetition:
            task = """
            Rewrite the sentence so the phrase "\(issue.matched)" appears only ONCE. Merge the two parts. Do not add words like "again".
            Example: "I'm not sure, I'm not sure if I can come." -> "I'm not sure if I can come."
            """
        case .passive:
            task = """
            Rewrite the sentence in active voice: say who did the action first.
            Example: "The mistake was made by our team." -> "Our team made the mistake."
            """
        case .longSentence:
            task = """
            Split the sentence into two or three shorter sentences at natural breaks. Keep every fact.
            Example: "We met and talked about the plan and then we agreed to wait." -> "We met and talked about the plan. Then we agreed to wait."
            """
        case .cliche:
            task = "Replace the cliché \"\(issue.matched)\" with plain, specific words."
        default:
            task = "Fix this: \(issue.message)"
        }
        for attempt in 0..<2 {
            guard let url = URL(string: endpoint) else { return nil }
            let prompt = """
            \(task)
            Keep the meaning, the writer's tone and any non-English words (for example "kya", "yaar"). Do not add new ideas.
            Reply with ONLY the rewritten text.
            Sentence: \(sentence)
            """
            var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 40
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": false, "think": false, "keep_alive": "30m",
                                                                            "options": ["temperature": 0.2 + 0.4 * Double(attempt), "num_predict": max(60, sentence.count)]])
            struct Outer: Decodable { let response: String }
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let outer = try? JSONDecoder().decode(Outer.self, from: data) else { return nil }
            let cleaned = cleanRewrite(outer.response)
            if !cleaned.isEmpty, cleaned != sentence, !stillHasProblem(cleaned, issue) { return cleaned }
        }
        return nil
    }

    private static func stillHasProblem(_ text: String, _ issue: StyleFinding) -> Bool {
        switch issue.kind {
        case .repetition:
            return text.lowercased().components(separatedBy: issue.matched.lowercased()).count > 2
        case .passive, .cliche:
            return text.lowercased().contains(issue.matched.lowercased())
        default:
            return false
        }
    }
}
