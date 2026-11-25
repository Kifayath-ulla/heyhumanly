import SwiftUI
import AppKit

// Visual language for everything drawn over other apps:
// solid surfaces (no decorative blur), 1px hairline, one soft shadow, SF Pro at 12–15pt,
// red wave = real mistake, violet dashes = optional style idea, blue = the action.

private enum C {
    static let radius: CGFloat = 14
    static let shadow = Color.black.opacity(0.22)
}

private struct Surface: ViewModifier {
    var radius: CGFloat = C.radius
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.ink.opacity(0.10), lineWidth: 0.75))
            .shadow(color: C.shadow, radius: 16, y: 8)
            .shadow(color: Color.black.opacity(0.06), radius: 1, y: 0.5)
    }
}
private extension View { func surface(radius: CGFloat = C.radius) -> some View { modifier(Surface(radius: radius)) } }

/// Small key hint, e.g. ⌃⌥↩.
struct KeyHint: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.ink.opacity(0.06)))
    }
}

private struct ActionButton: View {
    let title: String
    var hint: String? = nil
    var primary = false
    var tint: Color = .brand
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                if let hint { Text(hint).font(.system(size: 10.5, weight: .medium, design: .rounded)).opacity(0.7) }
            }
            .foregroundStyle(primary ? (Color.onAccent) : Color.ink)
            .padding(.horizontal, 11).frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(primary ? tint.opacity( hover.on ? 0.92 : 1) : Color.ink.opacity( hover.on ? 0.09 : 0.055)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.on = $0 }
        .accessibilityLabel(title)
    }
}

private struct QuietButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10.5, weight: .semibold)) }
                Text(title).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle( hover.on ? Color.ink : Color.secondary)
            .padding(.horizontal, 6).frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.ink.opacity( hover.on ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hover.on = $0 }
        .accessibilityLabel(title)
    }
}

// MARK: - The companion (the dot next to your text, and what it opens into)

struct CompanionView: View {
    @ObservedObject var session: InlineSession

    static func size(for s: InlineSession) -> NSSize {
        if let l = s.learn, l.finished { return NSSize(width: 380, height: summaryHeight(s)) }
        if s.learn != nil { return NSSize(width: 34, height: 34) }
        if s.expanded { return NSSize(width: 420, height: expandedHeight(s)) }
        if s.toast != nil { return NSSize(width: 420, height: 34) }
        if case .done = s.phase { return NSSize(width: s.undoStack.isEmpty ? 150 : 250, height: 34) }
        if case .failed = s.phase { return NSSize(width: 360, height: 34) }
        if s.phase == .ready { return NSSize(width: 34, height: 34) }
        return NSSize(width: 34, height: 34)
    }

    /// Lesson summary: header, optional takeaway, optional "you practised", note, buttons.
    static func summaryHeight(_ s: InlineSession) -> CGFloat {
        func lines(_ text: String, _ perLine: Double) -> CGFloat { CGFloat(max(1, Int(ceil(Double(text.count) / perLine)))) }
        var h: CGFloat = 150
        if !s.tip.isEmpty { h += 30 + lines(s.tip, 50) * 18 }
        if let learned = s.learn?.learned, !learned.isEmpty { h += 30 + lines(learned.prefix(5).joined(separator: "  ·  "), 50) * 17 }
        return min(420, h)
    }

