import SwiftUI
import Foundation

struct QuizItem: Identifiable {
    let id = UUID()
    let change: Change
    let options: [String]
}

struct QuizState {
    var items: [QuizItem]
    var index = 0
    var picked: String?
    var correct = 0
    var current: QuizItem? { index < items.count ? items[index] : nil }
    var finished: Bool { index >= items.count }
}

extension CoachModel {
    /// Back to editing the original text (keeps the draft, drops the result).
    func editAgain() {
        draft = currentItem?.original ?? draft
        result = .empty; resultMode = nil; changeSet = ChangeSet(); acceptedChanges = []
        styleFindings = []; proposedRewrites = [:]; quiz = nil; spotRevealed = true; statusMessage = nil
        currentItem = nil
    }

    // MARK: Make it better

    func refreshStyle() {
        let style = currentItem?.style ?? selectedStyle
        styleFindings = finalText.isEmpty ? [] : StyleChecker.check(finalText, style: style)
        proposedRewrites = proposedRewrites.filter { id, _ in styleFindings.contains { $0.id == id } }
    }

    /// Applies a word-level style fix on top of the current result.
    func applyStyle(_ finding: StyleFinding, replacement: String) {
        rebase(to: StyleChecker.apply(finding, replacement: replacement, to: finalText), because: finding)
    }

    func proposeRewrite(_ finding: StyleFinding) {
        let ns = finalText as NSString
        let range = NSRange(location: finding.sentenceLocation, length: finding.sentenceLength)
        guard NSMaxRange(range) <= ns.length else { return }
        let sentence = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isOnline else {
            errorMessage = "Sentence rewrites only run on this Mac. Edit it yourself, or enable offline coaching in Settings."
            return
        }
        styleBusy = finding.id
        let endpoint = activeEndpoint, modelName = activeModel
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Rewriting sentence")
        Task {
            defer { ProcessInfo.processInfo.endActivity(activity) }
            let rewritten = await CoachService.rewriteSentence(sentence, issue: finding, endpoint: endpoint, model: modelName)
            styleBusy = nil
            if let rewritten { proposedRewrites[finding.id] = rewritten }
            else { statusMessage = nil; errorMessage = "The model couldn't find a better version this time. Try again, or edit it yourself." }
        }
    }

    func acceptRewrite(_ finding: StyleFinding) {
        guard let rewritten = proposedRewrites[finding.id] else { return }
        let ns = finalText as NSString
        let range = NSRange(location: finding.sentenceLocation, length: finding.sentenceLength)
        guard NSMaxRange(range) <= ns.length else { return }
        let original = ns.substring(with: range)
        // Keep the sentence's trailing whitespace.
        let trailing = String(original.reversed().prefix { $0.isWhitespace }.reversed())
        rebase(to: ns.replacingCharacters(in: range, with: rewritten + trailing), because: finding)
    }

    /// Applies a finding's known-good deterministic edit (e.g. "say it once").
    func applyQuickEdit(_ finding: StyleFinding) {
        guard let edit = finding.quickEdit else { return }
        let ns = finalText as NSString
        guard edit.location + edit.length <= ns.length else { return }
        var text = ns.replacingCharacters(in: NSRange(location: edit.location, length: edit.length), with: edit.text)
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        rebase(to: text, because: finding)
    }

