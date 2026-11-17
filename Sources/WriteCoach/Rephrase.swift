import SwiftUI
import AppKit

/// Rephrase & learn: rewrites for clarity and explains each move by the writing *habit* behind it,
/// so the writer learns what to do differently next time (not just what was changed).
enum Habit: String, Codable, CaseIterable, Identifiable {
    case buriedPoint = "Buried the point", filler = "Filler", vague = "Vague wording", tooLong = "Too much in one sentence"
    case hedging = "Hedging", repetition = "Repetition", passive = "Passive voice", tone = "Tone", order = "Order of ideas"
    var id: String { rawValue }
    var blurb: String {
        switch self {
        case .buriedPoint: return "The main point or ask comes late. Lead with it."
        case .filler: return "Words that add nothing: basically, kind of, just, you know."
        case .vague: return "Words like thing, stuff or it make the reader guess."
        case .tooLong: return "Several ideas in one sentence. Give each its own."
        case .hedging: return "Too many maybes weaken a message you mean."
        case .repetition: return "Saying the same idea twice."
        case .passive: return "Hiding who does what."
        case .tone: return "The tone doesn't fit who is reading."
        case .order: return "Ideas arrive in the order you thought of them, not the order the reader needs."
        }
    }
    var icon: String {
        switch self {
        case .buriedPoint: return "arrow.up.to.line"
        case .filler: return "scissors"
        case .vague: return "scope"
        case .tooLong: return "text.line.first.and.arrowtriangle.forward"
        case .hedging: return "questionmark.bubble"
        case .repetition: return "repeat"
        case .passive: return "arrow.uturn.right"
        case .tone: return "theatermasks"
        case .order: return "list.number"
        }
    }
    static func record(_ habits: [Habit]) {
        var d = (UserDefaults.standard.dictionary(forKey: "heyhumanly.habits") as? [String: Int]) ?? [:]
        for h in habits { d[h.rawValue, default: 0] += 1 }
        UserDefaults.standard.set(d, forKey: "heyhumanly.habits")
    }
    static func counts() -> [(Habit, Int)] {
        let d = (UserDefaults.standard.dictionary(forKey: "heyhumanly.habits") as? [String: Int]) ?? [:]
        return d.compactMap { k, v in Habit(rawValue: k).map { ($0, v) } }.sorted { $0.1 > $1.1 }
    }
}

enum RephraseGoal: String, CaseIterable, Identifiable {
    case clearer = "Clearer", shorter = "Shorter", professional = "Professional", warmer = "Warmer"
    var id: String { rawValue }
    var instruction: String {
        switch self {
        case .clearer: return "Make it clear and direct, the way a thoughtful person would say it out loud to a colleague."
        case .shorter: return "Make it as short as possible without losing any fact or the reason behind it."
        case .professional: return "Make it clear, polite and professional for a workplace reader."
        case .warmer: return "Make it clear and warm, like a friendly message to someone you respect."
        }
    }
}

struct Move: Codable, Identifiable {
    var id = UUID()
    var habit: String
    var before: String
    var after: String
    var why: String
    /// Other places in the text where the same habit shows up (highlighted too).
    var also: [String] = []
    var habitValue: Habit? { Habit(rawValue: habit) }
}

struct RephraseResult {
    var rewrite: String
    var moves: [Move]
    var next: String
}

