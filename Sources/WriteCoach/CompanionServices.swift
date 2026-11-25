import Foundation

/// Model calls used by the in-app companion. Everything goes to the configured endpoint (local Ollama by default).
enum CompanionService {
    struct Explained { var category: MistakeCategory; var kind: String; var level: String; var label: String; var why: String }
    struct Teaching { var items: [Explained]; var messageTip: String }

    /// The local prompt for one style. Short, direct prompts work best for small local models (measured on
    /// qwen2.5:7b: the long version invented "planning to go"; the Polish one kept the facts on 3 of 3 runs).
    static func prompt(_ text: String, style: WritingStyle, appName: String, preserve: [String]) -> String {
        let task: String
        switch style {
        case .polish:
            task = "Rewrite this \(appName) message so it is clear and natural. Remove repeated or abandoned phrases, fix mistakes, keep the writer's casual tone and every fact. Do not invent facts or plans; drop unclear fragments instead of guessing. Leave slang and abbreviations alone, and fix a typo to the word that was meant (never a different word). Example: \"I was thinking that tomorrow since the dentist is there, I would like to. I wanted to say you. I wanted to tell you I'll be late.\" becomes \"I have a dentist appointment tomorrow, so I'll be late. Just wanted to tell you.\""
        case .fixOnly:
            task = "Fix only the real mistakes in this \(appName) message: spelling, grammar, verb forms, articles, punctuation. Do not rephrase or reorder correct words and keep the tone. Keep the writer's own slang, abbreviations and contractions exactly as typed. If a phrase is repeated back to back, keep it once. If nothing is wrong, return the message unchanged."
        case .shorter:
            task = "Make this \(appName) message noticeably shorter and more direct, in complete natural sentences. Keep every fact and the writer's tone. Do not invent facts."
        case .friendly:
            task = "Rewrite this \(appName) message to sound warmer and friendlier. Keep every fact. No emojis unless the original had them. Do not invent facts."
        case .professional:
            task = "Rewrite this \(appName) message to be polite, clear and professional. Keep every fact. Do not add greetings, sign-offs or ideas that were not there."
        }
        let preserveRule = preserve.isEmpty ? "" : " Keep these words exactly: " + preserve.map { "\"\($0)\"" }.joined(separator: ", ") + "."
        let lines = text.contains("\n") ? " Keep the line breaks." : ""
        return "\(task)\(preserveRule)\(lines) Reply with only the message.\nMessage: \(text)"
    }

    static func tokenLimit(_ text: String) -> Int { min(2048, max(160, text.count / 2 + 120)) }

    /// Rewrites the whole message in a style. Plain text.
    static func rewrite(_ text: String, style: WritingStyle, appName: String, preserve: [String], endpoint: String, model: String, temperature: Double = 0.1) async throws -> String {
        let prompt = prompt(text, style: style, appName: appName, preserve: preserve)
        let limit = tokenLimit(text)
        var out = try await generate(prompt: prompt, endpoint: endpoint, model: model, limit: limit, temperature: temperature)
        // Small models occasionally drift into another language mid-answer. Try once more, then refuse rather than show it.
        if hasForeignScript(out, source: text) {
            out = try await generate(prompt: prompt, endpoint: endpoint, model: model, limit: limit, temperature: 0.4)
            if hasForeignScript(out, source: text) { throw CoachError.invalidResponse }
        }
        return StyleChecker.collapseRepetitions(out)
    }

    /// Same prompt as `rewrite`, streamed so the panel shows words as they arrive.
    static func streamRewrite(_ text: String, style: WritingStyle, appName: String, preserve: [String], endpoint: String, model: String,
                              temperature: Double = 0.1, onToken: @escaping @MainActor (String) -> Void) async throws -> String {
        let prompt = prompt(text, style: style, appName: appName, preserve: preserve)
        var out = try await CoachService.stream(prompt: prompt, endpoint: endpoint, model: model, limit: tokenLimit(text), temperature: temperature, onToken: onToken)
        if hasForeignScript(out, source: text) {
            out = try await generate(prompt: prompt, endpoint: endpoint, model: model, limit: tokenLimit(text), temperature: 0.4)
            if hasForeignScript(out, source: text) { throw CoachError.invalidResponse }
        }
        return StyleChecker.collapseRepetitions(out)
    }

