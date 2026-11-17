import SwiftUI

// MARK: - Insights

struct InsightsView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        let stats = model.categoryStats
        let total = stats.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(eyebrow: "Insights", title: "What you ", italic: "keep", after: " getting wrong", subtitle: "Patterns in your own writing, counted from sessions on this Mac. No scores, no comparisons with other people.")
            if total == 0 {
                HabitsCard(model: model)
                EmptyState(icon: "chart.bar.xaxis", title: "Your patterns will show up here",
                           message: "After a few Quick Fix sessions, HeyHumanly groups your corrections by type so you can see what to work on.",
                           action: ("Open coach", { model.showCoach() }))
            } else {
                HabitsCard(model: model)
                trendCard
                ActivityGrid(history: model.history)
                if let top = stats.first { focusCard(top) }
                VStack(alignment: .leading, spacing: 12) {
                    Text("All corrections by type").font(.system(size: 15, weight: .semibold))
                    VStack(spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                            if index > 0 { Divider().overlay(Color.hairline) }
                            categoryRow(stat, max: stats.first?.count ?? 1)
                        }
                    }
                    .card(padding: 0)
                }
            }
        }
    }

    private var trendCard: some View {
        let cal = Calendar.current, now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!, twoWeeks = cal.date(byAdding: .day, value: -14, to: now)!
        let thisWeek = Insights.rate(history: model.history, from: weekAgo, to: now.addingTimeInterval(1))
        let lastWeek = Insights.rate(history: model.history, from: twoWeeks, to: weekAgo)
        return HStack(spacing: 0) {
            metric("Corrections per 100 words", value: thisWeek.map { String(format: "%.1f", $0) } ?? "—",
                   caption: thisWeek == nil ? "Needs about 40 words this week" : "this week")
            Rectangle().fill(Color.hairline).frame(width: 1, height: 44).padding(.horizontal, 18)
            if let a = thisWeek, let b = lastWeek, b > 0 {
                let change = (a - b) / b * 100
                metric("Compared with last week", value: String(format: "%@%.0f%%", change <= 0 ? "↓ " : "↑ ", abs(change)),
                       caption: change <= 0 ? "fewer corrections needed" : "more corrections needed", tint: change <= 0 ? .added : .orange)
            } else {
                metric("Compared with last week", value: "—", caption: "Shows once you have two weeks of writing")
            }
            Rectangle().fill(Color.hairline).frame(width: 1, height: 44).padding(.horizontal, 18)
            metric("Mistakes mastered", value: "\(model.masteredCount)", caption: "fixed correctly 3 times in Review")
        }
        .card(padding: 20)
    }

    private func metric(_ title: String, value: String, caption: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(tint)
            Text(caption).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func focusCard(_ stat: CategoryStat) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: stat.category.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(stat.category.color)
                .frame(width: 46, height: 46).background(stat.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text("Your most common correction: \(stat.category.title.lowercased())").font(.system(size: 15, weight: .semibold))
                Text("\(stat.count) time\(stat.count == 1 ? "" : "s") so far. Examples from your own writing:")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                ForEach(stat.examples) { ex in
                    HStack(spacing: 6) {
                        Text(ex.from.isEmpty ? "∅" : ex.from).strikethrough().foregroundStyle(Color.removed)
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                        Text(ex.to.isEmpty ? "∅" : ex.to).foregroundStyle(Color.added)
                        if !ex.reason.isEmpty { Text("· \(ex.reason)").foregroundStyle(.secondary).lineLimit(1) }
                    }
                    .font(.system(size: 13))
                }
                if !model.dueReviews.isEmpty {
                    Button("Review \(model.dueReviews.count) due") { model.section = .review }
                        .buttonStyle(PrimaryButtonStyle()).padding(.top, 4).accessibilityLabel("Start review")
                }
            }
            Spacer()
        }
        .card(padding: 20)
    }

    private func categoryRow(_ stat: CategoryStat, max: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stat.category.icon).foregroundStyle(stat.category.color).frame(width: 20)
            Text(stat.category.title).font(.system(size: 13, weight: .medium)).frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.hairline)
                    RoundedRectangle(cornerRadius: 4).fill(stat.category.color.opacity(0.75))
                        .frame(width: max > 0 ? geo.size.width * CGFloat(stat.count) / CGFloat(max) : 0)
                }
            }
            .frame(height: 6)
            Text("\(stat.count)").font(.system(size: 13, weight: .semibold, design: .rounded)).frame(width: 34, alignment: .trailing)
            Text(stat.thisWeek > 0 ? "\(stat.thisWeek) this week" : "none this week").font(.system(size: 11)).foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Review

