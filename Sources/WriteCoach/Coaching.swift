import SwiftUI
import Foundation

// MARK: - Styles

/// The five rewrite styles, in ⌘1–⌘5 order. Polish is the default: clear and natural, still in the writer's voice.
enum WritingStyle: CaseIterable, Identifiable, Codable, RawRepresentable, Hashable {
    case fixOnly, polish, shorter, friendly, professional
    var id: String { rawValue }
    var rawValue: String {
        switch self {
        case .fixOnly: return "Fix only"
        case .polish: return "Polish"
        case .shorter: return "Shorter"
        case .friendly: return "Friendly"
        case .professional: return "Professional"
        }
    }
    /// Accepts names saved by older versions ("Concise" became "Shorter").
    init?(rawValue: String) {
        switch rawValue {
        case "Fix only": self = .fixOnly
        case "Polish": self = .polish
        case "Shorter", "Concise": self = .shorter
        case "Friendly": self = .friendly
        case "Professional": self = .professional
        default: return nil
        }
    }
    var title: String { rawValue }
    /// Goal sent to the online coach (worker/coach.js).
    var onlineGoal: String {
        switch self {
        case .fixOnly: return "fixOnly"
        case .polish: return "sameTone"
        case .shorter: return "shorter"
        case .friendly: return "friendly"
        case .professional: return "formal"
        }
    }
    /// Light styles must not change meaning, slang or harmless wording, so the meaning guard checks every change.
    var guarded: Bool { self == .fixOnly || self == .polish }
    var icon: String {
        switch self {
        case .fixOnly: return "checkmark.seal"
        case .polish: return "wand.and.stars"
        case .professional: return "briefcase"
        case .friendly: return "face.smiling"
        case .shorter: return "scissors"
        }
    }
    var blurb: String {
        switch self {
        case .fixOnly: return "Only real mistakes. Your words and tone stay."
        case .polish: return "Clear and natural, still sounds like you."
        case .professional: return "Polite and clear for work email."
        case .friendly: return "Warm and casual for chat."
        case .shorter: return "Shorter, same meaning."
        }
    }
    var instruction: String {
        switch self {
        case .fixOnly:
            return "Fix only real mistakes: spelling, grammar, verb forms, articles, punctuation and capitalization. Do not rephrase, reorder or replace words that are already correct, and do not change the tone (keep casual words like 'kinda', 'hey', 'asap'). If nothing is wrong, return the text unchanged."
        case .polish:
            return "Fix mistakes and make it read clearly and naturally, like a fluent native speaker wrote it. Keep the user's meaning, voice and roughly the same length. Do not add new ideas."
        case .professional:
            return "Rewrite it as a clear, polite, professional message. Keep the meaning and every fact. Do not add greetings, sign-offs or ideas that were not there."
        case .friendly:
            return "Rewrite it in a warm, friendly, casual tone suitable for chat. Keep the meaning and every fact. Do not add emojis or new ideas."
        case .shorter:
            return "Make it shorter and more direct while keeping every fact and the user's tone. Remove filler words and redundancy. Do not add new ideas."
        }
    }
}

// MARK: - Changes

enum MistakeCategory: String, Codable, CaseIterable, Identifiable {
    case spelling, grammar, verbForm = "verb form", wordChoice = "word choice", punctuation, capitalization, clarity, tone
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var color: Color {
        switch self {
        case .spelling: return .removed
        case .grammar, .verbForm: return .teach
        case .wordChoice: return .orange
        case .punctuation, .capitalization: return .blue
        case .clarity, .tone: return .brand
        }
    }
    var icon: String {
        switch self {
        case .spelling: return "textformat.abc"
        case .grammar: return "text.book.closed"
        case .verbForm: return "clock.arrow.2.circlepath"
        case .wordChoice: return "character.cursor.ibeam"
        case .punctuation: return "ellipsis"
        case .capitalization: return "textformat.size"
        case .clarity: return "eye"
        case .tone: return "theatermasks"
        }
    }
    /// Short, generic fallback reason when the model can't explain a change.
    var fallbackReason: String {
        switch self {
        case .spelling: return "That spelling isn't a real word. Sound it out, then check the vowels."
        case .capitalization: return "Start a sentence, and a name, with a capital letter."
        case .punctuation: return "The punctuation should match where the sentence actually pauses."
        case .grammar: return "The verb has to match who is doing the action."
        case .verbForm: return "The time of the sentence (now, past, or still going) picks the verb form."
        case .wordChoice: return "Pick the word a person would actually say here, not the closest dictionary word."
        case .clarity: return "Say the point in the order a reader meets it. Cut the words that repeat it."
        case .tone: return "Match the tone to who will read this. Formal when it matters, plain when it doesn't."
        }
    }