enum RephraseService {
    /// One short model call for the rewrite; the explanations are computed locally from the writer's own words.
    static func run(text: String, goal: RephraseGoal, endpoint: String, model: String) async throws -> RephraseResult {
        guard let url = URL(string: endpoint) else { throw CoachError.noEndpoint }
        let prompt = """
        You are HeyHumanly, a writing coach. The text may be transcribed speech full of restarts, filler and rambling.
        Rewrite it so the reader gets the point in the first sentence: put the main question, decision or request first, then only the facts the reader needs. Cut filler and hedges. \(goal.instruction)
        Keep every fact, name, number and the writer's own voice. Never invent details. If the writer is unsure or asking something, keep it as a question or a stated doubt: never turn a doubt into a decision or a request into a statement. Reply with ONLY the rewritten text.
        Text:
        \(text)
        """
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": false, "keep_alive": "30m",
                                                                       "options": ["temperature": 0.3, "num_predict": min(700, max(120, text.count / 2 + 80))]])
        let data: Data
        do { (data, _) = try await URLSession.shared.data(for: request) }
        catch let e as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet].contains(e.code) { throw CoachError.ollamaNotRunning }
        struct Outer: Decodable { let response: String?; let error: String? }
        let outer = try JSONDecoder().decode(Outer.self, from: data)
        if let e = outer.error { if e.localizedCaseInsensitiveContains("not found") { throw CoachError.modelMissing(model) }; throw CoachError.server(500, e) }
        let rewrite = CoachService.cleanRewrite(outer.response ?? "")
        guard !rewrite.isEmpty else { throw CoachError.invalidResponse }
        let moves = HabitDetector.moves(original: text, rewrite: rewrite)
        let next = moves.first?.habitValue.map { "Next time, work on one thing: \($0.rawValue.lowercased()). \($0.tip)" } ?? "This was already clear. Keep doing what you're doing."
        return RephraseResult(rewrite: rewrite, moves: moves, next: next)
    }
}

extension Habit {
    var tip: String {
        switch self {
        case .buriedPoint: return "Before you write or speak, finish the sentence “What I need from you is…” and start with that."
        case .filler: return "Pause silently instead of saying “um” or “you know”. A pause sounds confident."
        case .hedging: return "Say it plainly, or name the condition: “If the design isn't fixed by Thursday, we push.”"
        case .vague: return "Replace “thing” with the noun you'd use if someone asked “which one?”."
        case .tooLong: return "One idea per sentence. Start a new one whenever the subject changes."
        case .repetition: return "Say it once, in the strongest place."
        case .passive: return "Put who does the action first: “Priya reviewed it”, not “it was reviewed”."
        case .tone: return "Picture the reader and write the way you'd talk to them."
        case .order: return "Put ideas in the order the reader needs them."
        }
    }
}