    /// Explains each change: error or style, which level, a short label and one sentence of why (in the user's language).
    static func teach(original: String, rewrite: String, changes: [Change], language: String, endpoint: String, model: String) async -> Teaching? {
        guard !changes.isEmpty, let url = URL(string: endpoint) else { return nil }
        let cats = MistakeCategory.allCases.map(\.rawValue)
        let lines = changes.enumerated().map { "\($0.offset + 1). \"\($0.element.from)\" -> \"\($0.element.to.isEmpty ? "(removed)" : $0.element.to)\"" }.joined(separator: "\n")
        let langRule = language == "English" ? "" : " Write \"why\", \"label\" and \"tip\" in \(language); keep quoted English words in English."
        let prompt = """
        You are a kind, precise writing teacher. A message was improved.
        Original: \(original)
        Improved: \(rewrite)
        Changes:
        \(lines)
        For EACH numbered change give:
        - kind: "error" if the original was wrong (spelling, grammar, verb form, punctuation, capitalization), "style" if it was correct but could read better (repetition, wordiness, awkward or unnatural phrasing, unclear or unfinished thought, tone).
        - level: "word", "phrase" or "sentence".
        - label: 1-3 word name of the rule, e.g. "Repeated phrase", "Unfinished thought", "Verb tense".
        - why: ONE short sentence (max 18 words) to the writer as "you" that QUOTES their exact words and names the rule, e.g. "You said 'I just wanted to' twice; once is enough." Never write a generic line like "Remove redundant word."
        - category: one of \(cats).
        Also give "tip": ONE piece of advice for next time about this whole message, as an instruction (max 18 words), about what matters most here: order (main point first), length, clarity of the ask, or fit for the reader. It must be specific to this message. Do not praise or describe the edit.\(langRule)
        Return JSON {"items":[{"from":"","kind":"","level":"","label":"","why":"","category":""}],"tip":""}, one item per change in order.
        """
        let schema: [String: Any] = ["type": "object", "required": ["items", "tip"], "properties": [
            "tip": ["type": "string"],
            "items": ["type": "array", "items": ["type": "object", "required": ["from", "kind", "level", "label", "why", "category"], "properties": [
                "from": ["type": "string"], "kind": ["type": "string", "enum": ["error", "style"]],
                "level": ["type": "string", "enum": ["word", "phrase", "sentence"]], "label": ["type": "string"],
                "why": ["type": "string"], "category": ["type": "string", "enum": cats]]]]]]
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": false, "think": false, "format": schema, "keep_alive": "30m",
                                                                        "options": ["temperature": 0.1, "num_predict": 120 + 70 * changes.count]])
        struct Outer: Decodable { let response: String }
        struct Parsed: Decodable { struct I: Decodable { let from: String?; let kind: String?; let level: String?; let label: String?; let why: String?; let category: String? }; let items: [I]; let tip: String? }
        guard let (data, _) = try? await LLM.data(for: request),
              let outer = try? JSONDecoder().decode(Outer.self, from: data),
              let parsed = try? JSONDecoder().decode(Parsed.self, from: Data(outer.response.utf8)) else { return nil }
        let norm = { (s: String) in s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
        let items: [Explained] = changes.indices.map { i in
            let c = changes[i]
            let byWords = parsed.items.first { norm($0.from ?? "") == norm(c.from) && !norm(c.from).isEmpty }
            let it = byWords ?? (i < parsed.items.count ? parsed.items[i] : nil)
            // Trust local evidence for obvious typo-level fixes over the model.
            let local = ChangeSet.guessCategory(from: c.from, to: c.to)
            let category = local ?? MistakeCategory(rawValue: it?.category ?? "") ?? c.category
            var kind = it?.kind ?? (c.isError ? "error" : "style")
            // A real mistake is a small, rule-based fix. Rephrasing several words is a style choice, whatever the model says.
            let words = max(c.from.split(separator: " ").count, c.to.split(separator: " ").count)
            if words > 3 || [.clarity, .tone, .wordChoice].contains(category) { kind = "style" }
            if let local, [.spelling, .capitalization, .punctuation].contains(local) { kind = "error" }
            return Explained(category: category, kind: kind, level: it?.level ?? c.learnLevel.rawValue,
                             label: (it?.label).flatMap { $0.isEmpty ? nil : $0 } ?? category.title,
                             why: (it?.why).flatMap { $0.isEmpty ? nil : $0 } ?? c.reason)
        }
        return Teaching(items: items, messageTip: parsed.tip ?? "")
    }

    /// Puts an explanation into the user's language, leaving the quoted English words alone.
    static func translate(_ text: String, to language: String, endpoint: String, model: String) async throws -> String {
        try await generate(prompt: "Translate this grammar explanation into \(language). Keep every word inside quotation marks in English, exactly as it is. Reply with only the translation.\n\(text)",
                           endpoint: endpoint, model: model, limit: 200)
    }

    /// True when the answer contains writing systems the original doesn't use.
    static func hasForeignScript(_ out: String, source: String) -> Bool {
        func scripts(_ s: String) -> Set<String> {
            var found = Set<String>()
            for u in s.unicodeScalars {
                switch u.value {
                case 0x4E00...0x9FFF, 0x3400...0x4DBF: found.insert("han")
                case 0x3040...0x30FF: found.insert("kana")
                case 0xAC00...0xD7AF: found.insert("hangul")
                case 0x0400...0x04FF: found.insert("cyrillic")
                case 0x0600...0x06FF: found.insert("arabic")
                case 0x0900...0x097F: found.insert("devanagari")
                default: break
                }
            }
            return found
        }
        let allowed = scripts(source)
        return !scripts(out).isSubset(of: allowed)
    }

    static func generate(prompt: String, endpoint: String, model: String, limit: Int, temperature: Double = 0.1) async throws -> String {
        guard !endpoint.isEmpty, let url = URL(string: endpoint) else { throw CoachError.noEndpoint }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": false, "think": false, "keep_alive": "30m",
                                                                       "options": ["temperature": temperature, "num_predict": limit]])
        let data: Data, response: URLResponse
        do { (data, response) = try await LLM.data(for: request) }
        catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet].contains(error.code) {
            throw CoachError.ollamaNotRunning
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        let body = String(decoding: data, as: UTF8.self)
        guard status < 300 else {
            if status == 404 || body.localizedCaseInsensitiveContains("not found") { throw CoachError.modelMissing(model) }
            throw CoachError.server(status, body)
        }
        struct Outer: Decodable { let response: String }
        guard let out = try? JSONDecoder().decode(Outer.self, from: data) else { throw CoachError.invalidResponse }
        let cleaned = CoachService.cleanRewrite(out.response)
        guard !cleaned.isEmpty else { throw CoachError.invalidResponse }
        return cleaned
    }

    /// True when the endpoint is on this Mac, so automatic checks never send text elsewhere.
    static func isLocal(_ endpoint: String) -> Bool {
        guard let host = URL(string: endpoint)?.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
    }
}
