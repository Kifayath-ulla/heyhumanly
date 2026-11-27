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
        // An all-lowercase message keeps its lowercase "i" too, except in Professional, which is asked for proper capitalisation.
        if slang { fixed = keepLowercase(original: original, rewrite: fixed) }
        let lower = slang && original == original.lowercased() && original != original.uppercased()
        return restoreCode(original: original, rewrite: keep.contains("i") || lower ? fixed : capitalizeI(fixed))
    }

    /// Grammar slips a small model often leaves in ("I has", "we was"). Fixed only when the writer's text had them.
    /// Only subject-only pronouns, so "the thing I sent you was" is left alone. Mirrored in extension/core.js (fixGrammar).
    private static let grammarRules: [(NSRegularExpression, String)] = [
        (try! NSRegularExpression(pattern: "\\b([Ii]) has\\b"), "$1 have"),
        (try! NSRegularExpression(pattern: "\\b(we|they) was\\b", options: .caseInsensitive), "$1 were"),
        (try! NSRegularExpression(pattern: "\\b(t)heir (is|are|was|were)\\b", options: .caseInsensitive), "$1here $2"),
        (try! NSRegularExpression(pattern: "\\b(should|could|would|must|might) of\\b(?! course)", options: .caseInsensitive), "$1 have"),
        (try! NSRegularExpression(pattern: "\\b(he|she) don(['’]?)t\\b", options: .caseInsensitive), "$1 doesn$2t"),
        (try! NSRegularExpression(pattern: "(^|[.!?,;:]\\s+|\\b(?:and|but|so|because|cuz|if|that|when|whether|maybe|think|hope|guess|know|said|says|sure|bet)\\s+)(t)heir going to\\b(?! (?:the|a|an|my|your|his|her|its|our|their|this|that|these|those)\\b)", options: .caseInsensitive), "$1$2hey're going to"),
    ]

    static func fixGrammar(original: String, rewrite: String) -> String {
        var out = rejoinTail(original: original, rewrite: keepOfCourse(original: original, rewrite: rewrite))
        for (re, template) in grammarRules
        where re.firstMatch(in: original, range: NSRange(location: 0, length: (original as NSString).length)) != nil {
            out = re.stringByReplacingMatches(in: out, range: NSRange(location: 0, length: (out as NSString).length), withTemplate: template)
        }
        return out
    }

    /// "…shipping it tbh" must not come back as "…shipping it. TBH.": a trailing word the model split off goes back on the sentence.
    /// Mirrored in extension/core.js (rejoinTail).
    static func rejoinTail(original: String, rewrite: String) -> String {
        let o = original as NSString
        guard let m = try! NSRegularExpression(pattern: "[\\p{L}\\p{N}]\\s+(\\p{L}+)\\W*$").firstMatch(in: original, range: NSRange(location: 0, length: o.length)) else { return rewrite }
        let word = o.substring(with: m.range(at: 1))
        guard chat.contains(word.lowercased()) else { return rewrite }
        let re = try! NSRegularExpression(pattern: "([\\p{L}\\p{N}])([.!?;])\\s+" + NSRegularExpression.escapedPattern(for: word) + "([.!?]*)\\s*$", options: .caseInsensitive)
        let r = rewrite as NSString
        guard let hit = re.firstMatch(in: rewrite, range: NSRange(location: 0, length: r.length)) else { return rewrite }
        let sep = r.substring(with: hit.range(at: 2)), end = "?!".contains(sep) ? sep : r.substring(with: hit.range(at: 3))
        return r.replacingCharacters(in: hit.range, with: r.substring(with: hit.range(at: 1)) + " " + word + end)
    }

    /// Fix only must not cut the writer's words: true when the rewrite drops two or more of them and is two or more
    /// words shorter than the original with only the deterministic fixes. Mirrored in extension/core.js (cutsWords).
    static func cutsWords(original: String, rewrite: String, preserve: [String] = []) -> Bool {
        let base = tokens(apply(original: original, rewrite: original, preserve: preserve)), after = tokens(rewrite)
        var left: [String: Int] = [:]
        for w in after { left[w, default: 0] += 1 }
        var gone: [String] = []
        for w in base { if let n = left[w], n > 0 { left[w] = n - 1 } else { gone.append(w) } }
        if gone.count >= 2 && base.count - after.count >= 2 { return true }
        // A word swapped for an unrelated one ("Great work" → "Great job") is a rewrite, not a fix; "is" → "are", "seen" → "saw" or "realy" → "really" is a fix.
        let added = left.flatMap { Array(repeating: $0.key, count: $0.value) }
        func near(_ a: String, _ b: String) -> Bool { distance(a, b) <= 2 || a.first == b.first || (aux.contains(a) && aux.contains(b)) || (go.contains(a) && go.contains(b)) }
        // A dropped word with nothing like it added ("hey r u" → "hey, u") is a cut too; a dropped helper verb ("I has went" → "I went") is a fix.
        let lost = gone.filter { w in !added.contains { near(w, $0) } }
        if lost.contains(where: { !aux.contains($0) }) { return true }
        // "I have finished" → "I haven't finished" flips the meaning; so does a writer's slang turned into another word ("ngl" → "ngg").
        if negations(base) != negations(after) || gone.contains(where: { chat.contains($0) }) { return true }
        // A statement turned into a question ("review them first" → "review them first?") changes the meaning too; a "?" added to
        // a question ("is it ready" → "is it ready?") is a fix.
        if questionsAStatement(original: original, rewrite: rewrite) { return true }
        return !lost.isEmpty && added.contains { w in !gone.contains { near(w, $0) } }
    }
    private static func negations(_ ws: [String]) -> Int {
        ws.filter { negationWords.contains($0) || $0.hasSuffix("n't") }.count
    }
    private static let negationWords: Set<String> = Set("not no noone never nothing nobody none nor cannot dont doesnt didnt cant couldnt wont wouldnt shouldnt isnt arent wasnt werent havent hasnt hadnt aint mustnt neednt".split(separator: " ").map(String.init))
    /// Chat shorthand Fix only never changes. Same list as RewriteGuard.slang in Guard.swift, plus omw, u, ur, r and sry.
    static let chat: Set<String> = Set(("gng ngl tbh idk imo imho fr rn btw lol lmao brb omg ikr smh fyi asap bro bruh gonna wanna gotta kinda sorta yeah yep yup nope nah ok okay pls plz " +
        "thx ty np nvm tho cuz coz bc idc wdym hbu wyd ofc afaik iirc dm lmk ttyl gg gm gn dude yo hey hiya ya yall y'all ain't lemme gimme dunno tldr " +
        "tmrw tmr msg pic pics ppl abt thru bday prolly rly srsly gtg jk wtf wth af sus lowkey highkey legit fam sis mate hmm uh um haha hehe aight ight wassup sup omw u ur r sry").split(separator: " ").map(String.init))
    private static let go: Set<String> = ["go", "goes", "went", "gone", "going"]
    private static let aux: Set<String> = ["is", "are", "was", "were", "am", "be", "been", "has", "have", "had", "do", "does", "did"]

    /// Small models invent content: a cause the writer never gave ("late due to a bug") or a whole new sentence ("I apologize for
    /// any confusion."). A new cause falls back to the deterministic fixes; a sentence that shares no content word with the original
    /// is dropped. An apology or assistant line the writer never wrote ("We apologize for the delay.", "Let me know if you need help.")
    /// or a rewrite whose content words are all new (none of the writer's) falls back to the deterministic fixes. Friendly may add warmth and
    /// sentences, so it only gets the assistant and content checks. Mirrored in extension/core.js (dropInvented).
    private static let causal = try! NSRegularExpression(pattern: "\\b(?:due to|because|cuz|coz|bcuz|b/c|therefore|as a result|caused by|so that|hence|thus)\\b", options: .caseInsensitive)
    private static let assistant = try! NSRegularExpression(pattern: "\\b(?:here(?:'|’)?s|here is) (?:a|an|the|your) [^.!?:\\n]*\\b(?:version|rewrite|message)\\b|\\bI(?:'|’)?d be (?:happy|glad) to help\\b|\\bI(?:'|’)?m (?:happy|glad) to help\\b|\\bno problem at all\\b|\\bfeel free to ask\\b|\\bask me again\\b|\\bif you need (?:any )?(?:more|further|additional) (?:help|info|information|assistance)\\b|\\b(?:sorry|sry) to hear\\b|\\b(?:thank(?:s| you)|thx|ty) for (?:sharing )?(?:your|the) (?:feedback|kind words|compliment)\\b|\\bI(?:'|’)?m (?:so |really )?glad (?:to hear|you like)\\b|\\bI appreciate your (?:feedback|kind words|recognition)\\b|\\bhope this helps\\b", options: .caseInsensitive)
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
        // The writer's own slang spelled out ("lmk if thats ok" → "let me know if that is okay") is not added content.
        func known(_ s: String) -> Set<String> {
            let fixed = apply(original: s, rewrite: s, preserve: preserve)
            let spelled = (TextSafety.slang + [("ok", ["okay"])]).filter { count($0.0, in: plain(s)) > 0 }.map { $0.1.joined(separator: " ") }
            return contentWords((s + " " + fixed).replacingOccurrences(of: "`", with: " ")).union(contentWords(spelled.joined(separator: " ")))
        }
        let written = contentWords((original + " " + apply(original: original, rewrite: original, preserve: preserve)).replacingOccurrences(of: "`", with: " "))
        let seen = known(original)
        // Friendly may add a friendly line, but not a question or proposal the writer never made ("How about grabbing a coffee?").
        var out = dropAddedSentences(original: original, rewrite: rewrite, known: known, questionsOnly: friendly)
        // A rewrite that opens with an assistant line ("Sorry to hear that!") is a reply, even if that line gets trimmed below.
        let lead = sentence.firstMatch(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length)).map { (rewrite as NSString).substring(with: $0.range) } ?? rewrite
        let opener = intro.stringByReplacingMatches(in: lead, range: NSRange(location: 0, length: (lead as NSString).length), withTemplate: " ")
        if hits(assistant, opener) > hits(assistant, original) { return fallback }
        if hits(assistant, out) > hits(assistant, original) { return fallback }
        if !friendly && hits(apology, out) > hits(apology, original) { return fallback }
        // A rewrite whose content words are all new replaced the message instead of rewriting it.
        let kept = contentWords(out.replacingOccurrences(of: "`", with: " "))
        if written.count >= 3 && !kept.isEmpty && seen.isDisjoint(with: kept) { return fallback }
        // A rewrite that drops the writer's request ("…tests. pls fix asap" → "…tests.") loses what they asked for.
        if !friendly, dropsRequest(original: plain(original), rewrite: plain(out)) { return fallback }
        return out
    }

    /// Only when no request is left and none of the words the writer asked about survive. Mirrored in extension/core.js (dropsRequest).
    private static func dropsRequest(original: String, rewrite: String) -> Bool {
        let o = original as NSString
        let have = Set(tokens(rewrite).map { String($0.prefix(4)) })
        func words(_ t: String) -> [String] { tokens(t).filter { $0.count >= 3 && !stop.contains($0) && !askWords.contains($0) } }
        let asks = askClause.matches(in: original, range: NSRange(location: 0, length: o.length))
        // Each request is checked on its own words, those after the ask or, for "retry it please", before it.
        let lost = asks.filter { m in
            let after = words(o.substring(with: m.range(at: 2)))
            let w = after.isEmpty ? words(o.substring(with: m.range(at: 1))) : after
            return !w.isEmpty && !w.contains { have.contains(String($0.prefix(4))) }
        }.count
        let parts = sentenceBreak.stringByReplacingMatches(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length), withTemplate: "\n").components(separatedBy: "\n")
        let still = parts.filter { stillAsks.firstMatch(in: $0, range: NSRange(location: 0, length: ($0 as NSString).length)) != nil }.count
        return lost > 0 && still < asks.count
    }
    private static let askWords: Set<String> = ["please", "pls", "plz", "can", "could", "would", "will", "you", "u", "the", "and", "for", "but", "our", "its", "his", "her", "him", "she", "was", "are", "has", "had", "too", "also"]
    private static let sentenceBreak = try! NSRegularExpression(pattern: "(?<=[.!?])\\s+")
    private static let askClause = try! NSRegularExpression(pattern: "([^.!?,;]*?)(?:\\b(?:can|could|would|will) (?:you|u)\\b|\\b(?:please|pls|plz)\\b)([^.!?,;]*)", options: .caseInsensitive)
    private static let stillAsks = try! NSRegularExpression(pattern: "\\b(?:can|could|would|will) (?:you|u)\\b|\\b(?:please|pls|plz|kindly|let me know|lmk)\\b|\\?", options: .caseInsensitive)

    private static let writerAsks = try! NSRegularExpression(pattern: "\\b(?:can|could|would|will) (?:you|u)\\b|\\b(?:please|pls|plz)\\b", options: .caseInsensitive)
    private static let request = try! NSRegularExpression(pattern: "^\\W*(?:(?:can|could|would|will) (?:you|u)\\b|please\\b)", options: .caseInsensitive)
    private static func dropAddedSentences(original: String, rewrite: String, known: (String) -> Set<String>, questionsOnly: Bool = false) -> String {
        let seen = known(original)
        let ns = rewrite as NSString
        let parts = sentence.matches(in: rewrite, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
        guard parts.joined() == rewrite else { return rewrite }
        // Only sentences the model added, and only at the start or end: a rewritten sentence of the writer's always stays.
        var extra = parts.count - max(1, sentence.numberOfMatches(in: original, range: NSRange(location: 0, length: (original as NSString).length)))
        var (a, b) = (0, parts.count)
        // The writer's own question reworded ("can u look?" → "Could you please assist?") stays, unless the model added a question.
        func asks(_ t: String) -> Int {
            codeRegex.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length), withTemplate: " ").filter { $0 == "?" }.count
        }
        // Only a request the writer made ("can u…", "pls…") reworded as one ("Could you…?"); any other new question still goes.
        func has(_ re: NSRegularExpression, _ t: String) -> Bool { re.firstMatch(in: t, range: NSRange(location: 0, length: (t as NSString).length)) != nil }
        let plainOriginal = codeRegex.stringByReplacingMatches(in: original, range: NSRange(location: 0, length: (original as NSString).length), withTemplate: " ")
        let ownRequest = asks(rewrite) <= asks(original) && has(writerAsks, plainOriginal)
        func unrelated(_ p: String) -> Bool {
            let w = contentWords(p)
            // Only a question the writer didn't ask: their own question, reworded or split off, stays.
            if questionsOnly && (!p.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") || asks(rewrite) <= asks(original)) { return false }
            return !w.isEmpty && w.isDisjoint(with: seen) && !(ownRequest && has(request, p) && p.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?"))
        }
        // A statement that rewords the writer's first or last clause ("nice job" → "Well done!") stays: the rest doesn't cover that clause.
        // A reworded question of the writer's is kept or dropped as a question, so only their statements hold a place here.
        let po = plainOriginal as NSString
        let clauses: [(w: Set<String>, q: Bool)] = clausePiece.matches(in: plainOriginal, range: NSRange(location: 0, length: po.length)).compactMap { m in
            let w = known(po.substring(with: m.range(at: 1)))
            return w.isEmpty ? nil : (w, po.substring(with: m.range(at: 2)).contains("?"))
        }
        // As many unrelated statements next to the writer's text stay as there are edge clauses it doesn't cover; the rest still go.
        func isQ(_ p: String) -> Bool { p.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") }
        func uncovered(_ cl: [(w: Set<String>, q: Bool)], _ core: ArraySlice<String>) -> Int {
            let w = contentWords(core.joined(separator: " "))
            var n = 0
            for c in cl { if !c.w.isDisjoint(with: w) { break }; if !c.q { n += 1 } }
            return n
        }
        var r = b
        while r - a > 1, unrelated(parts[r - 1]) { r -= 1 }
        let keepEnd = uncovered(Array(clauses.reversed()), parts[a..<r])
        while extra > 0, b > r, isQ(parts[b - 1]) || parts[r..<(b - 1)].filter({ !isQ($0) }).count >= keepEnd { b -= 1; extra -= 1 }
        var l = a
        while b - l > 1, unrelated(parts[l]) { l += 1 }
        let keepStart = uncovered(clauses, parts[l..<b])
        while extra > 0, a < l, isQ(parts[a]) || parts[(a + 1)..<l].filter({ !isQ($0) }).count >= keepStart { a += 1; extra -= 1 }
        return a == 0 && b == parts.count ? rewrite : parts[a..<b].joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Small models sometimes answer the message instead of rewriting it ("thx for the help" -> "No problem at all!", "Can you send
    /// it?" -> "Sure, I can send it."). Every style, Friendly too, then falls back to the deterministic fixes. Mirrored in
    /// extension/core.js (dropReply).
    private static let reply = try! NSRegularExpression(pattern: "^\\W*(sure|no problem|of course|absolutely|certainly|you['’]re welcome|you are welcome|happy to|glad to|great question|my pleasure|anytime|no worries|shoot|it['’]?s (?:okay|ok|fine|alright|all right)|that['’]?s (?:okay|ok|fine)|don['’]?t worry)\\b", options: .caseInsensitive)
    private static let ack = try! NSRegularExpression(pattern: "^\\W*(?:yep|yeah|yes|yup|ok|okay|sure|np|no prob|will do|got it|sounds good|of course|absolutely|certainly)\\b", options: .caseInsensitive)
    private static let leadIntro = try! NSRegularExpression(pattern: "^\\W*(?:here['’]?s|here is) (?:a|an|the|your) [^.!?:\\n]*\\b(?:version|rewrite|message)\\b[^.!?:\\n]*[.!:]?\\s*", options: .caseInsensitive)
    private static let asks = try! NSRegularExpression(pattern: "\\b(?:can|could|would|will) you\\b", options: .caseInsensitive)
    private static let offers = try! NSRegularExpression(pattern: "\\bI(?:['’]ll| will| can(?!['’]t)| could)\\b", options: .caseInsensitive)

    /// A leading "Sure," the writer didn't type is filler when a rewrite follows it ("Sure, could you send…"), not a reply.
    /// Mirrored in extension/core.js (dropFiller).
    private static let filler = try! NSRegularExpression(pattern: "^\\s*(sure|of course|absolutely|certainly)\\s*[,!.]\\s+(?=\\S)", options: .caseInsensitive)
    private static let offerLead = try! NSRegularExpression(pattern: "^\\W*(?:I|we)(?:['’]ll| will| can(?!['’]t)| could| would)\\b|^\\W*(?:here|let me)\\b", options: .caseInsensitive)
    static func dropFiller(original: String, rewrite: String) -> String {
        let ns = rewrite as NSString
        guard let m = filler.firstMatch(in: rewrite, range: NSRange(location: 0, length: ns.length)) else { return rewrite }
        let word = ns.substring(with: m.range(at: 1))
        guard !original.lowercased().contains(word.lowercased()) else { return rewrite }
        let rest = ns.substring(from: m.range.upperBound), whole = NSRange(location: 0, length: (rest as NSString).length)
        // "Sure, lmk if thats ok." keeps only a scrap of the message: still a reply, not a rewrite.
        if tokens(rest).count * 2 < tokens(original).count { return rewrite }
        if offerLead.firstMatch(in: rest, range: whole) != nil || reply.firstMatch(in: rest, range: whole) != nil { return rewrite }
        // "Can you check it?" → "Certainly, the report looks good." answers the request; the rest of a rewrite still asks it.
        func plain(_ t: String) -> String { codeRegex.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length), withTemplate: " ") }
        let o = plain(original), r = plain(rest)
        if writerAsks.firstMatch(in: o, range: NSRange(location: 0, length: (o as NSString).length)) != nil,
           stillAsks.firstMatch(in: r, range: NSRange(location: 0, length: (r as NSString).length)) == nil { return rewrite }
        // "Is it ready?" → "Sure, it is ready." answers the question instead of rewriting it.
        let marks = try! NSRegularExpression(pattern: "\\?+")
        func asks(_ t: String) -> Int { let p = plain(t); return marks.numberOfMatches(in: p, range: NSRange(location: 0, length: (p as NSString).length)) }
        if asks(rest) < asks(original) { return rewrite }
        // A word the writer typed in lowercase ("npm install") keeps its case.
        let first = String(rest.prefix { $0.isLetter })
        let typed = !first.isEmpty && (try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])" + NSRegularExpression.escapedPattern(for: first) + "(?![\\p{L}\\p{N}_])"))?
            .firstMatch(in: original, range: NSRange(location: 0, length: (original as NSString).length)) != nil
        return word.first?.isUppercase == true && !typed ? rest.prefix(1).uppercased() + rest.dropFirst() : rest
    }

    /// The model swapped who is speaking: "Im running late" → "You are running late", or "r u free?" → "I'm free.".
    /// Mirrored in extension/core.js (swapsSpeaker).
    private static let iLead = try! NSRegularExpression(pattern: "^\\W*(?:i['’]m|i['’]ll|i['’]ve|i['’]d|im|i am|i)\\b", options: .caseInsensitive)
    private static let youLead = try! NSRegularExpression(pattern: "^\\W*(?:you['’](?:re|ll|ve|d)|youre|you|ur|u)\\b", options: .caseInsensitive)
    private static let youWord = try! NSRegularExpression(pattern: "\\b(?:you|u|ur|your|youre|you['’](?:re|ll|ve|d))\\b", options: .caseInsensitive)
    private static let meWord = try! NSRegularExpression(pattern: "\\b(?:i|im|i['’]m|i['’]ll|i['’]ve|i['’]d|me|my)\\b", options: .caseInsensitive)
    private static let subjectVerb = try! NSRegularExpression(pattern: "^\\W*(?:(?:am|are|is|was|were|will|would|have|has|had|r|can|could|should|shall|may|might|must|do|does|did|not|never|just|also|still|really|\\p{L}+ly)\\s+)*(\\p{L}+)", options: .caseInsensitive)
    static func swapsSpeaker(original: String, rewrite: String) -> Bool {
        func has(_ re: NSRegularExpression, _ s: String) -> Bool { re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil }
        func plain(_ t: String) -> String { codeRegex.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length), withTemplate: " ") }
        func first(_ t: String) -> String {
            let p = plain(t).trimmingCharacters(in: .whitespacesAndNewlines) as NSString
            let end = try! NSRegularExpression(pattern: "(?<=[.!?])\\s+").firstMatch(in: p as String, range: NSRange(location: 0, length: p.length))
            return end.map { p.substring(to: $0.range.location) } ?? p as String
        }
        // Answers that reword the word asked about: "r u free?" → "I'm available."
        let answer = ["avai": "free", "free": "avai"]
        let negation = try! NSRegularExpression(pattern: "\\b(?:not|never|\\w+n(?:'|’)t|cant|dont|wont|isnt|arent|wasnt|didnt|doesnt)\\b", options: .caseInsensitive)
        func verb(_ s: String, _ lead: NSRegularExpression) -> String {
            let rest = lead.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: "") as NSString
            guard let m = subjectVerb.firstMatch(in: rest as String, range: NSRange(location: 0, length: rest.length)) else { return "" }
            return String(rest.substring(with: m.range(at: 1)).lowercased().prefix(4))
        }
        let o = first(original)
        let r = first(leadIntro.stringByReplacingMatches(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length), withTemplate: ""))
        if has(iLead, o), has(youLead, r), !has(youWord, o) {
            let v = verb(o, iLead)
            if !v.isEmpty && v == verb(r, youLead) { return true }
        }
        // An answer repeats the word asked about ("r u free?" → "I'm free."), even before a new question; "I'd like to know what time works" still asks.
        let asked = Set(tokens(o).map { String($0.prefix(4)) })
        // The writer's own later "I'm free after 3", moved first, is not an answer.
        func ownStatement(_ v: String) -> Bool {
            let p = plain(original).trimmingCharacters(in: .whitespacesAndNewlines)
            let split = try! NSRegularExpression(pattern: "(?<=[.!?])\\s+").stringByReplacingMatches(in: p, range: NSRange(location: 0, length: (p as NSString).length), withTemplate: "\n")
            return split.components(separatedBy: "\n").dropFirst().contains { has(iLead, $0) && verb($0, iLead) == v && has(negation, $0) == has(negation, r) }
        }
        return o.contains("?") && has(youWord, o) && !has(meWord, o) && has(iLead, r) && !has(youWord, r) && !r.contains("?")
            && (asked.contains(verb(r, iLead)) || answer[verb(r, iLead)].map(asked.contains) == true)
            && !ownStatement(verb(r, iLead))
    }

    static func dropReply(original: String, rewrite: String, preserve: [String] = [], keepSlang slang: Bool = true) -> String {
        func has(_ re: NSRegularExpression, _ s: String) -> Bool { re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil }
        let body = leadIntro.stringByReplacingMatches(in: rewrite, range: NSRange(location: 0, length: (rewrite as NSString).length), withTemplate: "")
        let lead = reply.firstMatch(in: body, range: NSRange(location: 0, length: (body as NSString).length))
            .map { (body as NSString).substring(with: $0.range(at: 1)).lowercased().replacingOccurrences(of: "’", with: "'") }
        let quoted = original.lowercased().replacingOccurrences(of: "’", with: "'")
        let acked = has(ack, original) && (!original.contains("?") || rewrite.contains("?"))
        let answers = (lead.map { !acked && !quoted.contains($0) } ?? false) || (has(asks, original) && has(offers, rewrite) && !has(offers, original))
            || swapsSpeaker(original: original, rewrite: rewrite)
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
    private static let questionLead = try! NSRegularExpression(pattern: "^(?:is|are|am|was|were|do|does|did|can|could|would|will|should|shall|may|might|must|have|has|had|what|why|how|when|where|who|whom|whose|which|r|u|any|anyone|anybody|isn['’]?t|aren['’]?t|don['’]?t|doesn['’]?t|didn['’]?t|can['’]?t|won['’]?t|wouldn['’]?t|shouldn['’]?t)\\b", options: .caseInsensitive)
    private static let clausePiece = try! NSRegularExpression(pattern: "([^.!?;,]*)([.!?;,]*)")
    private static let sentencePiece = try! NSRegularExpression(pattern: "[^.!?\\n]*[.!?]+|[^.!?\\n]+")
    /// Sentence by sentence, so a "?" another sentence already had (or a comma added before "can you") can't hide it.
    private static func questionsAStatement(original: String, rewrite: String) -> Bool {
        func pieces(_ t: String) -> [String] {
            let p = codeRegex.stringByReplacingMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length), withTemplate: " ") as NSString
            return sentencePiece.matches(in: p as String, range: NSRange(location: 0, length: p.length)).map { p.substring(with: $0.range) }
        }
        func asked(_ p: String) -> Bool { p.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") }
        func statement(_ p: String) -> Bool {
            asked(p) && !p.components(separatedBy: CharacterSet(charactersIn: ",;:")).contains { c in
                let lead = c.replacingOccurrences(of: "^\\W+", with: "", options: .regularExpression)
                return questionLead.firstMatch(in: lead, range: NSRange(location: 0, length: (lead as NSString).length)) != nil
            }
        }
        let o = pieces(original), r = pieces(rewrite)
        if o.count == r.count { return zip(o, r).contains { statement($0.1) && !asked($0.0) } }
        return r.filter(statement).count > o.filter(statement).count
    }

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
            // "do not" for "dont" is the intended word spelled out, not a wrong word ("I don't not think").
            let spelled = right.replacingOccurrences(of: "n't", with: " not").replacingOccurrences(of: "'re", with: " are")
            if to.lowercased() != right && !(spelled != right && count(spelled, in: to) > 0) {
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