/// Finds writing habits in the writer's own text and explains each with their exact words.
enum HabitDetector {
    private static func occurrences(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
    private static func words(_ s: String) -> [String] { s.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.map { String($0).lowercased() } }
    private static func list(_ items: [String]) -> String {
        var seen = Set<String>(); let u = items.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ,.")) }.filter { seen.insert($0.lowercased()).inserted }
        return u.prefix(4).map { "“\($0)”" }.joined(separator: ", ")
    }

    static func moves(original: String, rewrite: String) -> [Move] {
        var out: [Move] = []
        let wc = max(1, words(original).count)

        // Buried point: the clause that matches the rewrite's opening sits late in the original.
        let lead = rewrite.split(whereSeparator: { ".?!".contains($0) }).first.map(String.init) ?? ""
        let leadWords = Set(words(lead).filter { $0.count > 3 })
        if !leadWords.isEmpty {
            let ns = original as NSString
            var best: (score: Double, start: Int, text: String)?
            var idx = 0
            for clause in original.components(separatedBy: CharacterSet(charactersIn: ",;.?!")) {
                let range = ns.range(of: clause, options: [], range: NSRange(location: idx, length: ns.length - idx))
                if range.location != NSNotFound { idx = range.location + range.length }
                let cw = Set(words(clause).filter { $0.count > 3 })
                guard !cw.isEmpty else { continue }
                let score = Double(cw.intersection(leadWords).count) / Double(leadWords.count)
                if score > (best?.score ?? 0.3), range.location != NSNotFound { best = (score, range.location, clause.trimmingCharacters(in: .whitespaces)) }
            }
            if let b = best {
                let before = original.prefix(b.start).split(separator: " ").count
                if Double(before) / Double(wc) > 0.3 && before >= 8 {
                    let phrase = b.text.split(separator: " ").prefix(6).joined(separator: " ")
                    out.append(Move(habit: Habit.buriedPoint.rawValue, before: phrase, after: String(lead.prefix(40)),
                                    why: "Your main point doesn't appear until word \(before + 1) of \(wc). A reader decides whether to keep reading in the first sentence. Open with it: “\(lead.trimmingCharacters(in: .whitespaces))”."))
                }
            }
        }

        // Too long: one sentence carrying several ideas.
        for sentence in original.components(separatedBy: CharacterSet(charactersIn: ".?!")) {
            let n = words(sentence).count
            if n >= 32 {
                let start = sentence.split(separator: " ").prefix(6).joined(separator: " ")
                out.append(Move(habit: Habit.tooLong.rawValue, before: start, after: "",
                                why: "This sentence runs \(n) words and carries several separate ideas joined by “and”, “but” and “so”. Each idea is easier to follow as its own sentence. Split it where the subject changes."))
                break
            }
        }

        // Hedging.
        let hedges = occurrences(#"\b(maybe|probably|perhaps|i think|i guess|i feel like|not sure|might|sort of|kind of)\b"#, in: original)
        if hedges.count >= 2 {
            out.append(Move(habit: Habit.hedging.rawValue, before: hedges[0], after: "", why: "You hedged \(hedges.count) times (\(list(hedges))). Each one tells the reader you don't stand behind the point. If you're unsure, say what you'd need to know; if you're sure, say it plainly.", also: Array(hedges.dropFirst())))
        }

        // Filler.
        let fillers = occurrences(#"\b(um+|uh+|you know|basically|i mean|literally|so basically|kind of|sort of)\b|,\s*like,"#, in: original)
        if !fillers.isEmpty {
            let clean = fillers.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ,")) }
            out.append(Move(habit: Habit.filler.rawValue, before: clean[0], after: "", why: "\(clean.count) filler \(clean.count == 1 ? "phrase" : "phrases") in \(wc) words (\(list(clean))). They add no information, and they make a reader wait for the point.", also: Array(clean.dropFirst())))
        }

        // Vague words.
        let vague = occurrences(#"\b(the |a |some )?(things?|stuff)\b( about| with| on)?( the)?( \w+)?"#, in: original)
        if let v = vague.first {
            let phrase = v.trimmingCharacters(in: .whitespaces)
            out.append(Move(habit: Habit.vague.rawValue, before: phrase, after: "", why: "“\(phrase)” makes the reader guess what you mean. Name the actual thing (the plan, the design, the deadline) so nobody has to ask."))
        }

        // Repetition: the same 3-word run twice.
        let w = words(original)
        if w.count > 8 {
            var seen = [String: Int]()
            for i in 0..<(w.count - 2) { let g = w[i...(i + 2)].joined(separator: " "); seen[g, default: 0] += 1 }
            if let rep = seen.first(where: { $0.value >= 2 && !["i think we", "you know the"].contains($0.key) }) {
                out.append(Move(habit: Habit.repetition.rawValue, before: rep.key, after: "", why: "“\(rep.key)” appears \(rep.value) times. Say it once, in the strongest place."))
            }
        }
        let order: [Habit] = [.buriedPoint, .tooLong, .hedging, .filler, .vague, .repetition]
        return out.sorted { (order.firstIndex(of: $0.habitValue ?? .tone) ?? 9) < (order.firstIndex(of: $1.habitValue ?? .tone) ?? 9) }.prefix(5).map { $0 }
    }
}

extension CoachModel {
    func rephrase() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !rephraseLoading else { return }
        rephraseLoading = true; rephraseResult = nil; rephraseOriginal = text; errorMessage = nil; statusMessage = nil
        let endpoint = settings.endpoint, model = settings.model, goal = rephraseGoal
        Task {
            do {
                let r = try await RephraseService.run(text: text, goal: goal, endpoint: endpoint, model: model)
                rephraseResult = r
                Habit.record(r.moves.compactMap(\.habitValue))
                habitsVersion += 1
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't rephrase that. Try again."
            }
            rephraseLoading = false
        }
    }

    func copyRephrase() {
        guard let r = rephraseResult else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(r.rewrite, forType: .string); statusMessage = "Copied to clipboard"
    }

    func replaceWithRephrase() {
        guard let r = rephraseResult else { return }
        guard let app = sourceApp, !app.isTerminated else { errorMessage = "There's no captured selection to replace. Use Copy, or select text in another app and press \(shortcutLabel)."; return }
        guard AccessibilityBridge.isTrusted else { errorMessage = "Accessibility is off, so HeyHumanly can't paste into \(sourceAppName ?? "that app"). Use Copy instead."; return }
        app.activate(options: [])
        Task {
            for _ in 0..<50 { if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { break }; try? await Task.sleep(nanoseconds: 20_000_000) }
            try? await Task.sleep(nanoseconds: 150_000_000)
            await bridge.replaceSelectedText(with: r.rewrite)
            statusMessage = "Replaced in \(sourceAppName ?? "the app") · ⌘Z there to undo"; sourceApp = nil
        }
    }
}

// MARK: - View

struct RephrasePane: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.rephraseResult == nil && !model.rephraseLoading { composer } else { compact }
                if model.rephraseLoading { loading }
                if let r = model.rephraseResult { result(r) }
                if let e = model.errorMessage { Text(e).font(.system(size: 12.5)).foregroundStyle(Color.removed).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(16)
        }
    }

    private var goals: some View {
        HStack(spacing: 6) {
            ForEach(RephraseGoal.allCases) { g in
                Button { model.rephraseGoal = g } label: {
                    Text(g.rawValue).font(.system(size: 12.5, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(model.rephraseGoal == g ? Color.brand : Color.ink.opacity(0.06), in: Capsule())
                        .foregroundStyle(model.rephraseGoal == g ? Color.white : Color.ink)
                }.buttonStyle(.plain).accessibilityLabel("Make it \(g.rawValue)")
            }
            Spacer()
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Say it the way you'd say it. We'll show you how to say it better, and why.")
                .font(.serif(21, weight: .medium)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.draft).modifier(NoSystemWritingTools()).font(.system(size: 15)).scrollContentBackground(.hidden)
                    .padding(.horizontal, 8).padding(.vertical, 10).frame(minHeight: 190).accessibilityLabel("Text to rephrase")
                if model.draft.isEmpty {
                    Text("Paste a message, or something you dictated. Rambling is fine.")
                        .font(.system(size: 15)).foregroundStyle(.tertiary).padding(.horizontal, 13).padding(.vertical, 10).allowsHitTesting(false)
                }
            }
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
            goals
        }
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOU WROTE").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.tertiary)
            highlighted(model.rephraseOriginal, phrases: model.rephraseResult?.moves.flatMap { [$0.before] + $0.also } ?? [], color: Color.removed)
                .font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loading: some View {
        HStack(spacing: 10) { ProgressView().controlSize(.small); Text("Rephrasing, then working out why…").font(.system(size: 13.5)).foregroundStyle(.secondary); Spacer()
            Text("on \(model.settings.model) · this Mac").font(.system(size: 11)).foregroundStyle(.tertiary) }
            .padding(14).background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
    }

    private func result(_ r: RephraseResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BETTER").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Color.teach)
                highlighted(r.rewrite, phrases: r.moves.map(\.after).filter { $0.count < 60 }, color: Color.added).font(.system(size: 16)).foregroundStyle(Color.ink)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.teach.opacity(0.35)))

            if !r.moves.isEmpty {
                Text("WHAT CHANGED, AND WHY").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.tertiary)
                ForEach(r.moves) { m in move(m) }
            } else {
                Text("This was already clear. Nothing to change.").font(.system(size: 13.5)).foregroundStyle(.secondary)
            }
            if !r.next.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "flag.checkered").foregroundStyle(Color.teach)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next time").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.teach)
                        Text(r.next).font(.system(size: 13.5)).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teach.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func move(_ m: Move) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: m.habitValue?.icon ?? "sparkles").font(.system(size: 15)).foregroundStyle(Color.teach)
                .frame(width: 30, height: 30).background(Color.teach.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(m.habit).font(.system(size: 12, weight: .bold)).foregroundStyle(Color.teach)
                (Text("“\(m.before)”").foregroundColor(Color.removed).strikethrough(true, color: Color.removed)
                 + Text(m.after.isEmpty ? (m.habitValue == .filler || m.habitValue == .hedging ? "  cut" : "") : "  →  “\(m.after)”").foregroundColor(m.after.isEmpty ? .secondary : Color.added))
                    .font(.system(size: 13.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Text(m.why).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14).background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
    }

    private func highlighted(_ text: String, phrases: [String], color: Color) -> Text {
        var a = AttributedString(text)
        for p in phrases where !p.isEmpty {
            if let r = a.range(of: p, options: .caseInsensitive) { a[r].foregroundColor = color; a[r].backgroundColor = color.opacity(0.14) }
        }
        return Text(a)
    }

    /// Footer actions live in the panel footer; this is used there.
    static func footer(_ model: CoachModel) -> some View {
        HStack(spacing: 8) {
            if let s = model.statusMessage { Text(s).font(.system(size: 12)).foregroundStyle(Color.added).lineLimit(1) }
            Spacer()
            if model.rephraseResult != nil {
                Button("New text") { model.rephraseResult = nil; model.draft = ""; model.errorMessage = nil; model.statusMessage = nil }.buttonStyle(SecondaryButtonStyle())
                Button("Copy") { model.copyRephrase() }.buttonStyle(SecondaryButtonStyle())
                if model.sourceApp != nil { Button("Replace in \(model.sourceAppName ?? "app")") { model.replaceWithRephrase() }.buttonStyle(SecondaryButtonStyle()) }
                Button("Rephrase again") { model.rephrase() }.buttonStyle(PrimaryButtonStyle(tint: .teach)).keyboardShortcut(.return, modifiers: .command)
            } else {
                Button { model.rephrase() } label: {
                    HStack(spacing: 6) { if model.rephraseLoading { ProgressView().controlSize(.mini) } else { Image(systemName: "sparkles") }
                        Text(model.rephraseLoading ? "Working…" : "Rephrase & explain") }
                }
                .buttonStyle(PrimaryButtonStyle(tint: .teach)).keyboardShortcut(.return, modifiers: .command)
                .disabled(model.rephraseLoading || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// Insights card: the writing habits the user has been told about, most frequent first.
struct HabitsCard: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        let _ = model.habitsVersion
        let counts = Habit.counts()
        VStack(alignment: .leading, spacing: 12) {
            Text("Your writing habits").font(.system(size: 15, weight: .semibold))
            if counts.isEmpty {
                Text("Use Rephrase on a few messages and your habits will appear here, with what to do about each.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            } else {
                if let top = counts.first {
                    Text("Your biggest habit: \(top.0.rawValue)").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Color.teach)
                    Text(top.0.blurb).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                ForEach(counts, id: \.0) { h, n in
                    HStack(spacing: 10) {
                        Image(systemName: h.icon).frame(width: 20).foregroundStyle(Color.teach)
                        Text(h.rawValue).font(.system(size: 13))
                        Spacer()
                        GeometryReader { g in Capsule().fill(Color.teach.opacity(0.25)).frame(width: g.size.width * CGFloat(n) / CGFloat(counts.first!.1)) }.frame(width: 120, height: 8)
                        Text("\(n)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
