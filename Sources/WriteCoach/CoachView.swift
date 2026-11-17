import SwiftUI
import AppKit

/// Spotlight-style floating coach: write or capture text, pick a mode, review the diff, copy or replace.
struct CoachPanelView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hairline)
            if model.rephraseOn {
                RephrasePane(model: model)
            } else if model.result.rewrite.isEmpty && !model.isLoading {
                // Composing: the editor fills the panel.
                VStack(alignment: .leading, spacing: 12) {
                    if let prompt = model.practicePrompt { practiceBanner(prompt) }
                    editor.frame(maxHeight: .infinity)
                    if let error = model.errorMessage { banner(error, icon: "exclamationmark.triangle.fill", tint: .removed) }
                }
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let prompt = model.practicePrompt { practiceBanner(prompt) }
                        compactOriginal
                        if model.isLoading { loadingCard } else { resultCard }
                        if let error = model.errorMessage { banner(error, icon: "exclamationmark.triangle.fill", tint: .removed) }
                    }
                    .padding(16)
                }
            }
            Divider().overlay(Color.hairline)
            if model.rephraseOn { RephrasePane.footer(model) } else { footer }
        }
        .frame(minWidth: 520, minHeight: 360)
        .background(Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.hairline))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("HeyHumanly").font(.system(size: 13, weight: .semibold))
                Text(model.sourceAppName.map { "From \($0)" } ?? "Writing coach")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if !model.rephraseOn { styleMenu }
            modePicker
            Button { model.closeCoach() } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                    .frame(width: 24, height: 24).background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain).help("Close (Esc)").accessibilityLabel("Close coach")
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
    }

    private var styleMenu: some View {
        Menu {
            ForEach(WritingStyle.allCases) { style in
                Button { model.selectedStyle = style } label: {
                    Label("\(style.rawValue) — \(style.blurb)", systemImage: model.selectedStyle == style ? "checkmark" : style.icon)
                }
            }
        } label: {
            Label(model.selectedStyle.rawValue, systemImage: model.selectedStyle.icon)
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("How much HeyHumanly may change: \(model.selectedStyle.blurb)")
        .accessibilityLabel("Style: \(model.selectedStyle.rawValue)")
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            rephraseTab
            modeTab(.quickFix, title: "Quick Fix", icon: "bolt.fill", tint: .brand)
            modeTab(.teach, title: "Teach Me", icon: "graduationcap.fill", tint: .teach)
        }
        .padding(3)
        .background(Color.primary.opacity(0.06), in: Capsule())
    }

    private var rephraseTab: some View {
        let selected = model.rephraseOn
        return Button { model.rephraseOn = true } label: {
            Label("Rephrase", systemImage: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? Color.teach : .secondary)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(selected ? Color.surface : .clear, in: Capsule())
                .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain).accessibilityLabel("Rephrase mode").accessibilityAddTraits(selected ? .isSelected : [])
        .help("Rewrite for clarity and learn why")
    }

    private func modeTab(_ mode: CoachMode, title: String, icon: String, tint: Color) -> some View {
        let selected = model.selectedMode == mode && !model.rephraseOn
        return Button { model.selectedMode = mode; model.rephraseOn = false } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? tint : .secondary)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(selected ? Color.surface : .clear, in: Capsule())
                .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) mode")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(mode == .teach ? "Fix it, explain why, and give an exercise" : "Fix spelling, grammar and clarity right away")
    }

    // MARK: Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $model.draft)
                .modifier(NoSystemWritingTools())
                .font(.system(size: 15))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8).padding(.vertical, 10)
                .frame(minHeight: model.result.rewrite.isEmpty && !model.isLoading ? 120 : 64, maxHeight: model.result.rewrite.isEmpty && !model.isLoading ? .infinity : 104)
                .accessibilityLabel("Text to coach")
            if model.draft.isEmpty {
                Text(model.practicePrompt == nil
                     ? "Type or paste text, or select text in any app and press \(model.shortcutLabel)…"
                     : "Write your answer here, then run Quick Fix to check it…")
                    .font(.system(size: 15)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
    }

    /// Once there is a result, the input collapses to two lines so the coaching gets the space.
    private var compactOriginal: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("YOUR TEXT").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.tertiary)
                Text(model.currentItem?.original ?? model.draft).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button("Edit") { model.editAgain() }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.brand)
                .disabled(model.isLoading).accessibilityLabel("Edit text")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func practiceBanner(_ prompt: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "target").foregroundStyle(Color.teach)
            VStack(alignment: .leading, spacing: 3) {
                Text("Exercise").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.teach)
                Text(prompt).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button { model.practicePrompt = nil } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Dismiss exercise")
        }
        .padding(12)
        .background(Color.teach.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Result

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(model.loadingMode == .teach ? "Correcting, then preparing your lesson…" : "Fixing your text…")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                Spacer()
                Text("on \(model.settings.model) · this Mac").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            if !model.streamingText.isEmpty {
                (Text(Services_clean(model.streamingText)) + Text(" ▍").foregroundColor(.brand))
                    .font(.system(size: 16)).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
    }

    private var resultCard: some View {
        let mode = model.resultMode ?? .quickFix
        let original = model.currentItem?.original ?? model.draft
        let changes = model.visibleChanges
        let quiet = model.quietChanges
        let accepted = changes.filter { model.acceptedChanges.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ModeBadge(mode: mode)
                if let style = model.currentItem?.style {
                    Label(style.rawValue, systemImage: style.icon).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.tryFirst.toggle() } label: {
                    Label("Try first", systemImage: "scope")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(model.tryFirst ? Color.teach.opacity(0.15) : Color.ink.opacity(0.05), in: Capsule())
                        .foregroundStyle(model.tryFirst ? Color.teach : .secondary)
                }
                .buttonStyle(.plain)
                .help("Find the mistakes yourself before HeyHumanly shows them")
                .accessibilityLabel("Try first mode \(model.tryFirst ? "on" : "off")")
                if changes.isEmpty && quiet.isEmpty {
                    Label("Looks good, nothing to fix", systemImage: "checkmark.seal.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.added)
                } else if changes.isEmpty {
                    Text("\(quiet.count) quiet fix\(quiet.count == 1 ? "" : "es") applied").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                } else {
                    Text("\(accepted) of \(changes.count) changes applied").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            if !model.spotRevealed {
                SpotView(model: model)
            } else {
            if model.tryFirst && !model.spotPicked.isEmpty { SpotScore(model: model) }
            Text(WordDiff.attributed(original, model.finalText, showRemoved: model.showRemovedWords))
                .font(.system(size: 16)).lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(model.finalText)

            if model.quiz != nil { QuizView(model: model) }

            if !changes.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                        if index > 0 { Divider().overlay(Color.hairline) }
                        ChangeRow(change: change, accepted: model.acceptedChanges.contains(change.id),
                                  explaining: model.explaining && change.pending,
                                  mute: { model.setMuted(change.category, true) }) { model.toggleChange(change.id) }
                    }
                }
                .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.hairline))
                if !quiet.isEmpty { quietRow(quiet) }
                HStack(spacing: 12) {
                    Button(accepted == changes.count ? "Undo all" : "Accept all") { model.setAllChanges(accepted != changes.count) }
                        .buttonStyle(.link).font(.system(size: 11.5)).accessibilityLabel(accepted == changes.count ? "Undo all changes" : "Accept all changes")
                    Toggle("Show removed words", isOn: $model.showRemovedWords)
                        .toggleStyle(.checkbox).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    if model.explaining {
                        HStack(spacing: 5) { ProgressView().controlSize(.mini); Text("Explaining…") }
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    } else if model.quiz == nil, changes.contains(where: { !$0.from.isEmpty && !$0.to.isEmpty && $0.from.lowercased() != $0.to.lowercased() }) {
                        Button { model.startQuiz() } label: { Label("Quiz me", systemImage: "brain.head.profile") }
                            .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Quiz me on these mistakes")
                    }
                }
            }

            if !model.styleFindings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .lastTextBaseline) {
                        Eyebrow(text: "Make it better", color: .teach)
                        Text("\(model.styleFindings.count) idea\(model.styleFindings.count == 1 ? "" : "s") beyond corrections")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    ForEach(model.styleFindings) { finding in
                        StyleCard(model: model, finding: finding)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity.combined(with: .scale(scale: 0.96))))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.styleFindings.map(\.id))
            }
            }

            if mode == .teach, model.lessonLoading {
                HStack(spacing: 6) { ProgressView().controlSize(.mini); Text("Writing your lesson…") }
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if mode == .teach, !model.result.explanation.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Lesson", systemImage: "lightbulb.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange)
                    ForEach(Array(Self.sentences(model.result.explanation).enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4).offset(y: -2)
                            Text(line).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if mode == .teach, !model.result.exercise.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Try this", systemImage: "target").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.teach)
                    Text(model.result.exercise).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                    Button("Practice now") { if let item = model.currentItem { model.practice(item) } }
                        .buttonStyle(.link).font(.system(size: 12, weight: .medium)).accessibilityLabel("Practice now")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.teach.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
    }

    /// Fixes in categories the user already knows: applied, summarised in one line.
    private func quietRow(_ quiet: [Change]) -> some View {
        let names = Array(Set(quiet.map { $0.category.title.lowercased() })).sorted().joined(separator: ", ")
        return VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.easeOut(duration: 0.2)) { model.showQuietFixes.toggle() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash").font(.system(size: 11))
                    Text("\(quiet.count) quiet fix\(quiet.count == 1 ? "" : "es") applied (\(names))")
                    Spacer()
                    Image(systemName: model.showQuietFixes ? "chevron.up" : "chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 12)).foregroundStyle(.secondary).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("\(quiet.count) quiet fixes applied")
            if model.showQuietFixes {
                ForEach(quiet) { c in
                    HStack(spacing: 6) {
                        Text(c.from).strikethrough().foregroundStyle(Color.removed)
                        Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(c.to).foregroundStyle(Color.added)
                        Spacer()
                        Button("Teach me again") { model.setMuted(c.category, false) }.buttonStyle(.link).font(.system(size: 11))
                            .accessibilityLabel("Teach me \(c.category.title) again")
                    }
                    .font(.system(size: 12.5))
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Splits a model explanation into sentences for a bullet list.
    static func sentences(_ text: String) -> [String] {
        var out: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sub, _, _, _ in
            if let s = sub?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { out.append(s) }
        }
        return out.isEmpty ? [text] : out
    }

    private func banner(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if text.contains("Accessibility") {
                Button("Open Settings") { AccessibilityBridge.openSystemSettings() }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Open Accessibility Settings")
            }
        }
        .padding(12)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 10) {
            if let status = model.statusMessage {
                Label(status, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.added)
            } else {
                HStack(spacing: 5) {
                    KeyCap(key: "⌘", size: 10); KeyCap(key: "↩", size: 10)
                    Text("run").font(.system(size: 11)).foregroundStyle(.secondary)
                    KeyCap(key: "esc", size: 10).padding(.leading, 6)
                    Text("close").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !model.draft.isEmpty || !model.result.rewrite.isEmpty {
                Button("Clear") { model.clearDraft() }.buttonStyle(.plain)
                    .font(.system(size: 12)).foregroundStyle(.secondary).accessibilityLabel("Clear")
            }
            if !model.result.rewrite.isEmpty && !model.isLoading {
                Button { model.copyRewrite() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Copy rewrite")
                if let source = model.sourceAppName {
                    Button { model.apply() } label: { Label("Replace in \(source)", systemImage: "arrow.uturn.left") }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Replace selected text")
                } else {
                    runButton(secondary: true)
                }
            } else {
                runButton(secondary: false)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder
    private func runButton(secondary: Bool) -> some View {
        let teach = model.selectedMode == .teach
        let title = model.isLoading ? "Working…" : (secondary ? "Run again" : (teach ? "Teach me" : "Fix it"))
        let button = Button { model.run() } label: {
            HStack(spacing: 6) {
                if model.isLoading { ProgressView().controlSize(.mini) }
                else { Image(systemName: teach ? "graduationcap.fill" : "bolt.fill") }
                Text(title)
            }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(model.isLoading || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel(teach ? "Teach Me" : "Quick Fix")
        if secondary { button.buttonStyle(SecondaryButtonStyle()) }
        else { button.buttonStyle(PrimaryButtonStyle(tint: teach ? .teach : .brand)) }
    }
}


/// One reviewable change: category, before → after, reason, accept/undo.
struct ChangeRow: View {
    let change: Change
    let accepted: Bool
    let explaining: Bool
    var mute: (() -> Void)? = nil
    let toggle: () -> Void
    /// Capital letters and punctuation get a compact row; the reason is in the tooltip.
    private var minor: Bool { change.category == .capitalization || change.category == .punctuation }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: change.category.icon)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(change.category.color)
                .frame(width: 24, height: 24)
                .background(change.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if !change.from.isEmpty {
                        Text(change.from).strikethrough(accepted).foregroundStyle(accepted ? Color.removed : .primary)
                    }
                    if !change.from.isEmpty && !change.to.isEmpty {
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    }
                    if !change.to.isEmpty {
                        Text(change.to).foregroundStyle(accepted ? Color.added : .secondary).strikethrough(!accepted)
                    }
                    Text(change.category.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(change.category.color)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(change.category.color.opacity(0.10), in: Capsule())
                }
                .font(.system(size: 13, weight: .medium))
                if explaining {
                    Text("Explaining…").font(.system(size: 11.5)).foregroundStyle(.tertiary)
                } else if !change.reason.isEmpty && !minor {
                    Text(change.reason).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            if let mute {
                Menu {
                    Button("I know \(change.category.title.lowercased()) — fix it quietly from now on", action: mute)
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary).frame(width: 22, height: 22)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .help("Stop showing \(change.category.title.lowercased()) fixes")
                .accessibilityLabel("Options for \(change.category.title) fix")
            }
            Button(action: toggle) {
                Image(systemName: accepted ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                    .font(.system(size: 17)).foregroundStyle(accepted ? Color.added : .secondary)
            }
            .buttonStyle(.plain)
            .help(accepted ? "Undo this change" : "Apply this change")
            .accessibilityLabel(accepted ? "Undo change \(change.from) to \(change.to)" : "Apply change \(change.from) to \(change.to)")
        }
        .padding(.horizontal, 12).padding(.vertical, minor ? 6 : 10)
        .opacity(accepted ? 1 : 0.65)
        .help(change.reason)
    }
}

/// Streaming text with any leading label/quote stripped, for the live preview.
func Services_clean(_ s: String) -> String { CoachService.cleanRewrite(s) }

/// macOS puts its own Writing Tools button on text editors; in a writing coach it only gets in the way.
struct NoSystemWritingTools: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) { content.writingToolsBehavior(.disabled) } else { content }
    }
}