struct ReviewView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(eyebrow: "Review", title: "Make the fixes ", italic: "stick", subtitle: "Short drills built from your own past mistakes, spaced out so they stick. A few minutes a day is enough.")
            if let item = model.currentReview {
                drill(item)
            } else if model.reviews.isEmpty {
                EmptyState(icon: "rectangle.stack", title: "No review cards yet",
                           message: "Each time HeyHumanly fixes a spelling, grammar or word-choice mistake, it saves a card here. Your first cards come due the next day.",
                           action: ("Open coach", { model.showCoach() }))
            } else {
                let next = model.reviews.map(\.due).min()
                HStack(spacing: 14) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 26)).foregroundStyle(Color.added)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All caught up").font(.system(size: 15, weight: .semibold))
                        Text("\(model.reviews.count) cards · \(model.masteredCount) mastered" + (next.map { " · next one \($0.formatted(.relative(presentation: .named)))" } ?? ""))
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .card(padding: 20)
            }
            lessons
        }
    }

    private func drill(_ item: ReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(item.category.title, systemImage: item.category.icon).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(item.category.color)
                Spacer()
                Text(model.reviewFeedback == nil ? "\(model.dueReviews.count) due" : "\(model.dueReviews.count) left")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Text("You wrote this. Fix the highlighted part:").font(.system(size: 12.5)).foregroundStyle(.secondary)
            Text(Self.highlight(item.sentence, item.from, color: item.category.color)).font(.system(size: 17, weight: .medium)).textSelection(.enabled)
            if model.reviewHintShown, model.reviewFeedback == nil {
                Label(item.reason.isEmpty ? item.category.fallbackReason : item.reason, systemImage: "lightbulb.fill")
                    .font(.system(size: 12.5)).foregroundStyle(.orange)
            }
            TextField("Type the corrected sentence", text: $model.reviewAnswer, axis: .vertical)
                .textFieldStyle(.plain).font(.system(size: 15))
                .padding(12)
                .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(feedbackColor))
                .onSubmit { if model.reviewFeedback == nil { model.checkReview() } else { model.nextReview() } }
                .disabled(model.reviewFeedback != nil)
                .accessibilityLabel("Your corrected sentence")
            if let correct = model.reviewFeedback {
                VStack(alignment: .leading, spacing: 6) {
                    Label(correct ? "Correct" : "Not quite", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(correct ? Color.added : Color.removed)
                    Text(Self.highlight(item.corrected, item.to, color: .added)).font(.system(size: 14))
                    if !item.reason.isEmpty { Text(item.reason).font(.system(size: 12.5)).foregroundStyle(.secondary) }
                    Text(correct ? "You'll see this again in a few days." : "You'll get this one again shortly.")
                        .font(.system(size: 11.5)).foregroundStyle(.tertiary)
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background((correct ? Color.added : Color.removed).opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack {
                if model.reviewFeedback == nil {
                    Button("Skip for today") { model.skipReview() }.buttonStyle(.link).font(.system(size: 12)).accessibilityLabel("Skip for today")
                    Button("Show hint") { model.reviewHintShown = true }
                        .buttonStyle(.link).font(.system(size: 12)).help("Shows the rule, not the answer")
                        .accessibilityLabel("Show hint")
                    Button("Start from my sentence") { model.reviewAnswer = item.sentence }
                        .buttonStyle(.link).font(.system(size: 12)).accessibilityLabel("Start from my sentence")
                    Spacer()
                    Button("Check") { model.checkReview() }.buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(model.reviewAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityLabel("Check answer")
                } else {
                    Spacer()
                    Button("Next") { model.nextReview() }.buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command).accessibilityLabel("Next card")
                }
            }
        }
        .card(padding: 22)
    }

    /// The sentence with the mistake marked in the category colour.
    static func highlight(_ sentence: String, _ fragment: String, color: Color) -> AttributedString {
        var s = AttributedString(sentence)
        if !fragment.isEmpty, let range = s.range(of: fragment) {
            s[range].backgroundColor = color.opacity(0.18)
            s[range].foregroundColor = color
            s[range].underlineStyle = .single
        }
        return s
    }

    private var feedbackColor: Color {
        switch model.reviewFeedback { case .some(true): return .added; case .some(false): return .removed; default: return .hairline }
    }

    @ViewBuilder private var lessons: some View {
        let lessons = model.history.filter { $0.mode == .teach && !$0.result.exercise.isEmpty }
        if !lessons.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Teach Me lessons").font(.system(size: 15, weight: .semibold))
                ForEach(lessons.prefix(8)) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "target").foregroundStyle(Color.teach).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.result.exercise).font(.system(size: 13.5, weight: .medium))
                            Text(item.result.rewrite).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Button("Practice") { model.practice(item) }.buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Practice this exercise")
                    }
                    .card(padding: 14, radius: 12)
                }
            }
        }
    }
}


/// Day-by-day activity for the last 26 weeks, from saved sessions (GitHub-style; same as the website).
struct ActivityGrid: View {
    let history: [HistoryItem]
    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let counts = Dictionary(grouping: history, by: { cal.startOfDay(for: $0.date) }).mapValues(\.count)
        // Start on the Sunday 25 weeks before this week's Sunday, so columns are whole weeks.
        let weekday = cal.component(.weekday, from: today) - 1
        let start = cal.date(byAdding: .day, value: -(25 * 7 + weekday), to: today)!
        let days = (0..<(26 * 7)).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        let active = counts.filter { $0.key >= start }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Day by day").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(active) day\(active == 1 ? "" : "s") with sessions in the last 6 months").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7), spacing: 3) {
                ForEach(days, id: \.self) { day in
                    let n = day > today ? -1 : (counts[day] ?? 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(n < 0 ? Color.clear : n == 0 ? Color.hairline : Color.teach.opacity(min(1, 0.3 + Double(n) * 0.12)))
                        .frame(width: 11, height: 11)
                        .help(n < 0 ? "" : "\(day.formatted(date: .abbreviated, time: .omitted)): \(n) session\(n == 1 ? "" : "s")")
                }
            }
            .frame(height: 7 * 11 + 6 * 3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(active) days with sessions in the last six months")
        }
        .card(padding: 20)
    }
}