    /// Preview of the sentence after the deterministic edit.
    func quickEditPreview(_ finding: StyleFinding) -> (before: String, after: String)? {
        guard let edit = finding.quickEdit else { return nil }
        let ns = finalText as NSString
        let sentence = NSRange(location: finding.sentenceLocation, length: finding.sentenceLength)
        let start = min(sentence.location, edit.location)
        let end = max(NSMaxRange(sentence), edit.location + edit.length)
        guard end <= ns.length else { return nil }
        let span = NSRange(location: start, length: end - start)
        let before = ns.substring(with: span)
        let local = NSRange(location: edit.location - start, length: edit.length)
        let after = (before as NSString).replacingCharacters(in: local, with: edit.text)
        return (before.trimmingCharacters(in: .whitespacesAndNewlines), after.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func dismissStyle(_ finding: StyleFinding) {
        styleFindings.removeAll { $0.id == finding.id }
        proposedRewrites[finding.id] = nil
    }

    /// Makes `text` the new result: corrections + style edits are re-diffed against the original, so
    /// everything stays reviewable in one list and in history.
    func rebase(to text: String, because finding: StyleFinding? = nil) {
        let original = currentItem?.original ?? draft
        let old = changeSet.changes
        var set = ChangeSet(original: original, rewrite: text)
        for i in set.changes.indices {
            if let match = old.first(where: { $0.from == set.changes[i].from && $0.to == set.changes[i].to }) {
                set.changes[i].category = match.category; set.changes[i].reason = match.reason; set.changes[i].pending = false
            } else {
                set.changes[i].pending = false
                set.changes[i].category = finding?.kind == .wordy ? .wordChoice : .clarity
                set.changes[i].reason = finding.map { "\($0.kind.title): \($0.kind.lesson.components(separatedBy: ". ").first ?? "")." } ?? "Clearer wording."
            }
        }
        changeSet = set
        acceptedChanges = Set(set.changes.map(\.id))
        result = CoachResult(rewrite: text, explanation: result.explanation, exercise: result.exercise)
        if let item = currentItem, let index = history.firstIndex(where: { $0.id == item.id }) {
            let updated = HistoryItem(copying: history[index], result: result)
            var withChanges = updated; withChanges.changes = set.changes
            history[index] = withChanges; currentItem = withChanges
            HistoryItem.saveAll(history)
        }
        refreshStyle()
        statusMessage = nil
    }

    // MARK: Try first (spot the mistakes)

    /// Word ranges of the original text, and which of them contain a mistake.
    var spotWords: [(text: String, wrong: Bool)] {
        let original = currentItem?.original ?? draft
        let ns = original as NSString
        let targets = visibleChanges.compactMap { c -> NSRange? in
            guard let loc = c.location, let len = c.length, len > 0 else { return nil }
            return NSRange(location: loc, length: len)
        }
        var out: [(String, Bool)] = []
        var last = 0
        for r in StyleChecker.wordRanges(ns) {
            // Attach punctuation that follows a word to it, so chips read naturally.
            let gap = ns.substring(with: NSRange(location: last, length: r.location - last)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !gap.isEmpty, !out.isEmpty { out[out.count - 1].0 += gap }
            out.append((ns.substring(with: r), targets.contains { NSIntersectionRange($0, r).length > 0 }))
            last = NSMaxRange(r)
        }
        let tail = ns.substring(from: last).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty, !out.isEmpty { out[out.count - 1].0 += tail }
        return out
    }

    func toggleSpot(_ index: Int) {
        if spotPicked.contains(index) { spotPicked.remove(index) } else { spotPicked.insert(index) }
    }

    func revealSpot() { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { spotRevealed = true } }

    // MARK: Quiz

    func startQuiz() {
        // Real learning first: spelling, grammar and word choice; punctuation only to fill up.
        let rank: (MistakeCategory) -> Int = { [.verbForm, .grammar, .spelling, .wordChoice].contains($0) ? 0 : 1 }
        let items = visibleChanges
            .filter { !$0.from.isEmpty && !$0.to.isEmpty && $0.from.lowercased() != $0.to.lowercased() }
            .sorted { rank($0.category) < rank($1.category) }
            .prefix(5)
            .map { QuizItem(change: $0, options: [$0.from, $0.to].shuffled()) }
        guard !items.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { quiz = QuizState(items: Array(items)) }
    }

    func answerQuiz(_ option: String) {
        guard var q = quiz, let item = q.current, q.picked == nil else { return }
        q.picked = option
        let right = option == item.change.to
        if right { q.correct += 1 }
        // Counts as practice for the matching review card.
        if let i = reviews.firstIndex(where: { $0.from.lowercased() == item.change.from.lowercased() && $0.to.lowercased() == item.change.to.lowercased() }) {
            reviews[i].record(correct: right); ReviewItem.saveAll(reviews)
        }
        quiz = q
    }

    func nextQuiz() {
        guard var q = quiz else { return }
        q.index += 1; q.picked = nil
        withAnimation(.easeOut(duration: 0.2)) { quiz = q }
    }

    func closeQuiz() { withAnimation { quiz = nil } }
}