    /// Fits the preview: about 52 characters a line at 13.5pt in 388pt.
    static func expandedHeight(_ s: InlineSession) -> CGFloat {
        let text = s.showRemoved ? s.checkedText + " " + s.proposal : (s.proposal.isEmpty ? s.checkedText : s.proposal)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / 52))) }
        let languages: Int = s.showLanguages ? 32 : 0
        let height: Int = 214 + languages + max(3, lines) * 21 + 30
        return min(460, CGFloat(height))
    }

    var body: some View {
        Group {
            if let l = session.learn, l.finished { LearnSummary(session: session) }
            else if session.expanded { ExpandedCompanion(session: session) }
            else { collapsed }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(session.reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: session.expanded)
    }

    private var collapsed: some View {
        HStack(spacing: 6) {
            Button { session.toggleExpanded() } label: { Orb(session: session) }
                .buttonStyle(.plain)
                .help(orbHelp)
                .accessibilityLabel(orbHelp)
            if let toast = session.toast {
                Pill { Text(toast).font(.system(size: 12, weight: .medium)).lineLimit(1) }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            } else if case .done(let msg) = session.phase {
                Pill {
                    HStack(spacing: 8) {
                        Text(msg).font(.system(size: 12, weight: .semibold))
                        if !session.undoStack.isEmpty {
                            Divider().frame(height: 12)
                            Button { session.undo() } label: { HStack(spacing: 4) { Text("Undo").font(.system(size: 12, weight: .semibold)); KeyHint(text: "⌃⌥Z") } }
                                .buttonStyle(.plain).foregroundStyle(Color.brand).accessibilityLabel("Undo")
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else if case .failed(let msg) = session.phase {
                Pill { Text(msg).font(.system(size: 11.5)).lineLimit(1) }
            }
        }
        .padding(4)
    }

    private var orbHelp: String {
        switch session.phase {
        case .checking: return "HeyHumanly is reading this message on your Mac"
        case .ready:
            var parts: [String] = []
            if session.errorCount > 0 { parts.append("\(session.errorCount) fix\(session.errorCount == 1 ? "" : "es")") }
            if session.styleCount > 0 { parts.append("\(session.styleCount) idea\(session.styleCount == 1 ? "" : "s")") }
            return parts.joined(separator: " · ") + ". Click for options"
        case .done: return "All set"
        default: return "HeyHumanly"
        }
    }
}

private struct Pill<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(.horizontal, 11).frame(height: 26)
            .background(Capsule().fill(Color.surface))
            .overlay(Capsule().strokeBorder(Color.ink.opacity(0.10), lineWidth: 0.75))
            .shadow(color: Color.black.opacity(0.16), radius: 2.5, y: 1.2)   // fits the small window
    }
}

/// 26pt mark. Thinking: a soft arc orbiting. Found: count, red if anything is wrong, violet if only ideas. Done: check.
struct Orb: View {
    @ObservedObject var session: InlineSession
    @StateObject private var spin = Flag()
    @StateObject private var pop = Flag()

    var body: some View {
        ZStack {
            switch session.phase {
            case .checking, .idle:
                Circle().fill(Color.surface).overlay(Circle().strokeBorder(Color.ink.opacity(0.10), lineWidth: 0.75))
                Circle().trim(from: 0, to: 0.28).stroke(Color.brand, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .padding(5).rotationEffect(.degrees(spin.on ? 360 : 0))
                    .animation(session.reduceMotion ? nil : .linear(duration: 0.9).repeatForever(autoreverses: false), value: spin.on)
                Circle().fill(Color.brand).frame(width: 5, height: 5)
            case .ready:
                Circle().fill(session.errorCount > 0 ? Color.removed : Color.teach)
                Text("\(session.visible.count)").font(.system(size: 12.5, weight: .bold, design: .rounded)).foregroundStyle(session.errorCount > 0 ? Color.white : Color.onAccent)
                    .contentTransition(.numericText())
            case .done:
                Circle().fill(Color.added)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            case .failed:
                Circle().fill(Color.orange)
                Image(systemName: "exclamationmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
            }
        }
        .frame(width: 26, height: 26)
        // Small enough to fit inside the 34pt window, so it never shows as a clipped grey square.
        .shadow(color: Color.black.opacity(0.18), radius: 2.5, y: 1.2)
        .scaleEffect(pop.on ? 1 : 0.6)
        .opacity(pop.on ? 1 : 0)
        .animation(session.visible.count > 0 ? .spring(response: 0.3, dampingFraction: 0.6) : .default, value: session.visible.count)
        .onAppear {
            spin.on = true
            if session.reduceMotion { pop.on = true } else { withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { pop.on = true } }
        }
    }
}

// MARK: - Expanded: the whole message, tones, translate

private struct ExpandedCompanion: View {
    @ObservedObject var session: InlineSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { session.toggleExpanded() } label: { Orb(session: session) }.buttonStyle(.plain).accessibilityLabel("Collapse")
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text("Read on this Mac only · nothing is saved until you act").font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { session.toggleExpanded() } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary).frame(width: 22, height: 22) }
                    .buttonStyle(.plain).accessibilityLabel("Close")
            }
            .padding(.horizontal, 10).padding(.top, 9).padding(.bottom, 8)

            Divider().opacity(0.6)

            // Tones
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WritingStyle.allCases) { t in Chip(title: t.title, on: session.tone == t) { session.setTone(t) } }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 9)

            // Preview of the message
            ScrollView {
                Group {
                    if session.toneBusy || session.proposal.isEmpty && session.phase == .checking {
                        Shimmer(lines: 3)
                    } else if session.proposal.isEmpty {
                        Text("No version yet.").foregroundStyle(.secondary)
                    } else {
                        Text(Self.preview(old: session.checkedText, new: session.proposal, showRemoved: session.showRemoved))
                    }
                }
                .font(.system(size: 13.5))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.ink.opacity(0.035)))
            .overlay(alignment: .bottomTrailing) {
                if !session.proposal.isEmpty {
                    QuietButton(title: session.showRemoved ? "Hide original" : "Show original", icon: session.showRemoved ? "eye.slash" : "eye") { session.showRemoved.toggle() }
                        .padding(4)
                }
            }
            .padding(.horizontal, 10)

            HStack(spacing: 6) {
                ActionButton(title: "Use this", hint: nil, primary: true) { session.useProposal() }
                    .disabled(session.proposal.isEmpty || session.toneBusy)
                if session.phase == .ready && !session.visible.isEmpty {
                    ActionButton(title: "Fix mistakes only", hint: "⌃⌥↩") { session.fixAll() }
                    ActionButton(title: "Teach me", hint: "⌃⌥L", tint: .teach) { session.startLearn() }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.top, 9)

            HStack(spacing: 2) {
                QuietButton(title: "Pause in \(session.appName)", icon: "pause.circle") { session.pauseThisApp() }
                Spacer()
                if !session.tip.isEmpty {
                    Image(systemName: "lightbulb").font(.system(size: 10)).foregroundStyle(Color.teach)
                    Text(session.tip).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1).help(session.tip)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
        }
        .frame(width: 412, height: CompanionView.expandedHeight(session) - 8, alignment: .topLeading)
        .surface()
        .padding(4)
    }

    /// Clean new text; added runs tinted as one span, removed words only when asked.
    static func preview(old: String, new: String, showRemoved: Bool) -> AttributedString {
        var out = AttributedString()
        var run = "", runKind: WordDiff.Kind = .same
        func flush() {
            guard !run.isEmpty else { return }
            var a = AttributedString(run)
            switch runKind {
            case .added: a.foregroundColor = Color.added; a.underlineStyle = .init(pattern: .solid, color: Color.added.opacity(0.35))
            case .removed: a.foregroundColor = Color.removed.opacity(0.8); a.strikethroughStyle = .single
            case .same: break
            }
            out += a; run = ""
        }
        for p in WordDiff.diff(old, new) {
            if p.kind == .removed && !showRemoved { continue }
            if p.kind != runKind {
                // Keep the trailing space outside the coloured span.
                flush(); runKind = p.kind
            }
            run += p.text
        }
        flush()
        return out
    }

    private var title: String {
        let e = session.errorCount, s = session.styleCount
        if session.phase == .checking { return "Reading your message…" }
        if e == 0 && s == 0 { return "Looks good" }
        var parts: [String] = []
        if e > 0 { parts.append("\(e) mistake\(e == 1 ? "" : "s")") }
        if s > 0 { parts.append("\(s) way\(s == 1 ? "" : "s") to say it better") }
        return parts.joined(separator: " · ")
    }
}