    /// What to look for before the answer is shown.
    var coachHint: String {
        switch self {
        case .spelling: return "One of these isn't a real spelling."
        case .capitalization: return "Look at what should start with a capital."
        case .punctuation: return "Look at where the sentence should pause."
        case .grammar: return "Check that the verb matches the person doing it."
        case .verbForm: return "Check the time: now, finished, or still going."
        case .wordChoice: return "One version is what people actually say."
        case .clarity: return "One version gets to the point with less leftover wording."
        case .tone: return "One version fits the person you're writing to."
        }
    }
}

struct Change: Codable, Identifiable, Equatable {
    var id = UUID()
    var from: String
    var to: String
    var category: MistakeCategory
    var reason: String
    var accepted = true
    /// True while the model hasn't explained it yet.
    var pending = false
    /// Position of `from` in the original text, in UTF-16 units (what Accessibility APIs use).
    var location: Int?
    var length: Int?
    /// "error" (a real mistake) or "style" (optional improvement). Optional so older history decodes.
    var kind: String?
    /// "word", "phrase", "sentence" or "message".
    var level: String?
    /// Short name of the rule, e.g. "Repeated phrase".
    var label: String?
    /// A way to remember the rule, and a fresh sentence pair to practise it on (from the rule book).
    var tip: String?
    var practiceWrong: String?
    var practiceRight: String?

    /// Fills in the teaching for this change from the built-in rule book. `location` must be relative to `original`.
    mutating func teach(original: String, location: Int?) {
        let rule = RuleBook.match(from: from, to: to, original: original, location: location)
        if let rule {
            // Mechanical fixes (a typo, a capital) keep their exact local wording unless the rule is more specific.
            let mechanical = [.spelling, .capitalization, .punctuation].contains(category) && !pending
            if !mechanical || rule.tip != nil { reason = rule.why; label = rule.label; category = rule.category }
            kind = rule.kind; tip = rule.tip; practiceWrong = rule.wrong; practiceRight = rule.right
        }
        if reason.isEmpty { reason = to.isEmpty ? "The sentence is complete without “\(from)”." : from.isEmpty ? "“\(to)” was missing here." : category.fallbackReason }
        if kind == nil {
            let words = max(from.split(separator: " ").count, to.split(separator: " ").count)
            kind = (words > 3 || [.clarity, .tone, .wordChoice].contains(category)) ? "style" : "error"
            if [.spelling, .capitalization, .punctuation].contains(category) { kind = "error" }
        }
        if label == nil { label = to.isEmpty ? "Extra words" : from.isEmpty ? "Missing word" : category.title }
        pending = false
    }

    var isError: Bool {
        if let kind { return kind == "error" }
        // Until the model explains it: small edits read as mistakes, rephrasing as style.
        let words = max(from.split(separator: " ").count, to.split(separator: " ").count)
        return words <= 2 && [.spelling, .grammar, .verbForm, .punctuation, .capitalization].contains(category)
    }
    /// Level from the model, else from the size of the edit.
    var learnLevel: LearnLevel {
        if let level, let l = LearnLevel(rawValue: level) { return l }
        let words = max(from.split(separator: " ").count, to.split(separator: " ").count)
        return words <= 1 ? .word : words <= 4 ? .phrase : .sentence
    }
}

enum LearnLevel: String, CaseIterable, Identifiable, Codable {
    case word, phrase, sentence, message
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Original text split into unchanged runs and numbered changes, so each change can be accepted or undone.
struct ChangeSet {
    enum Segment { case same(String), change(Int) }
    var segments: [Segment] = []
    var changes: [Change] = []
    /// Raw text (with whitespace) of each change, used to rebuild the result.
    private var rawFrom: [String] = []
    private var rawTo: [String] = []

