import Foundation

/// What HeyHumanly teaches about one change: the rule in a sentence, a way to remember it,
/// and a fresh sentence to practise the same rule on.
struct CoachRule {
    var label: String
    var category: MistakeCategory
    var kind: String            // "error" or "style"
    var why: String
    var tip: String? = nil
    var wrong: String? = nil    // practice pair: same rule, new sentence
    var right: String? = nil
}

/// Hand-written rules for the mistakes people make most. These are matched on the words that changed
/// and the words around them, so the explanation is exact and available instantly, with no model call.
/// Anything not covered here is explained by the local model, one change at a time.
enum RuleBook {
    static func match(from rawFrom: String, to rawTo: String, original: String, location: Int?) -> CoachRule? {
        let from = words(rawFrom), to = words(rawTo)
        let ns = original as NSString
        var before: [String] = [], after: [String] = []
        if let loc = location, loc >= 0, loc <= ns.length {
            before = Array(words(ns.substring(to: loc)).suffix(4))
            let end = min(ns.length, loc + (rawFrom as NSString).length)
            after = Array(words(ns.substring(from: end)).prefix(3))
        }
        let ctx = Context(from: from, to: to, rawFrom: rawFrom.trimmed, rawTo: rawTo.trimmed, before: before, after: after, sentence: original.lowercased())
        var hits: [CoachRule] = []
        for check in checks { if let r = check(ctx), !hits.contains(where: { $0.label == r.label }) { hits.append(r) } }
        guard var first = hits.first else { return describe(ctx) }
        // Two rules in one change ("effect alot" → "affect a lot"): teach both, briefly.
        if hits.count > 1 { first.why += " " + hits[1].why }
        return first
    }

    struct Context {
        let from: [String], to: [String]
        let rawFrom: String, rawTo: String
        let before: [String], after: [String]
        let sentence: String
        var prev: String { before.last ?? "" }
        var next: String { after.first ?? "" }
        var f: String { from.count == 1 ? from[0] : "" }
        var t: String { to.count == 1 ? to[0] : "" }
    }