private struct Chip: View {
    let title: String
    var icon: String? = nil
    let on: Bool
    var small = false
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
                Text(title).font(.system(size: small ? 11.5 : 12, weight: on ? .semibold : .medium))
            }
            .foregroundStyle(on ? Color.surface : Color.ink.opacity(0.85))
            .padding(.horizontal, 10).frame(height: small ? 24 : 26)
            .background(Capsule().fill(on ? Color.ink : Color.ink.opacity( hover.on ? 0.10 : 0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain).onHover { hover.on = $0 }
        .accessibilityLabel(title).accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Placeholder lines while a version is being written.
private struct Shimmer: View {
    let lines: Int
    @StateObject private var phase = Value(-1)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<lines, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4).fill(Color.ink.opacity(0.08))
                    .frame(height: 10).frame(maxWidth: i == lines - 1 ? 180 : .infinity, alignment: .leading)
            }
        }
        .mask(LinearGradient(colors: [.black.opacity(0.4), .black, .black.opacity(0.4)], startPoint: UnitPoint(x: phase.v, y: 0), endPoint: UnitPoint(x: phase.v + 1, y: 0)))
        .onAppear { withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase.v = 1 } }
        .accessibilityLabel("Writing")
    }
}

// MARK: - Card under a word (hover or click), and the Learn steps