    init() {}

    init(original: String, rewrite: String) {
        var removed = "", added = ""
        var removedTokens: [String] = [], addedTokens: [String] = []
        var cursor = 0                 // UTF-16 offset in the original text
        var runStart = 0               // where the current change run began
        func addChange(_ r: String, _ a: String, at start: Int) {
            let index = changes.count
            let from = r.trimmingCharacters(in: .whitespacesAndNewlines)
            let to = a.trimmingCharacters(in: .whitespacesAndNewlines)
            let category = ChangeSet.guessCategory(from: from, to: to)
            let leading = r.prefix { $0.isWhitespace }.utf16.count
            var change = Change(from: from, to: to, category: category ?? .grammar,
                                reason: category.map { ChangeSet.localReason(from: from, to: to, category: $0) } ?? "", pending: category == nil)
            change.location = start + leading
            change.length = from.utf16.count
            changes.append(change)
            rawFrom.append(r); rawTo.append(a)
            segments.append(.change(index))
        }
        func flush() {
            defer { removed = ""; added = ""; removedTokens = []; addedTokens = [] }
            guard !removed.isEmpty || !added.isEmpty else { return }
            // Same number of words on both sides ("shoud of went their" → "should have gone there"):
            // pair them up so each word is its own reviewable, separately categorised change.
            if removedTokens.count == addedTokens.count, removedTokens.count > 1,
               zip(removedTokens, addedTokens).allSatisfy({ ChangeSet.related($0, $1) }) {
                var pos = runStart
                for (r, a) in zip(removedTokens, addedTokens) {
                    if r.trimmingCharacters(in: .whitespacesAndNewlines) == a.trimmingCharacters(in: .whitespacesAndNewlines) { segments.append(.same(a)) }
                    else { addChange(r, a, at: pos) }
                    pos += r.utf16.count
                }
                return
            }
            addChange(removed, added, at: runStart)
        }
        for piece in WordDiff.diff(original, rewrite) {
            switch piece.kind {
            case .same:
                flush()
                let oldText = piece.old ?? piece.text
                if oldText.trimmingCharacters(in: .whitespacesAndNewlines) != piece.text.trimmingCharacters(in: .whitespacesAndNewlines) {
                    addChange(oldText, piece.text, at: cursor)   // e.g. "urgent" → "urgent,": reviewable like any other change
                } else {
                    segments.append(.same(piece.text))
                }
                cursor += oldText.utf16.count
                runStart = cursor
            case .removed:
                if removed.isEmpty && added.isEmpty { runStart = cursor }
                removed += piece.text; removedTokens.append(piece.text); cursor += piece.text.utf16.count
            case .added:
                if removed.isEmpty && added.isEmpty { runStart = cursor }
                added += piece.text; addedTokens.append(piece.text)
            }
        }
        flush()
    }

    /// Two words that are versions of each other ("goes"/"go", "thier"/"their", "its"/"it's"). Unrelated words
    /// that merely sit in the same position ("to" and "affect") are not paired; the phrase stays one change.
    static func related(_ a: String, _ b: String) -> Bool {
        let strip: (String) -> String = { String($0.lowercased().filter { $0.isLetter || $0.isNumber }) }
        let x = strip(a), y = strip(b)
        if x == y { return true }
        guard !x.isEmpty, !y.isEmpty else { return false }
        if min(x.count, y.count) >= 2, x.hasPrefix(y) || y.hasPrefix(x) { return true }
        if grammarPairs.contains(x + ">" + y) || grammarPairs.contains(y + ">" + x) { return true }
        return min(x.count, y.count) >= 3 && levenshtein(x, y) <= max(1, min(x.count, y.count) / 2)
    }
    private static let grammarPairs: Set<String> = ["is>are", "was>were", "has>have", "do>does", "a>an", "me>i", "him>he", "her>she", "them>they", "us>we",
                                                    "of>have", "to>too", "in>on", "in>at", "on>at", "this>these", "that>those", "much>many", "less>fewer",
                                                    "say>tell", "said>told", "good>well", "who>whom", "lie>lay", "can>could", "will>would", "am>is", "am>are",
                                                    "should>shoud", "your>you're", "there>their", "then>than", "affect>effect", "loose>lose",
                                                    // Irregular past tense / participle ("should of went" → "should have gone").
                                                    "went>gone", "saw>seen", "did>done", "came>come", "ran>run", "ate>eaten", "wrote>written",
                                                    "took>taken", "gave>given", "began>begun", "drank>drunk", "swam>swum", "threw>thrown",
                                                    "knew>known", "broke>broken", "spoke>spoken", "chose>chosen", "flew>flown", "grew>grown",
                                                    "got>gotten", "forgot>forgotten", "drove>driven", "rode>ridden", "sang>sung", "rang>rung"]

