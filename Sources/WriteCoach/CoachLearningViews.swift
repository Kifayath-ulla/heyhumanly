import SwiftUI

/// Wrapping row layout for word chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 { x = 0; y += line + lineSpacing; line = 0 }
            x += s.width + spacing; line = max(line, s.height)
        }
        return CGSize(width: width, height: y + line)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += line + lineSpacing; line = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; line = max(line, s.height)
        }
    }
}

// MARK: - Try first

struct SpotView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        let words = model.spotWords
        let total = words.filter(\.wrong).count
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "scope").foregroundStyle(Color.teach)
                Text("Try first").font(.system(size: 12, weight: .bold)).tracking(0.8).foregroundStyle(Color.teach)
                Spacer()
                Text("\(model.spotPicked.count) picked").font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Text("I found \(total) thing\(total == 1 ? "" : "s") to fix. Tap the words you think are wrong.")
                .font(.serif(19)).foregroundStyle(Color.ink)
            FlowLayout(spacing: 6, lineSpacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let picked = model.spotPicked.contains(index)
                    Button { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { model.toggleSpot(index) } } label: {
                        Text(word.text)
                            .font(.system(size: 15))
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(picked ? Color.teach.opacity(0.18) : Color.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(picked ? Color.teach : .clear, lineWidth: 1.2))
                            .foregroundStyle(Color.ink)
                            .scaleEffect(picked ? 1.04 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(word.text)\(picked ? ", picked" : "")")
                }
            }
            HStack {
                Button("Skip") { model.revealSpot() }.buttonStyle(.plain).font(.system(size: 12.5)).foregroundStyle(.secondary)
                Spacer()
                Button { model.revealSpot() } label: { Label("Check my picks", systemImage: "eye") }
                    .buttonStyle(PrimaryButtonStyle(tint: .teach)).disabled(model.spotPicked.isEmpty)
                    .accessibilityLabel("Check my picks")
            }
        }
    }
}