struct SuggestionCardView: View {
    @ObservedObject var session: InlineSession

    var body: some View {
        VStack(spacing: 0) {
            if !session.cardAbove { arrow(up: true) }
            ScrollView {
                Group {
                    if session.learn != nil, let step = session.learnStep { LearnCard(session: session, step: step) }
                    else if let id = session.openChangeID, let c = session.changes.first(where: { $0.id == id }) { FixCard(session: session, change: c) }
                }
                .frame(width: 356, alignment: .leading)
            }
            .frame(width: 356, alignment: .leading)
            .frame(maxHeight: session.cardMaxHeight - 12)
            .surface()
            if session.cardAbove { arrow(up: false) }
        }
        .padding(.horizontal, 12)
        .frame(width: 380, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func arrow(up: Bool) -> some View {
        Triangle(up: up).fill(Color.surface)
            .overlay(Triangle(up: up).stroke(Color.ink.opacity(0.10), lineWidth: 0.75))
            .frame(width: 14, height: 7)
            .offset(x: session.cardArrowX - 12 - 7, y: up ? 1 : -1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(1)
    }
}

private struct Triangle: Shape {
    var up: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if up { p.move(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)) }
        else { p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)) }
        return p
    }
}

private struct KindTag: View {
    let change: Change
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(change.isError ? Color.removed : Color.teach).frame(width: 6, height: 6)
            Text(change.isError ? "Mistake" : "Style").font(.system(size: 11, weight: .semibold)).foregroundStyle(change.isError ? Color.removed : Color.teach)
            Text("·").foregroundStyle(.tertiary)
            Text(change.pending ? change.category.title : (change.label ?? change.category.title)).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}

private struct BeforeAfter: View {
    let change: Change
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !change.from.isEmpty {
                Text(change.from).strikethrough(color: Color.removed.opacity(0.7)).foregroundStyle(.secondary)
                    .font(.system(size: 13)).lineLimit(3)
            }
            Text(change.to.isEmpty ? "Remove this" : change.to)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(change.to.isEmpty ? Color.removed : Color.ink).lineLimit(4)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct FixCard: View {
    @ObservedObject var session: InlineSession
    let change: Change
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                KindTag(change: change)
                Spacer()
                Button { session.closeCard() } label: { Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.secondary).frame(width: 20, height: 20) }
                    .buttonStyle(.plain).accessibilityLabel("Close")
            }
            if let st = session.step(for: [change.id], bySentence: false), !(st.prefix.isEmpty && st.suffix.isEmpty) {
                // The change in its own words' context, so a small swap still makes sense.
                VStack(alignment: .leading, spacing: 4) {
                    (Text(st.prefix + " ").foregroundStyle(.tertiary) + Text(change.from.isEmpty ? "" : change.from).strikethrough(color: Color.removed.opacity(0.7)).foregroundStyle(.secondary) + Text(" " + st.suffix).foregroundStyle(.tertiary))
                        .font(.system(size: 12.5)).lineLimit(2)
                    (Text(st.prefix + " ").foregroundStyle(.secondary) + Text(change.to.isEmpty ? "(removed)" : change.to).fontWeight(.semibold).foregroundStyle(change.to.isEmpty ? Color.removed : Color.ink) + Text(" " + st.suffix).foregroundStyle(.secondary))
                        .font(.system(size: 14.5)).lineLimit(3)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                BeforeAfter(change: change)
            }
            Group {
                if change.pending { Text("Working out the rule…").foregroundStyle(.tertiary) }
                else {
                    Text(change.label.flatMap { $0 == change.category.title ? nil : "The rule · \($0)" } ?? "The rule").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.teach)
                    Text(change.reason).foregroundStyle(Color.ink.opacity(0.8))
                    if let trick = change.tip { Text(trick).foregroundStyle(.secondary).italic() }
                }
            }
            .font(.system(size: 12.5)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ActionButton(title: "Teach me", primary: true, tint: .teach) { session.startLearn() }
                ActionButton(title: change.to.isEmpty ? "Remove" : "Fix now") { session.accept(change.id) }
                ActionButton(title: "Dismiss", hint: "esc") { session.ignore(change.id) }
                    .help("Hide this suggestion and don't bring it back for these words")
                Spacer(minLength: 0)
            }
            HStack(spacing: 2) {
                if change.category == .spelling, !change.from.contains(" ") {
                    QuietButton(title: "Add “\(change.from.trimmingCharacters(in: .punctuationCharacters))” to dictionary", icon: "plus") { session.addToDictionary(change.id) }
                        .help("It's a real word or a name. Never flag it again")
                }
                QuietButton(title: "Stop flagging \(change.category.title.lowercased())") { session.muteCategory(of: change.id) }
                    .help("Keep fixing it quietly with Fix all, but stop pointing it out")
                Spacer(minLength: 0)
            }
            .padding(.top, -4).padding(.leading, -6)
        }
        .padding(13)
    }
}