    /// The text with only the accepted changes applied.
    func text(accepted: Set<UUID>, overrides: [UUID: String] = [:]) -> String {
        segments.map { seg -> String in
            switch seg {
            case .same(let s): return s
            case .change(let i):
                let useNew = accepted.contains(changes[i].id)
                var piece = useNew ? rawTo[i] : rawFrom[i]
                if useNew, let word = overrides[changes[i].id] { piece = word }
                // Keep a separating space when the replacement lost the original's trailing whitespace.
                let other = useNew ? rawFrom[i] : rawTo[i]
                if !piece.isEmpty, piece.last?.isWhitespace != true, other.last?.isWhitespace == true { piece += " " }
                return piece
            }
        }.joined()
    }

    private static let alphanumerics = CharacterSet.letters.union(.decimalDigits)

    /// Cheap, reliable categories for mechanical edits; nil means "ask the model".
    static func guessCategory(from: String, to: String) -> MistakeCategory? {
        if from.isEmpty || to.isEmpty {
            let word = (from + to).trimmingCharacters(in: .punctuationCharacters)
            return word.isEmpty ? .punctuation : nil
        }
        if from.lowercased() == to.lowercased() { return .capitalization }
        if let right = TextSafety.commonTypos[from.trimmingCharacters(in: .punctuationCharacters).lowercased()],
           right == to.trimmingCharacters(in: .punctuationCharacters).lowercased() { return .spelling }   // "teh" → "the"
        // Contractions: "dont" → "don't", "its" → "it's".
        if from.replacingOccurrences(of: "'", with: "").lowercased() == to.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "").lowercased(),
           from.contains("'") != (to.contains("'") || to.contains("’")) { return .spelling }
        let strip: (String) -> String = { String(String.UnicodeScalarView($0.unicodeScalars.filter { alphanumerics.contains($0) })) }
        if strip(from).lowercased() == strip(to).lowercased() {
            return strip(from) == strip(to) ? .punctuation : (from.contains("'") || to.contains("'") ? .spelling : .capitalization)
        }
        let a = strip(from).lowercased(), b = strip(to).lowercased()
        let singleWord = !from.contains(" ") && !to.contains(" ")
        // Typos: same-length-ish words of 4+ letters a couple of edits apart ("thung" → "thing"). Short words
        // like "Me" → "He" are usually grammar, so the model decides those.
        if singleWord, min(a.count, b.count) >= 4, levenshtein(a, b) <= max(1, min(a.count, b.count) / 3) { return .spelling }
        return nil
    }

    /// Exact, template reasons for mechanical edits; these are more reliable than a small model's wording.
    static func localReason(from: String, to: String, category: MistakeCategory) -> String {
        let f = from.trimmingCharacters(in: .punctuationCharacters), t = to.trimmingCharacters(in: .punctuationCharacters)
        switch category {
        case .spelling:
            if t.contains("'") || t.contains("’") { return "“\(t)” needs an apostrophe: it is short for two words." }
            return "“\(f)” is misspelled; the word is spelled “\(t)”."
        case .capitalization:
            if t == "I" { return "The pronoun “I” is always a capital letter." }
            if let prevEnd = to.first, prevEnd.isUppercase, f.lowercased() == t.lowercased() {
                return t.count > 1 && t == t.uppercased() ? "Abbreviations like “\(t)” are written in capitals." : "Start a sentence or a name with a capital letter."
            }
            return "Capital letter fix."
        case .punctuation:
            if to.hasSuffix(".") && !from.hasSuffix(".") { return "End the sentence with a full stop." }
            if to.hasSuffix(",") && !from.hasSuffix(",") { return "A comma separates these parts of the sentence." }
            if to.hasSuffix("?") { return "A question ends with a question mark." }
            return "Punctuation fix."
        default:
            return category.fallbackReason
        }
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }; guard !b.isEmpty else { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count { cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)) }
            prev = cur
        }
        return prev[b.count]
    }
}