    static func words(_ s: String) -> [String] {
        s.lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "'") })
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }.filter { !$0.isEmpty }
    }

    // MARK: Word pairs people mix up

    /// Each group: word → what it does. The explanation contrasts the right word with the one they typed.
    static let confusables: [[String: String]] = [
        ["their": "shows that something belongs to them (their car)", "there": "points to a place, or starts “there is”", "they're": "is short for “they are”"],
        ["its": "shows belonging (the dog wagged its tail)", "it's": "is short for “it is” or “it has”"],
        ["your": "shows belonging (your phone)", "you're": "is short for “you are”"],
        ["whose": "asks or shows who owns something", "who's": "is short for “who is” or “who has”"],
        ["then": "is about time or order (first this, then that)", "than": "compares two things (better than)"],
        ["to": "shows direction, or comes before a verb (to go)", "too": "means “also” or “more than enough”", "two": "is the number 2"],
        ["affect": "is the verb: to change or influence something", "effect": "is the noun: the result of a change"],
        ["lose": "is the verb: to not win, or to no longer have", "loose": "means not tight"],
        ["accept": "means to say yes to something", "except": "means “apart from”"],
        ["advice": "is the noun (some advice)", "advise": "is the verb (I advise you)"],
        ["quiet": "means making little noise", "quite": "means “fairly” or “completely”"],
        ["weather": "is rain, sun and wind", "whether": "introduces a choice (whether or not)"],
        ["were": "is the past of “are”", "we're": "is short for “we are”", "where": "asks about a place"],
        ["hear": "is what your ears do", "here": "means “in this place”"],
        ["know": "is the verb: to have information", "no": "is the opposite of yes", "now": "means at this moment"],
        ["passed": "is the verb: went by, or succeeded (she passed the exam)", "past": "is the time before now, or “beyond” (walk past the shop)"],
        ["break": "means to damage, or a pause", "brake": "is what stops a car"],
        ["piece": "is a part of something", "peace": "is calm, the opposite of war"],
        ["principal": "is the main one, or the head of a school", "principle": "is a rule or belief"],
        ["complement": "completes something", "compliment": "is a kind remark"],
        ["stationary": "means not moving", "stationery": "is paper and pens"],
        ["desert": "is dry, sandy land", "dessert": "is the sweet course"],
        ["bought": "is the past of “buy”", "brought": "is the past of “bring”"],
        ["of": "links two nouns (a cup of tea)", "off": "is the opposite of on"],
        ["been": "follows have/has/had (I have been)", "being": "follows am/is/are/was/were (it is being fixed)"],
        ["lead": "is the present: to guide (pronounced “leed”)", "led": "is the past of “lead”"],
        ["choose": "is now (I choose)", "chose": "is the past (I chose yesterday)"],
        ["who": "is for people", "which": "is for things"],
    ]

    private static let memoryTricks: [String: String] = [
        "they're": "Test it: say “they are” in its place. If the sentence still works, write “they're”.",
        "it's": "Test it: say “it is” in its place. If the sentence still works, write “it's”. If not, “its”.",
        "its": "Test it: say “it is” in its place. If that sounds wrong, it's “its” with no apostrophe.",
        "you're": "Test it: say “you are” in its place. If the sentence still works, write “you're”.",
        "your": "Test it: say “you are” in its place. If that sounds wrong, it's “your”.",
        "than": "“Than” has an A, like “compAre”. “Then” has an E, like “timE”.",
        "then": "“Then” has an E, like “timE”. “Than” has an A, like “compAre”.",
        "affect": "A for Action: “affect” is the action. E for End result: “effect”.",
        "effect": "E for End result: “effect” is the result. A for Action: “affect”.",
        "lose": "“Lose” lost an O.",
        "too": "“Too” has one O too many: it means “more than enough” or “also”.",
    ]

    private static let practice: [String: (String, String)] = [
        "they're": ("Their coming at six.", "They're coming at six."),
        "their": ("They left there bags here.", "They left their bags here."),
        "there": ("Put it over their.", "Put it over there."),
        "it's": ("Its going to rain today.", "It's going to rain today."),
        "its": ("The company changed it's logo.", "The company changed its logo."),
        "you're": ("Your going to love this.", "You're going to love this."),
        "your": ("Is this you're laptop?", "Is this your laptop?"),
        "than": ("This one is cheaper then that one.", "This one is cheaper than that one."),
        "then": ("Finish the draft, than send it.", "Finish the draft, then send it."),
        "affect": ("The delay will effect the launch.", "The delay will affect the launch."),
        "effect": ("The change had no affect.", "The change had no effect."),
        "lose": ("We can't loose this client.", "We can't lose this client."),
        "too": ("I want to come to.", "I want to come too."),
        "to": ("I went too the office.", "I went to the office."),
        "whether": ("Tell me weather you can come.", "Tell me whether you can come."),
        "advice": ("Thanks for the advise.", "Thanks for the advice."),
        "quite": ("The room was quiet big.", "The room was quite big."),
        "accept": ("I except your offer.", "I accept your offer."),
        "past": ("We walked passed the office.", "We walked past the office."),
        "who": ("The person which called me.", "The person who called me."),
    ]

    // MARK: Small tables

    private static let singular: Set<String> = ["he", "she", "it", "this", "that", "everyone", "everybody", "someone", "somebody", "nobody", "each"]
    private static let plural: Set<String> = ["i", "you", "we", "they", "these", "those", "people"]
    private static let agreement: [String: String] = ["has": "have", "goes": "go", "does": "do", "is": "are", "was": "were",
                                                      "doesn't": "don't", "isn't": "aren't", "wasn't": "weren't", "hasn't": "haven't"]
    private static let helpers: Set<String> = ["did", "didn't", "does", "doesn't", "do", "don't", "can", "can't", "could", "couldn't", "will", "won't",
                                               "would", "wouldn't", "should", "shouldn't", "must", "might", "may", "to", "let", "let's"]
    private static let irregularPast: [String: String] = [
        "understood": "understand", "went": "go", "gone": "go", "meant": "mean", "knew": "know", "known": "know", "saw": "see", "seen": "see",
        "came": "come", "took": "take", "taken": "take", "got": "get", "told": "tell", "said": "say", "made": "make", "found": "find",
        "thought": "think", "gave": "give", "given": "give", "did": "do", "done": "do", "had": "have", "sent": "send", "wrote": "write",
        "written": "write", "spoke": "speak", "spoken": "speak", "bought": "buy", "brought": "bring", "left": "leave", "felt": "feel",
        "kept": "keep", "met": "meet", "paid": "pay", "ran": "run", "sat": "sit", "forgot": "forget", "forgotten": "forget", "began": "begin",
        "begun": "begin", "heard": "hear", "held": "hold", "lost": "lose", "built": "build", "chose": "choose", "ate": "eat", "eaten": "eat",
        "drove": "drive", "fell": "fall", "flew": "fly", "grew": "grow", "became": "become", "broke": "break", "caught": "catch", "taught": "teach",
        "sold": "sell", "spent": "spend", "stood": "stand", "won": "win", "woke": "wake", "wore": "wear", "threw": "throw", "slept": "sleep",
    ]
    private static func isPast(_ past: String, of verb: String) -> Bool {
        if irregularPast[past] == verb { return true }
        guard past.hasSuffix("ed") else { return false }
        let stem = String(past.dropLast(2))
        return stem == verb || stem + "e" == verb || (stem.count > 2 && String(stem.dropLast()) == verb && stem.last == stem.dropLast().last)
            || (stem.hasSuffix("i") && String(stem.dropLast()) + "y" == verb)
    }
    private static let noPreposition: [String: Set<String>] = [
        "about": ["discuss", "discussing", "discussed", "discusses", "mention", "mentioned", "mentioning", "describe", "described", "describing", "consider", "considering", "considered"],
        "on": ["emphasize", "emphasized", "emphasizing", "stress", "stressed", "stressing"],
        "for": ["request", "requested", "requesting", "await", "awaiting", "awaited", "order", "ordered", "seek", "seeking"],
        "to": ["reach", "reached", "reaching", "tell", "told", "telling", "ask", "asked", "asking", "contact", "contacted", "contacting", "call", "called", "calling",
               "answer", "answered", "answering", "approach", "approached", "attend", "attended", "attending", "join", "joined", "joining", "enter", "entered", "entering"],
        "with": ["marry", "married", "marrying", "meet", "met", "meeting", "resemble", "resembles"],
        "back": ["return", "returned", "returning", "revert", "reverted", "reverting", "reply", "replied", "replying"],
        "again": ["repeat", "repeated", "repeating"],
        "of": ["comprise", "comprises", "comprised", "despite"],
    ]
    private static let uncountable: Set<String> = ["information", "advice", "furniture", "equipment", "feedback", "homework", "staff", "software",
                                                   "knowledge", "luggage", "stuff", "research", "evidence", "news", "traffic", "work", "money", "progress", "luck", "data"]
    private static let stative: Set<String> = ["agree", "disagree", "think", "know", "want", "need", "understand", "believe", "like", "love", "prefer", "remember", "mean", "have"]
    private static let days: Set<String> = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "weekend", "weekdays"]
    private static let months: Set<String> = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december",
                                              "morning", "afternoon", "evening", "summer", "winter", "spring", "autumn"]
    private static let shorthand: [String: String] = ["u": "you", "ur": "your", "r": "are", "y": "why", "b4": "before", "2": "to", "4": "for", "n": "and",
                                                      "wud": "would", "cud": "could", "shud": "should", "wat": "what", "da": "the", "nd": "and", "hv": "have", "coz": "because"]
    private static let modals: Set<String> = ["should", "could", "would", "must", "might", "may", "shouldn't", "couldn't", "wouldn't"]

    // MARK: Checks (first match wins; order matters)

    private static let checks: [@Sendable (Context) -> CoachRule?] = idiomChecks + coreChecks

    /// Honest description for a change no rule covers. It says what changed; it never invents a grammar rule.
    private static func describe(_ c: Context) -> CoachRule? {
        let f = c.from, t = c.to
        if f.isEmpty || t.isEmpty || c.rawFrom.lowercased() == c.rawTo.lowercased() { return nil }   // punctuation, capitals, insert/remove: handled elsewhere
        if f.count >= 2, f.sorted() == t.sorted() {
            return CoachRule(label: "Word order", category: .clarity, kind: "style",
                             why: "Same words, in the order English expects: “\(c.rawTo)”.")
        }
        let kept = t.filter(f.contains).count
        if f.count >= 4, t.count < f.count, kept * 2 >= t.count {
            return CoachRule(label: "Tighter", category: .clarity, kind: "style",
                             why: "This says the same thing in fewer words. Nothing the reader needs was lost.")
        }
        if f.count >= 3 || t.count >= 3 {
            return CoachRule(label: "Natural phrasing", category: .clarity, kind: "style",
                             why: "Your version can be understood. This is how a fluent speaker would usually put it.")
        }
        // A small swap with no rule on file: say so plainly instead of guessing at grammar.
        if ChangeSet.guessCategory(from: c.rawFrom, to: c.rawTo) == nil {
            return CoachRule(label: "Suggested wording", category: .wordChoice, kind: "style",
                             why: "“\(c.rawTo)” is the more usual wording here than “\(c.rawFrom)”.")
        }
        return nil
    }

    private static let collocations: [String: String] = [
        "depend": "on", "depends": "on", "depending": "on", "rely": "on", "focus": "on", "insist": "on", "congratulate": "on", "congratulations": "on",
        "interested": "in", "participate": "in", "succeed": "in", "good": "at", "bad": "at", "arrive": "at", "arrived": "at",
        "different": "from", "responsible": "for", "apologize": "for", "wait": "for", "waiting": "for", "afraid": "of", "capable": "of", "proud": "of",
        "consist": "of", "consists": "of", "married": "to", "listen": "to", "listening": "to", "similar": "to", "belong": "to", "belongs": "to",
        "explain": "to", "agree": "with", "worried": "about",
    ]
    private static let subjectForms: [String: String] = ["me": "I", "him": "he", "her": "she", "us": "we", "them": "they"]
    private static let bareTime: Set<String> = ["next", "last", "this", "every", "tomorrow", "yesterday", "today", "tonight"]

    /// Patterns common in Indian and other second-language English, plus a few sentence-level rules.
    private static let idiomChecks: [@Sendable (Context) -> CoachRule?] = [
        { c in
            let s = c.from.joined(separator: " "), t = c.to.joined(separator: " ")
            if s.contains("do the needful") {
                return CoachRule(label: "“do the needful”", category: .tone, kind: "style",
                                 why: "“Do the needful” is common in Indian English, but readers elsewhere don't know what you need. Name the action: “\(c.rawTo)”.",
                                 tip: "Ask for the exact thing you want done.", wrong: "Kindly do the needful.", right: "Please approve the request today.")
            }
            if c.from.contains("revert"), t.contains("reply") || t.contains("get back") || t.contains("respond") {
                return CoachRule(label: "revert / reply", category: .wordChoice, kind: "style",
                                 why: "Outside India, “revert” means “go back to an earlier state”, not “reply”. Use “reply” or “get back to me”.",
                                 wrong: "Please revert by Friday.", right: "Please reply by Friday.")
            }
            if c.from.contains("prepone") {
                return CoachRule(label: "“prepone”", category: .wordChoice, kind: "style",
                                 why: "“Prepone” is understood in India but not elsewhere. Say “move it earlier” or “bring it forward”.",
                                 wrong: "Can we prepone the call?", right: "Can we move the call earlier?")
            }
            if s == "today morning" || s == "today evening" || s == "today afternoon" || s == "yesterday night" {
                return CoachRule(label: "this morning / last night", category: .wordChoice, kind: "error",
                                 why: "English says “this morning”, “this evening” and “last night”, not “today morning” or “yesterday night”.",
                                 wrong: "I called him today morning.", right: "I called him this morning.")
            }
            if c.f == "back", c.t == "ago" {
                return CoachRule(label: "ago", category: .wordChoice, kind: "style",
                                 why: "For time before now, use “ago”: “two years ago”. “Two years back” is informal and regional.",
                                 wrong: "I joined three years back.", right: "I joined three years ago.")
            }
            if s.hasPrefix("myself"), t.hasPrefix("i'm") || t.hasPrefix("i am") || t.hasPrefix("my name") {
                return CoachRule(label: "Introducing yourself", category: .grammar, kind: "error",
                                 why: "“Myself” can't start a sentence as the subject. Introduce yourself with “I'm …” or “My name is …”.",
                                 wrong: "Myself Rahul from the sales team.", right: "I'm Rahul from the sales team.")
            }
            if s.contains("am having") || s.contains("is having") || s.contains("are having"), c.to.contains("have") || c.to.contains("has"), !c.to.contains("having") {
                return CoachRule(label: "have, not “am having”", category: .verbForm, kind: "error",
                                 why: "When “have” means “own” or “possess”, it doesn't take -ing: “I have a doubt”, not “I am having a doubt”.",
                                 tip: "-ing is for actions in progress. Owning something isn't an action.",
                                 wrong: "I am having two laptops.", right: "I have two laptops.")
            }
            if c.f == "kindly", c.t == "please" {
                return CoachRule(label: "kindly / please", category: .tone, kind: "style",
                                 why: "“Kindly” can sound stiff or like an order in international English. “Please” is the neutral, friendly choice.")
            }
            if c.f == "only", c.to.isEmpty {
                return CoachRule(label: "“only” for emphasis", category: .clarity, kind: "style",
                                 why: "In Indian English “only” adds emphasis (“I told him only”). Elsewhere it means “just this and nothing else”, so readers may misread it.",
                                 tip: "To stress something, use “really”, “exactly” or word order instead.",
                                 wrong: "He is in the office only.", right: "He is in the office.")
            }
            if c.from == ["able", "to"], c.to.isEmpty, c.prev == "can" || c.prev == "could" {
                return CoachRule(label: "Doubled meaning", category: .clarity, kind: "error",
                                 why: "“\(c.prev.capitalized)” already means “able to”, so “\(c.prev) able to” says it twice.",
                                 wrong: "I can able to join.", right: "I can join.")
            }
            return nil
        },
        // "Me and him go" → "He and I go"
        { c in
            let subjects = Set(subjectForms.values.map { $0.lowercased() })
            guard c.from.count <= 4, let obj = c.from.first(where: { subjectForms[$0] != nil }),
                  c.to.contains(where: subjects.contains), !c.to.contains(obj), c.to.count <= 4 else { return nil }
            return CoachRule(label: "I / me", category: .grammar, kind: "error",
                             why: "The person doing the action takes the subject form: I, he, she, we, they. “\(obj.capitalized)” is for after a verb or a preposition. Put yourself last: “He and I”.",
                             tip: "Drop the other person and listen: “Me go to the office”? No. “I go”, so “He and I go”.",
                             wrong: "Me and Sara finished the report.", right: "Sara and I finished the report.")
        },
        // Embedded question: "what did he meant" → "what he meant"
        { c in
            let wh: Set<String> = ["what", "why", "where", "when", "how", "who", "which"]
            let aux: Set<String> = ["did", "does", "do", "is", "are", "was", "were", "can", "will"]
            let fromAll = c.before.suffix(2) + c.from
            guard let a = c.from.first(where: aux.contains), fromAll.contains(where: wh.contains),
                  !c.to.contains(a) || c.to.firstIndex(of: a) != c.from.firstIndex(of: a), c.from.count <= 5,
                  ["know", "understand", "understood", "tell", "ask", "wonder", "sure", "idea", "explain", "see", "remember"].contains(where: { c.sentence.contains($0) }) else { return nil }
            return CoachRule(label: "Question inside a sentence", category: .grammar, kind: "error",
                             why: "A question inside a longer sentence uses normal word order, with no extra “\(a)”: “what he meant”, not “what did he meant”.",
                             tip: "“Did” and question order are only for direct questions: “What did he mean?”",
                             wrong: "Can you tell me where is the office?", right: "Can you tell me where the office is?")
        },
        // "looking forward to meet" → "to meeting"
        { c in
            guard c.sentence.contains("forward to"), !c.f.isEmpty, c.t == c.f + "ing" || c.t == String(c.f.dropLast()) + "ing" || c.to.last?.hasSuffix("ing") == true && c.from.last.map({ !$0.hasSuffix("ing") }) == true else { return nil }
            return CoachRule(label: "look forward to + -ing", category: .verbForm, kind: "error",
                             why: "After “look forward to”, the verb takes -ing: “look forward to \(c.to.last ?? "meeting")”. Here “to” is a preposition, not part of the verb.",
                             tip: "Test: you can say “look forward to it”. A thing fits, so use the -ing form.",
                             wrong: "I look forward to hear from you.", right: "I look forward to hearing from you.")
        },
        // "on next week" → "next week"
        { c in
            guard ["on", "in", "at"].contains(c.f), c.to.isEmpty, bareTime.contains(c.next) else { return nil }
            return CoachRule(label: "No preposition before “\(c.next)”", category: .grammar, kind: "error",
                             why: "Time phrases with next, last, this, every, tomorrow or yesterday take no preposition: “\(c.next) \(c.after.dropFirst().first ?? "")”, not “\(c.f) \(c.next) …”.",
                             wrong: "Let's meet on next Monday.", right: "Let's meet next Monday.")
        },
        // Fixed verb/adjective + preposition pairs
        { c in
            let anchor = c.before.suffix(2).last(where: { collocations[$0] != nil }) ?? ""
            guard let prep = collocations[anchor], c.t == prep, c.from.count <= 1,
                  c.from.isEmpty || ["on", "in", "at", "of", "for", "to", "with", "from", "about", "than", "upon"].contains(c.f) else { return nil }
            return CoachRule(label: "\(anchor) \(prep)", category: .wordChoice, kind: "error",
                             why: "“\(anchor.capitalized)” goes with “\(prep)”: “\(anchor) \(prep) \(c.next)”. These pairs are fixed in English, so learn them as one piece.",
                             tip: "Learn the pair, not the single word: depend on, interested in, good at, responsible for.",
                             wrong: "It depends of the weather.", right: "It depends on the weather.")
        },
        // Comma splice
        { c in
            guard c.rawFrom.hasSuffix(","), c.rawTo.hasSuffix(".") || c.rawTo.hasSuffix(";"), c.from == c.to else { return nil }
            return CoachRule(label: "Run-on sentence", category: .punctuation, kind: "error",
                             why: "Two complete sentences can't be joined by a comma alone. End the first with a full stop, or link them with “and”, “but” or “so”.",
                             tip: "Could each half stand alone as a sentence? Then a comma isn't enough.",
                             wrong: "I'm late, the train was delayed.", right: "I'm late. The train was delayed.")
        },
    ]

    private static let coreChecks: [@Sendable (Context) -> CoachRule?] = [
        // "should of" → "should have"
        { c in
            guard c.from.contains("of"), c.to.contains("have") || c.rawTo.contains("'ve"), let m = (c.before + c.from).first(where: modals.contains) else { return nil }
            return CoachRule(label: "“\(m) have”", category: .grammar, kind: "error",
                             why: "After “\(m)” the verb is “have”, not “of”. “\(m.capitalized) of” is only how “\(m)'ve” sounds when spoken.",
                             tip: "If you can say “\(m)'ve”, write “\(m) have”.", wrong: "I should of called you.", right: "I should have called you.")
        },
        // Texting shorthand
        { c in
            guard let full = shorthand[c.f], c.to.contains(full) || c.t == full else { return nil }
            return CoachRule(label: "Texting shorthand", category: .tone, kind: "style",
                             why: "“\(c.f)” is texting shorthand for “\(full)”. It's fine with friends; in a work message, spell it out.")
        },
        // alot, everyday, etc.
        { c in
            if c.from.contains("alot"), c.to.contains("lot") {
                return CoachRule(label: "“a lot”", category: .spelling, kind: "error", why: "“A lot” is always two words. “Alot” isn't a word.",
                                 tip: "You wouldn't write “alittle”; same for “a lot”.", wrong: "Thanks alot for your help.", right: "Thanks a lot for your help.")
            }
            if c.f == "everyday", c.to == ["every", "day"] {
                return CoachRule(label: "every day / everyday", category: .wordChoice, kind: "error",
                                 why: "“Every day” (two words) means each day. “Everyday” (one word) is an adjective meaning ordinary: “everyday clothes”.",
                                 tip: "If you can say “every single day”, it's two words.", wrong: "I go to the gym everyday.", right: "I go to the gym every day.")
            }
            return nil
        },
        // The same word typed twice
        { c in
            guard c.from.count == 2, c.from[0] == c.from[1], c.to == [c.from[0]] else { return nil }
            return CoachRule(label: "Repeated word", category: .clarity, kind: "error", why: "You typed “\(c.from[0])” twice in a row.")
        },
        // Confusable pairs
        { c in
            for group in confusables {
                guard c.from.count <= 3, c.to.count <= 4 else { break }
                for (right, meaning) in group where c.to.contains(right) && !c.from.contains(right) {
                    guard let wrong = c.from.first(where: { group[$0] != nil && !c.to.contains($0) }), let wrongMeaning = group[wrong] else { continue }
                    let p = practice[right]
                    return CoachRule(label: "\(wrong) / \(right)", category: .wordChoice, kind: "error",
                                     why: "“\(right.capitalized)” \(meaning). “\(wrong.capitalized)” \(wrongMeaning).",
                                     tip: memoryTricks[right], wrong: p?.0, right: p?.1)
                }
            }
            return nil
        },
        // a / an
        { c in
            guard (c.f == "a" && c.t == "an") || (c.f == "an" && c.t == "a") else { return nil }
            return CoachRule(label: "a / an", category: .grammar, kind: "error",
                             why: c.t == "an" ? "Use “an” before a vowel sound: “an \(c.next)”. It's the sound that counts, not the letter (an hour, a user)."
                                              : "Use “a” before a consonant sound: “a \(c.next)”. It's the sound that counts, not the letter (a user, an hour).",
                             tip: "Say the next word aloud. Starts with a vowel sound? “an”.", wrong: "It took a hour.", right: "It took an hour.")
        },
        // Missing article
        { c in
            guard c.from.isEmpty, ["a", "an", "the"].contains(c.t) else { return nil }
            return CoachRule(label: "Missing article", category: .grammar, kind: "error",
                             why: c.t == "the" ? "A specific thing that you and the reader both know needs “the” in front: “the \(c.next)”."
                                               : "One countable thing needs “a” or “an” in front: “\(c.t) \(c.next)”. English can't leave it bare.",
                             tip: "Singular + countable = it needs a, an, the, my, this… something.", wrong: "I have meeting at 3.", right: "I have a meeting at 3.")
        },
        // Present perfect continuous: "we was discussing … since" → "we've been discussing … for"
        { c in
            guard c.to.contains("been"), !c.from.contains("been") || c.rawTo.contains("'ve") || c.to.contains("have") || c.to.contains("has") else { return nil }
            return CoachRule(label: "have been + -ing", category: .verbForm, kind: "error",
                             why: "It started in the past and is still going on, so English uses “have been” + -ing: “we have been discussing”.",
                             tip: "Still happening now? “have/has been …ing”. Finished? Simple past.",
                             wrong: "I am working here since 2020.", right: "I have been working here since 2020.")
        },
        { c in
            let low = c.rawTo.lowercased().replacingOccurrences(of: "’", with: "'")
            guard low.hasSuffix("'ve"), c.from.count == 1, low == c.rawFrom.lowercased() + "'ve" else { return nil }
            return CoachRule(label: "have been + -ing", category: .verbForm, kind: "error",
                             why: "It started in the past and is still going on, so English uses “have been” + -ing: “\(c.rawTo) been …”.",
                             tip: "Still happening now? “have/has been …ing”. Finished? Simple past.",
                             wrong: "I am working here since 2020.", right: "I have been working here since 2020.")
        },
        // since / for
        { c in
            guard c.from.contains("since"), c.to.first == "for" else { return nil }
            return CoachRule(label: "since / for", category: .wordChoice, kind: "error",
                             why: "Use “for” with a length of time (for two weeks) and “since” with a starting point (since Monday).",
                             tip: "How long? “for”. From when? “since”.", wrong: "I have lived here since five years.", right: "I have lived here for five years.")
        },
        { c in
            guard c.f == "for", c.t == "since" else { return nil }
            return CoachRule(label: "since / for", category: .wordChoice, kind: "error",
                             why: "Use “since” with a starting point (since \(c.next)) and “for” with a length of time (for two weeks).",
                             tip: "How long? “for”. From when? “since”.", wrong: "I have been waiting for Monday.", right: "I have been waiting since Monday.")
        },
        // Base verb after did / can / to …
        { c in
            guard !c.f.isEmpty, !c.t.isEmpty, isPast(c.f, of: c.t), let helper = c.before.suffix(3).last(where: helpers.contains) else { return nil }
            return CoachRule(label: "Base verb after “\(helper)”", category: .verbForm, kind: "error",
                             why: "“\(helper.capitalized)” already shows the tense, so the verb after it stays in its base form: “\(helper) \(c.t)”, not “\(helper) \(c.f)”.",
                             tip: "After did, does, can, will, should, to: plain verb, no -ed, no -s.",
                             wrong: "I didn't went to the meeting.", right: "I didn't go to the meeting.")
        },
        // Past tense with a finished-time word
        { c in
            guard !c.f.isEmpty, !c.t.isEmpty, isPast(c.t, of: c.f),
                  let marker = ["yesterday", "last night", "last week", "last month", "last year", " ago", "earlier today", "this morning"].first(where: { c.sentence.contains($0) }) else { return nil }
            return CoachRule(label: "Past tense", category: .verbForm, kind: "error",
                             why: "“\(marker.trimmed.capitalized)” puts this in the finished past, so the verb takes its past form: “\(c.t)”.",
                             tip: "A finished-time word (yesterday, last week, ago) means past tense.",
                             wrong: "Yesterday I go to the bank.", right: "Yesterday I went to the bank.")
        },
        // Subject–verb agreement
        { c in
            guard !c.f.isEmpty, !c.t.isEmpty else { return nil }
            let subject = c.prev
            let dropsS = agreement[c.f] == c.t || ((c.f == c.t + "s" || c.f == c.t + "es") && (plural.contains(subject) || singular.contains(subject)))
            let addsS = agreement[c.t] == c.f || ((c.t == c.f + "s" || c.t == c.f + "es") && (plural.contains(subject) || singular.contains(subject)))
            guard dropsS || addsS else { return nil }
            let who = subject == "i" ? "I" : subject
            let known = plural.contains(subject) || singular.contains(subject)
            let why: String
            if dropsS {
                why = known ? "With “\(who)” the verb is “\(c.t)”: “\(who) \(c.t)”. Only he, she, it, or one single thing takes “\(c.f)”."
                            : "More than one person is doing this, so the verb is “\(c.t)”, not “\(c.f)”. “\(c.f.capitalized)” goes with he, she, it, or one single thing."
            } else {
                why = known ? "“\(who.capitalized)” is one person or thing, so the verb takes the -s form: “\(who) \(c.t)”."
                            : "One person or thing is doing this, so the verb takes the -s form: “\(c.t)”, not “\(c.f)”."
            }
            return CoachRule(label: "Subject–verb agreement", category: .grammar, kind: "error", why: why,
                             tip: "He, she, it → verb with -s (has, goes, works). I, you, we, they → no -s (have, go, work).",
                             wrong: dropsS ? "They was late again." : "She have two brothers.", right: dropsS ? "They were late again." : "She has two brothers.")
        },
        // "I am agree"
        { c in
            guard ["am", "is", "are", "was", "were"].contains(c.f), c.to.isEmpty, stative.contains(c.next) else { return nil }
            return CoachRule(label: "Extra “\(c.f)”", category: .grammar, kind: "error",
                             why: "“\(c.next.capitalized)” is already the verb, so it doesn't need “\(c.f)” in front: “\((c.prev == "i" ? "I " : c.prev.isEmpty ? "" : c.prev + " ") + c.next)”.",
                             tip: "“am/is/are” goes before -ing verbs and adjectives (I am working, I am happy), not before a plain verb.",
                             wrong: "I am agree with the plan.", right: "I agree with the plan.")
        },
        // Verbs that take no preposition; doubled meaning
        { c in
            guard c.to.isEmpty, let verbs = noPreposition[c.f], let verb = c.before.suffix(2).last(where: verbs.contains) else { return nil }
            if c.f == "back" || c.f == "again" {
                return CoachRule(label: "Doubled meaning", category: .clarity, kind: "style",
                                 why: "“\(verb.capitalized)” already means “\(c.f == "back" ? "go or send back" : "do again")”, so “\(c.f)” says it twice.",
                                 wrong: "Please revert back by Friday.", right: "Please reply by Friday.")
            }
            return CoachRule(label: "No “\(c.f)” after “\(verb)”", category: .grammar, kind: "error",
                             why: "“\(verb.capitalized)” takes its object directly, with no “\(c.f)”: “\(verb) \(c.after.prefix(2).joined(separator: " "))”.",
                             tip: "Discuss, mention, describe, tell, ask, reach, contact, attend, join: no preposition after them.",
                             wrong: "We discussed about the budget.", right: "We discussed the budget.")
        },
        // on / in / at with time
        { c in
            let preps: Set<String> = ["on", "in", "at"]
            guard preps.contains(c.t), preps.contains(c.f) || c.from.isEmpty else { return nil }
            let n = c.next
            let rule = "Days and dates take “on” (on Monday), months, years and parts of the day take “in” (in July, in the morning), clock times take “at” (at 5pm)."
            let fits = (c.t == "on" && days.contains(n)) || (c.t == "in" && (months.contains(n) || n.count == 4 && Int(n) != nil)) || (c.t == "at" && (n.first?.isNumber == true || ["night", "noon", "midnight"].contains(n)))
            guard fits else { return nil }
            return CoachRule(label: "on / in / at", category: .wordChoice, kind: "error", why: rule,
                             tip: "Small to big: at a time, on a day, in a month or year.", wrong: "The call is in Monday on 5pm.", right: "The call is on Monday at 5pm.")
        },
        // say / tell
        { c in
            guard ["say", "said", "saying", "says"].contains(c.f), ["tell", "told", "telling", "tells"].contains(c.t) else { return nil }
            return CoachRule(label: "say / tell", category: .wordChoice, kind: "error",
                             why: "“Tell” needs a person right after it (tell you, tell him). “Say” doesn't take one: you say something to someone.",
                             tip: "Tell + person. Say + words.", wrong: "He said me the news.", right: "He told me the news.")
        },
        // much / many, less / fewer
        { c in
            if c.f == "much", c.t == "many" {
                return CoachRule(label: "much / many", category: .wordChoice, kind: "error",
                                 why: "Use “many” with things you can count (many \(c.next)) and “much” with things you can't (much time).",
                                 tip: "Can you put a number in front? Then “many”.", wrong: "How much people are coming?", right: "How many people are coming?")
            }
            if c.f == "many", c.t == "much" {
                return CoachRule(label: "much / many", category: .wordChoice, kind: "error",
                                 why: "Use “much” with things you can't count (much \(c.next)) and “many” with things you can (many people).",
                                 tip: "Can you put a number in front? If not, “much”.", wrong: "I don't have many time.", right: "I don't have much time.")
            }
            if c.f == "less", c.t == "fewer" {
                return CoachRule(label: "less / fewer", category: .wordChoice, kind: "style",
                                 why: "Use “fewer” with things you can count (fewer \(c.next)) and “less” with things you can't (less time).",
                                 wrong: "We had less complaints this month.", right: "We had fewer complaints this month.")
            }
            return nil
        },
        // "more better"
        { c in
            guard c.f == "more" || c.f == "most", c.to.isEmpty, c.next.hasSuffix("er") || c.next.hasSuffix("est") || ["better", "worse", "best", "worst"].contains(c.next) else { return nil }
            return CoachRule(label: "Double comparative", category: .grammar, kind: "error",
                             why: "“\(c.next.capitalized)” already means “more”, so “\(c.f) \(c.next)” says it twice.",
                             tip: "Short words take -er (faster). Long words take “more” (more useful). Never both.",
                             wrong: "This one is more faster.", right: "This one is faster.")
        },
        // Uncountable nouns
        { c in
            guard c.f.hasSuffix("s"), uncountable.contains(c.t), c.f == c.t + "s" || c.f == c.t + "es" else { return nil }
            return CoachRule(label: "Uncountable noun", category: .grammar, kind: "error",
                             why: "“\(c.t.capitalized)” can't be counted in English, so it has no plural. Say “some \(c.t)” or “a piece of \(c.t)”.",
                             tip: "Information, advice, feedback, equipment, furniture, software, staff: never with -s.",
                             wrong: "Thanks for the informations.", right: "Thanks for the information.")
        },
        // Apostrophe contractions: dont → don't
        { c in
            let plain = c.rawFrom.lowercased().replacingOccurrences(of: "'", with: ""), fixed = c.rawTo.lowercased().replacingOccurrences(of: "’", with: "'")
            guard !c.f.isEmpty, fixed.contains("'"), fixed.replacingOccurrences(of: "'", with: "").trimmingCharacters(in: .punctuationCharacters) == plain.trimmingCharacters(in: .punctuationCharacters),
                  !c.rawFrom.contains("'"), !c.rawFrom.contains("’") else { return nil }
            let long: [String: String] = ["n't": "not", "'re": "are", "'ve": "have", "'ll": "will", "'m": "am", "'d": "would", "'s": "is"]
            guard let (short, full) = long.first(where: { fixed.trimmingCharacters(in: .punctuationCharacters).hasSuffix($0.key) }) else { return nil }
            return CoachRule(label: "Apostrophe", category: .spelling, kind: "error",
                             why: "The apostrophe in “\(c.rawTo.trimmingCharacters(in: .punctuationCharacters))” stands for the letters left out of “\(full)”\(short == "n't" ? "" : " (\(short) = \(full))").",
                             tip: "Two words squeezed into one? The apostrophe goes where letters were dropped.",
                             wrong: "I dont think thats right.", right: "I don't think that's right.")
        },
    ]
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