private struct LearnCard: View {
    @ObservedObject var session: InlineSession
    let step: InlineSession.LearnStep
    @StateObject private var showAll = Flag()

    var body: some View {
        let l = session.learn ?? InlineSession.LearnState(queue: [], bySentence: true)
        let tryFirst = session.model?.settings.tryFirstInline != false
        let pending = step.changes.contains(where: \.pending)
        let heavy = session.heavyNote(for: step)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("LEARN").font(.system(size: 10.5, weight: .bold)).tracking(0.8).foregroundStyle(Color.teach)
                HStack(spacing: 3) {
                    let total = l.completed + max(0, l.queue.count - l.index)
                    ForEach(0..<min(total, 12), id: \.self) { i in
                        Capsule().fill(i < l.completed ? Color.teach : i == l.completed ? Color.teach.opacity(0.55) : Color.ink.opacity(0.12))
                            .frame(width: i == l.completed ? 14 : 6, height: 6)
                    }
                }
                Spacer()
                QuietButton(title: "Just fix it") { session.showRewrite() }
                Button { session.endLearn() } label: { Image(systemName: "xmark").font(.system(size: 9.5, weight: .bold)).foregroundStyle(.secondary).frame(width: 20, height: 20) }
                    .buttonStyle(.plain).accessibilityLabel("Close lesson").help("Close (esc)")
            }
            HStack(spacing: 5) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, c in
                    HStack(spacing: 4) {
                        Circle().fill(c.isError ? Color.removed : Color.teach).frame(width: 5, height: 5)
                        Text(c.label ?? c.category.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(c.isError ? Color.removed : Color.teach)
                    .padding(.horizontal, 7).frame(height: 20)
                    .background(Capsule().fill((c.isError ? Color.removed : Color.teach).opacity(0.10)))
                    .fixedSize()
                }
                Spacer(minLength: 0)
            }