/// Shown after revealing: how many mistakes the user found on their own.
struct SpotScore: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        let words = model.spotWords
        let wrong = Set(words.indices.filter { words[$0].wrong })
        let hits = model.spotPicked.intersection(wrong).count
        let misses = model.spotPicked.subtracting(wrong).count
        HStack(spacing: 10) {
            Mascot(size: 30, mood: hits == wrong.count ? .proud : .happy)
            VStack(alignment: .leading, spacing: 2) {
                Text(hits == wrong.count ? "You spotted all \(wrong.count)!" : "You spotted \(hits) of \(wrong.count)")
                    .font(.system(size: 13.5, weight: .semibold))
                Text(misses > 0 ? "\(misses) word\(misses == 1 ? " was" : "s were") fine as written." : "Look at the ones you missed below.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.teach.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Make it better

struct StyleCard: View {
    @ObservedObject var model: CoachModel
    let finding: StyleFinding

    var body: some View {
        let lessonOpen = model.openLesson == finding.id
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: finding.kind.icon).font(.system(size: 11, weight: .bold)).foregroundStyle(finding.kind.color)
                    .frame(width: 24, height: 24).background(finding.kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(finding.kind.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(finding.kind.color)
                Spacer()
                Button(lessonOpen ? "Hide" : "Why?") { withAnimation(.easeOut(duration: 0.2)) { model.openLesson = lessonOpen ? nil : finding.id } }
                    .buttonStyle(.plain).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color.brand)
                    .accessibilityLabel("Why: \(finding.kind.title)")
                Button { withAnimation { model.dismissStyle(finding) } } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                    .buttonStyle(.plain).foregroundStyle(.tertiary).accessibilityLabel("Dismiss suggestion")
            }
            Text(finding.message).font(.system(size: 13)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)

            if lessonOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Text(finding.kind.lesson).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 8) {
                        Text("✗").foregroundStyle(Color.removed).font(.system(size: 12, weight: .bold))
                        Text(finding.kind.example.before).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 8) {
                        Text("✓").foregroundStyle(Color.added).font(.system(size: 12, weight: .bold))
                        Text(finding.kind.example.after).font(.system(size: 12.5, weight: .medium))
                    }
                }
                .padding(10)
                .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if model.proposedRewrites[finding.id] == nil, let preview = model.quickEditPreview(finding) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WordDiff.attributed(preview.before, preview.after, showRemoved: true)).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Use this") { withAnimation { model.applyQuickEdit(finding) } }.buttonStyle(PrimaryButtonStyle(tint: .teach)).accessibilityLabel("Use this fix")
                        Button {
                            model.proposeRewrite(finding)
                        } label: {
                            HStack(spacing: 6) {
                                if model.styleBusy == finding.id { ProgressView().controlSize(.mini) }
                                Text(model.styleBusy == finding.id ? "Rewriting…" : "Another way")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle()).disabled(model.styleBusy != nil).accessibilityLabel("Rewrite another way")
                    }
                }
                .padding(10)
                .background(Color.teach.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if let proposal = model.proposedRewrites[finding.id] {
                VStack(alignment: .leading, spacing: 8) {
                    let ns = model.finalText as NSString
                    let range = NSRange(location: finding.sentenceLocation, length: finding.sentenceLength)
                    let sentence = NSMaxRange(range) <= ns.length ? ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    Text(WordDiff.attributed(sentence, proposal)).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Use this") { withAnimation { model.acceptRewrite(finding) } }.buttonStyle(PrimaryButtonStyle(tint: .teach)).accessibilityLabel("Use rewrite")
                        Button("Try again") { model.proposeRewrite(finding) }.buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Try another rewrite")
                    }
                }
                .padding(10)
                .background(Color.teach.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if !finding.replacements.isEmpty {
                HStack(spacing: 6) {
                    ForEach(finding.replacements, id: \.self) { rep in
                        Button { withAnimation { model.applyStyle(finding, replacement: rep) } } label: {
                            Text(rep.isEmpty ? "Remove “\(finding.matched)”" : "→ \(rep)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.teach.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.teach)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(rep.isEmpty ? "Remove \(finding.matched)" : "Replace with \(rep)")
                    }
                }
            } else {
                Button {
                    model.proposeRewrite(finding)
                } label: {
                    HStack(spacing: 6) {
                        if model.styleBusy == finding.id { ProgressView().controlSize(.mini) } else { Image(systemName: "wand.and.stars") }
                        Text(model.styleBusy == finding.id ? "Rewriting…" : "Rewrite this sentence")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.styleBusy != nil)
                .accessibilityLabel("Rewrite this sentence")
            }
        }
        .padding(14)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.teach.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Quiz

struct QuizView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        if let q = model.quiz {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Quick quiz", systemImage: "brain.head.profile").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.teach)
                    Spacer()
                    if !q.finished {
                        HStack(spacing: 4) {
                            ForEach(0..<q.items.count, id: \.self) { i in
                                Capsule().fill(i < q.index ? Color.teach : (i == q.index ? Color.teach.opacity(0.5) : Color.ink.opacity(0.1)))
                                    .frame(width: i == q.index ? 18 : 8, height: 6)
                            }
                        }
                    }
                    Button { model.closeQuiz() } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Close quiz")
                }
                if let item = q.current {
                    Text("Which is correct here?").font(.serif(20))
                    Text(context(for: item)).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    HStack(spacing: 10) {
                        ForEach(item.options, id: \.self) { option in
                            optionButton(option, item: item, picked: q.picked)
                        }
                    }
                    if let picked = q.picked {
                        let right = picked == item.change.to
                        VStack(alignment: .leading, spacing: 6) {
                            Label(right ? "Nice — that's it." : "Not quite. It's “\(item.change.to)”.", systemImage: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(right ? Color.added : Color.removed)
                            if !item.change.reason.isEmpty { Text(item.change.reason).font(.system(size: 12.5)).foregroundStyle(.secondary) }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        HStack {
                            Spacer()
                            Button(q.index + 1 < q.items.count ? "Next" : "Finish") { model.nextQuiz() }
                                .buttonStyle(PrimaryButtonStyle(tint: .teach)).keyboardShortcut(.return, modifiers: [])
                                .accessibilityLabel("Next question")
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Mascot(size: 44, mood: q.correct == q.items.count ? .proud : .happy)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(q.correct) of \(q.items.count) right").font(.serif(22))
                            Text(q.correct == q.items.count ? "You've got these. They'll come back in Review to make sure they stick." : "The ones you missed are queued in Review.")
                                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Done") { model.closeQuiz() }.buttonStyle(PrimaryButtonStyle(tint: .teach)).accessibilityLabel("Done")
                    }
                }
            }
            .padding(16)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.teach.opacity(0.25), lineWidth: 1))
            .shadow(color: Color.teach.opacity(0.15), radius: 14, y: 6)
        }
    }

    private func context(for item: QuizItem) -> String {
        let original = model.currentItem?.original ?? model.draft
        let ns = original as NSString
        guard let loc = item.change.location, let len = item.change.length, loc + len <= ns.length else { return "" }
        let start = max(0, loc - 40), end = min(ns.length, loc + len + 40)
        let before = ns.substring(with: NSRange(location: start, length: loc - start))
        let after = ns.substring(with: NSRange(location: loc + len, length: end - loc - len))
        return (start > 0 ? "…" : "") + before + "____" + after + (end < ns.length ? "…" : "")
    }

    private func optionButton(_ option: String, item: QuizItem, picked: String?) -> some View {
        let isRight = option == item.change.to
        let chosen = picked == option
        let fill: Color = picked == nil ? Color.ink.opacity(0.05) : (isRight ? Color.added.opacity(0.15) : (chosen ? Color.removed.opacity(0.15) : Color.ink.opacity(0.04)))
        let stroke: Color = picked == nil ? Color.hairline : (isRight ? Color.added : (chosen ? Color.removed : .clear))
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { model.answerQuiz(option) } } label: {
            Text(option).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(stroke, lineWidth: 1.4))
        }
        .buttonStyle(.plain)
        .disabled(picked != nil)
        .accessibilityLabel("Answer \(option)")
    }
}