// MARK: - Spaced review of the user's own mistakes

struct ReviewItem: Codable, Identifiable {
    var id = UUID()
    let created: Date
    /// The sentence as the user originally wrote it.
    let sentence: String
    /// The corrected sentence.
    let corrected: String
    let from: String
    let to: String
    let category: MistakeCategory
    let reason: String
    var due: Date
    var step = 0
    var correctCount = 0
    var attempts = 0

    static let intervalsDays: [Double] = [1, 3, 7, 16, 35, 90]

    mutating func record(correct: Bool) {
        attempts += 1
        if correct {
            correctCount += 1
            due = Date().addingTimeInterval(Self.intervalsDays[min(step, Self.intervalsDays.count - 1)] * 86_400)
            step += 1
        } else {
            step = 0
            due = Date().addingTimeInterval(10 * 60)   // try again in 10 minutes
        }
    }

    var mastered: Bool { step >= 3 }

    static func loadAll() -> [ReviewItem] {
        guard let data = UserDefaults.standard.data(forKey: "heyhumanly.reviews"),
              let items = try? JSONDecoder().decode([ReviewItem].self, from: data) else { return [] }
        return items
    }
    static func saveAll(_ items: [ReviewItem]) {
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "heyhumanly.reviews") }
    }

    /// Normalises for answer checking: case, curly quotes and spacing don't matter; words and punctuation do.
    static func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
            .lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
    }

    /// Correct when the answer contains the fix and no longer contains the mistake.
    func check(_ answer: String) -> Bool {
        let a = Self.normalize(answer)
        if a == Self.normalize(corrected) { return true }
        let fixed = Self.normalize(to), wrong = Self.normalize(from)
        let hasFix = fixed.isEmpty || a.contains(fixed)
        let stillWrong = !wrong.isEmpty && wrong != fixed && Self.containsWord(a, wrong)
        return hasFix && !stillWrong
    }

    private static func containsWord(_ text: String, _ phrase: String) -> Bool {
        (" " + text + " ").contains(" " + phrase + " ")
    }
}

// MARK: - Insights (computed only from the user's own sessions)

struct CategoryStat: Identifiable {
    let category: MistakeCategory
    let count: Int
    let lastWeek: Int
    let thisWeek: Int
    let examples: [Change]
    var id: String { category.rawValue }
}

enum Insights {
    static func stats(history: [HistoryItem]) -> [CategoryStat] {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: now)!
        var buckets: [MistakeCategory: (Int, Int, Int, [Change])] = [:]
        for item in history {
            for change in item.changes ?? [] where !change.pending {
                var b = buckets[change.category] ?? (0, 0, 0, [])
                b.0 += 1
                if item.date >= weekAgo { b.2 += 1 } else if item.date >= twoWeeksAgo { b.1 += 1 }
                if b.3.count < 3, !b.3.contains(where: { $0.from == change.from && $0.to == change.to }) { b.3.append(change) }
                buckets[change.category] = b
            }
        }
        return buckets.map { CategoryStat(category: $0.key, count: $0.value.0, lastWeek: $0.value.1, thisWeek: $0.value.2, examples: $0.value.3) }
            .sorted { $0.count > $1.count }
    }

    /// Mistakes per 100 words written, for a date range. nil when there's too little writing to be meaningful.
    static func rate(history: [HistoryItem], from: Date, to: Date) -> Double? {
        let items = history.filter { $0.date >= from && $0.date < to && $0.changes != nil }
        let words = items.reduce(0) { $0 + $1.original.split(whereSeparator: \.isWhitespace).count }
        guard words >= 40 else { return nil }
        let mistakes = items.reduce(0) { $0 + ($1.changes?.count ?? 0) }
        return Double(mistakes) / Double(words) * 100
    }
}