            if l.picked == nil && tryFirst {
                Text(heavy != nil ? MistakeCategory.clarity.coachHint : (step.changes.first(where: \.isError) ?? step.changes.first)?.category.coachHint ?? "Which one is right?").font(.system(size: 12.5)).foregroundStyle(.secondary)
                HStack {
                    Text("Which one is right?").font(.system(size: 13.5, weight: .semibold))
                    Spacer()
                    QuietButton(title: "Show me") { session.reveal() }.help("Skip the guess and see the answer")
                }
                ForEach(l.betterFirst ? [true, false] : [false, true], id: \.self) { better in
                    OptionButton(text: option(better)) { session.pick(better: better) }
                }
            } else {
                if let picked = l.picked, tryFirst {
                    HStack(spacing: 6) {
                        Image(systemName: picked ? "checkmark.circle.fill" : "arrow.uturn.right.circle.fill")
                        Text(picked ? "Exactly." : "Not quite. This is the better one:")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(picked ? Color.added : Color.orange)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(step.before.trimmingCharacters(in: .whitespacesAndNewlines)).strikethrough(color: Color.removed.opacity(0.6))
                        .foregroundStyle(.secondary).font(.system(size: 12.5))
                    Text(CompanionText.highlighted(old: step.before, new: step.after)).font(.system(size: 14, weight: .medium))
                }
                .fixedSize(horizontal: false, vertical: true)
                if pending {
                    // The answer doesn't wait for the explanation; it fills in when the model is done.
                    HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Working out why…").font(.system(size: 12)).foregroundStyle(.tertiary) }
                }
                if let heavy {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().fill(Color.teach).frame(width: 5, height: 5).offset(y: -2)
                        Text(heavy).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(pending || heavy != nil ? [] : reasons) { c in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle().fill(c.isError ? Color.removed : Color.teach).frame(width: 5, height: 5).offset(y: -2)
                            Text(c.reason).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if heavy == nil, uniqueReasons.count > 3 {
                    QuietButton(title: showAll.on ? "Show fewer" : "Show all \(uniqueReasons.count) reasons", icon: showAll.on ? "chevron.up" : "chevron.down") { showAll.on.toggle(); session.objectWillChange.send() }
                }
                if !pending, heavy == nil, let trick = step.changes.compactMap(\.tip).first {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 10.5)).foregroundStyle(Color.orange)
                        Text(trick).font(.system(size: 12.5, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.09)))
                }
                if l.recall == nil, heavy == nil, let drill = drill {
                    Text(drill.transfer ? "Your turn. Same rule, new sentence: which is right?" : "Your turn. Put the right words back.").font(.system(size: 12.5, weight: .semibold))
                    if !drill.prompt.isEmpty { Text(drill.prompt).font(.system(size: 13.5)).fixedSize(horizontal: false, vertical: true) }
                    ForEach(drill.betterFirst ? [true, false] : [false, true], id: \.self) { right in
                        OptionButton(text: right ? drill.right : drill.wrong) { session.recall(correct: right) }
                    }
                } else {
                    if l.recall == false {
                        Text("Not that one. Read the rule once more; it'll come back in Review so you get another go.")
                            .font(.system(size: 12.5)).foregroundStyle(Color.orange).fixedSize(horizontal: false, vertical: true)
                    } else if l.recall == true {
                        Text("Right. You applied the rule yourself; that's the part that sticks.").font(.system(size: 12.5)).foregroundStyle(Color.added)
                    }
                    HStack(spacing: 6) {
                        ActionButton(title: "Use it", primary: true, tint: .teach) { session.learnUse() }
                        ActionButton(title: "Keep mine") { session.learnKeep() }
                        Spacer(minLength: 0)
                        if let c = step.changes.first { QuietButton(title: "I know this") { session.muteCategory(of: c.id) } }
                    }
                }
            }
            // Footer: where you are, and how the lesson is cut up.
            HStack(spacing: 8) {
                Text("\(l.completed + 1) of \(l.completed + max(1, l.queue.count - l.index))").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Text("Learn by").font(.system(size: 11)).foregroundStyle(.tertiary)
                HStack(spacing: 0) {
                    Segment(title: "Sentence", on: l.bySentence) { if !l.bySentence { session.startLearn(bySentence: true) } }
                    Segment(title: "Word", on: !l.bySentence) { if l.bySentence { session.startLearn(bySentence: false) } }
                }
                .padding(2).background(Capsule().fill(Color.ink.opacity(0.06))).fixedSize()
            }
        }
        .padding(13)
        .animation(session.reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: l.picked)
    }

    /// Mistakes first, one line per distinct reason; three unless expanded.
    private var uniqueReasons: [Change] {
        var seen = Set<String>()
        // Specific reasons (the model's, quoting your words) before generic fallbacks; bigger rewrites before small ones.
        func score(_ c: Change) -> Int {
            (c.reason == c.category.fallbackReason ? 0 : 100) + (c.reason.contains("'") || c.reason.contains("\"") ? 20 : 0) + min(c.from.count + c.to.count, 60) / 6
        }
        return step.changes.sorted { score($0) > score($1) }.filter { seen.insert($0.reason.lowercased()).inserted && !$0.reason.isEmpty }
    }
    private var reasons: [Change] { showAll.on ? uniqueReasons : Array(uniqueReasons.prefix(3)) }

    /// Distinct mistake/style tags for this step (max 3).
    private var tags: [Change] {
        var seen = Set<String>(), out: [Change] = []
        if session.heavyNote(for: step) != nil {
            var c = step.changes[0]; c.kind = "style"; c.label = "Clearer sentence"; return [c]
        }
        for c in step.changes where out.count < 2 {
            let key = (c.isError ? "e" : "s") + (c.label ?? c.category.title)
            if seen.insert(key).inserted { out.append(c) }
        }
        return out
    }

    /// A blanked sentence plus the right wording and the wording they wrote.
    private var drill: (prompt: String, right: String, wrong: String, betterFirst: Bool, transfer: Bool)? {
        // Best practice is the same rule on a sentence they haven't seen.
        if let c = step.changes.first(where: { $0.practiceRight != nil && $0.practiceWrong != nil }) {
            return ("", c.practiceRight!, c.practiceWrong!, c.id.uuid.1 & 1 == 1, true)
        }
        let c = step.changes.max { $0.to.count < $1.to.count }
        guard let c, c.from != c.to else { return nil }
        let after = step.after.trimmingCharacters(in: .whitespacesAndNewlines)
        let blank: String
        if c.to.isEmpty {
            blank = after
        } else if let r = after.range(of: c.to) {
            blank = after.replacingCharacters(in: r, with: "____")
        } else {
            blank = "____"
        }
        let right = c.to.isEmpty ? "(leave it out)" : c.to
        let wrong = c.from.isEmpty ? "(leave it out)" : c.from
        guard right != wrong else { return nil }
        // A short replacement that appears twice ("I", "to") would blank the wrong spot.
        if !c.to.isEmpty && after.components(separatedBy: c.to).count != 2 { return ( "Which wording is the fix?", right, wrong, step.changes[0].id.uuid.0 & 1 == 1, false) }
        let prompt = c.to.isEmpty ? "This bit shouldn't be there. What do you do with \"\(c.from)\"?" : blank
        return (prompt, right, wrong, step.changes[0].id.uuid.0 & 1 == 1, false)
    }

    private func option(_ better: Bool) -> String {
        let core = (better ? step.after : step.before).trimmingCharacters(in: .whitespacesAndNewlines)
        return [step.prefix, core.isEmpty ? "(nothing)" : core, step.suffix].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

private struct Segment: View {
    let title: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 11, weight: on ? .semibold : .medium))
                .foregroundStyle(on ? Color.ink : Color.secondary)
                .padding(.horizontal, 8).frame(height: 20)
                .background(Capsule().fill(on ? Color.surface : Color.clear).shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1.5, y: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityLabel("Learn by \(title.lowercased())").accessibilityAddTraits(on ? .isSelected : [])
    }
}

enum CompanionText {
    /// The new text with the parts that changed tinted.
    static func highlighted(old: String, new: String) -> AttributedString {
        var out = AttributedString()
        for p in WordDiff.diff(old.trimmingCharacters(in: .whitespacesAndNewlines), new.trimmingCharacters(in: .whitespacesAndNewlines)) where p.kind != .removed {
            var a = AttributedString(p.text)
            if p.kind == .added { a.foregroundColor = Color.teach }
            out += a
        }
        return out
    }
}

private struct LearnSummary: View {
    @ObservedObject var session: InlineSession
    var body: some View {
        let l = session.learn ?? InlineSession.LearnState(queue: [], bySentence: true)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap.fill").foregroundStyle(Color.teach)
                Text("Lesson done").font(.system(size: 14, weight: .semibold))
                Spacer()
                if l.answered > 0 {
                    Text("\(l.right) of \(l.answered) right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.added)
                }
            }
            if !session.tip.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("One thing to remember").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Text(session.tip).font(.system(size: 13)).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !l.learned.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("You practised").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Text(l.learned.prefix(5).joined(separator: "  ·  ")).font(.system(size: 12.5, weight: .medium)).foregroundStyle(Color.teach)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Saved to Review. HeyHumanly brings these back in a few days so they stick.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                if !session.undoStack.isEmpty { ActionButton(title: "Undo last") { session.undo() } }
                Spacer()
                ActionButton(title: "Done", primary: true, tint: .teach) { session.endLearn() }
            }
        }
        .padding(14)
        .frame(width: 372, height: CompanionView.summaryHeight(session) - 8, alignment: .topLeading)
        .surface()
        .padding(4)
    }
}

/// Local view state without the @State macro (not available in this toolchain).
final class Flag: ObservableObject { @Published var on = false }
final class Value: ObservableObject { @Published var v: CGFloat; init(_ v: CGFloat) { self.v = v } }

private struct OptionButton: View {
    let text: String
    let action: () -> Void
    @StateObject private var hover = Flag()
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 13.5)).foregroundStyle(Color.ink).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.ink.opacity(hover.on ? 0.08 : 0.04)))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(hover.on ? Color.teach.opacity(0.7) : Color.ink.opacity(0.08), lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hover.on = $0 }
        .accessibilityLabel(text)
    }
}
