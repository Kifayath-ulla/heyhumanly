import SwiftUI
import AppKit

// MARK: - Shell

struct DashboardView: View {
    @ObservedObject var model: CoachModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(model: model)
            ScrollView(.vertical) {
                Group {
                    switch model.section {
                    case .home: HomeView(model: model)
                    case .insights: InsightsView(model: model)
                    case .review: ReviewView(model: model)
                    case .history: HistoryView(model: model)
                    case .dictionary: DictionaryView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(.horizontal, 40).padding(.top, 46).padding(.bottom, 48)
                .frame(maxWidth: .infinity, alignment: .top)
                .id(model.section)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
            .scrollIndicators(.never)
            .background(Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.hairline, lineWidth: 0.6))
            .padding(.vertical, 10).padding(.trailing, 10)
        }
        .accessibilityHidden(model.onboardingStep != nil)   // the tour is modal for VoiceOver too
        .background(Color.canvas.ignoresSafeArea())
        .overlay { if model.onboardingStep != nil { OnboardingView(model: model).transition(.opacity) } }
        .animation(.easeOut(duration: 0.22), value: model.section)
        .animation(.easeOut(duration: 0.2), value: model.onboardingStep)
        .tint(Color.brand)
        .frame(minWidth: 1020, minHeight: 640)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            model.openDashboardAction = { openWindow(id: "dashboard") }
            model.refreshStatus()
        }
    }
}

/// Left sidebar navigation.
struct Sidebar: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 9) {
                BrandMark(size: 24)
                Text("HeyHumanly").font(.system(size: 16, weight: .bold)).foregroundStyle(Color.ink)
            }
            .padding(.horizontal, 10).padding(.top, 44).padding(.bottom, 20)
            .accessibilityElement(children: .combine)

            ForEach(DashboardSection.allCases) { section in
                let selected = model.section == section
                Button { model.section = section } label: {
                    HStack(spacing: 11) {
                        Image(systemName: section.icon).font(.system(size: 14, weight: .regular)).frame(width: 20)
                        Text(section.rawValue).font(.system(size: 14, weight: selected ? .semibold : .regular))
                        Spacer(minLength: 0)
                        if section == .review, !model.dueReviews.isEmpty {
                            Text("\(model.dueReviews.count)").font(.system(size: 10.5, weight: .bold)).foregroundStyle(Color.onAccent)
                                .padding(.horizontal, 6).padding(.vertical, 1.5).background(Color.brand, in: Capsule())
                        }
                    }
                    .foregroundStyle(selected ? Color.ink : Color.ink.opacity(0.65))
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(selected ? Color.ink.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }

            Spacer()

            Button { model.section = .settings } label: {
                HStack(spacing: 8) {
                    StatusDot(color: model.engineColor)
                    Text(model.engineSummary).font(.system(size: 12)).lineLimit(1)
                }
                .foregroundStyle(Color.ink.opacity(0.6)).padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.plain).help(model.engineSummary + (model.privacyIsLocal ? " · never leaves your Mac" : ""))
            .accessibilityLabel("AI status: \(model.engineSummary)")

            Button { model.cycleAppearance() } label: {
                HStack(spacing: 11) {
                    Image(systemName: model.appearanceIcon).font(.system(size: 13)).frame(width: 20)
                    Text("Appearance: \(model.appearanceName)").font(.system(size: 12))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.ink.opacity(0.6)).padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
            }
            .buttonStyle(.plain).help("Change appearance").accessibilityLabel("Appearance: \(model.appearanceName)")

            Button { model.showCoach() } label: {
                HStack(spacing: 6) { Image(systemName: "sparkles"); Text("Open coach") }.frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle()).padding(.top, 8)
            .accessibilityLabel("Open HeyHumanly coach")
        }
        .padding(.horizontal, 12).padding(.bottom, 16)
        .frame(width: 230)
    }
}

extension OllamaStatus {
    var color: Color {
        switch self { case .running: return .added; case .checking: return .orange; default: return .removed }
    }
    /// Green only when the selected model can actually run; orange while checking or when it still needs downloading.
    func color(model: String) -> Color {
        if case .running(let models) = self, !models.contains(model) { return .orange }
        return color
    }
    func summary(model: String) -> String {
        switch self {
        case .checking: return "Checking Ollama…"
        case .running(let models): return models.contains(model) ? "Ollama · \(model)" : "\(model) not installed"
        case .notRunning: return "Ollama isn't running"
        case .noEndpoint: return "No AI endpoint set"
        }
    }
}

// MARK: - Shared pieces

struct SectionHeader: View {
    var eyebrow: String = ""
    let title: String
    var italic: String = ""
    var after: String = ""
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !eyebrow.isEmpty { Eyebrow(text: eyebrow) }
            Headline(before: title, italic: italic, after: after, size: 36)
            if let subtitle {
                Text(subtitle).font(.system(size: 14.5)).foregroundStyle(Color.ink.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 640, alignment: .leading)
            }
        }
        .padding(.bottom, 8)
    }
}

struct EmptyState: View {
    let icon: String; let title: String; let message: String
    var action: (title: String, run: () -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Mascot(size: 64, mood: .thinking)
            Text(title).font(.serif(22)).foregroundStyle(Color.ink)
            Text(message).font(.system(size: 13.5)).foregroundStyle(Color.ink.opacity(0.6)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 420)
            if let action {
                Button(action.title, action: action.run).buttonStyle(PrimaryButtonStyle()).padding(.top, 6).accessibilityLabel(action.title)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .card()
    }
}

struct HistoryRow: View {
    @ObservedObject var model: CoachModel
    let item: HistoryItem

    var body: some View {
        let expanded = model.expandedHistoryID == item.id
        VStack(alignment: .leading, spacing: 10) {
            Button {
                model.expandedHistoryID = expanded ? nil : item.id
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 62, alignment: .leading)
                    Text(item.result.rewrite).font(.system(size: 13.5)).lineLimit(expanded ? nil : 1)
                    if let app = item.appName { Text(app).font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1) }
                    Spacer(minLength: 8)
                    ModeBadge(mode: item.mode)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.mode == .teach ? "Teach Me" : "Quick Fix") session: \(item.result.rewrite)")

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(WordDiff.attributed(item.original, item.result.rewrite)).font(.system(size: 14)).textSelection(.enabled)
                    if !item.result.explanation.isEmpty {
                        Label { Text(item.result.explanation) } icon: { Image(systemName: "lightbulb").foregroundStyle(.orange) }
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    if !item.result.exercise.isEmpty {
                        Label { Text(item.result.exercise) } icon: { Image(systemName: "target").foregroundStyle(Color.teach) }
                            .font(.system(size: 12.5))
                    }
                    HStack(spacing: 8) {
                        Button("Open in coach") { model.reopen(item) }.buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Open in coach")
                        Button("Copy rewrite") {
                            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.result.rewrite, forType: .string)
                        }.buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Copy rewrite")
                        if !item.result.exercise.isEmpty {
                            Button("Practice") { model.practice(item) }.buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Practice")
                        }
                        Spacer()
                        Button(role: .destructive) { model.deleteHistoryItem(item.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).foregroundStyle(Color.removed).accessibilityLabel("Delete session").help("Delete")
                    }
                }
                .padding(.leading, 74)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
    }
}

struct DayGroup: View {
    @ObservedObject var model: CoachModel
    let day: Date; let items: [HistoryItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.title(day)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(Color.hairline).padding(.leading, 16) }
                    HistoryRow(model: model, item: item)
                }
            }
            .card(padding: 0)
        }
    }
    static func title(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text(welcome).font(.serif(34)).foregroundStyle(Color.ink)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 24) {
                    banner
                    if !model.dueReviews.isEmpty { reviewCard }

                    let steps = model.setupSteps
                    if !model.engineReady { EngineArea(model: model) }
                    if steps.contains(where: { !$0.done }) { setupRow(steps) }

                    recent
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                statsCard.frame(width: 250)
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Recent fixes", color: Color.ink.opacity(0.45))
                Spacer()
                if !model.history.isEmpty {
                    Button("See all") { model.section = .history }.buttonStyle(.plain)
                        .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.ink.opacity(0.65)).accessibilityLabel("See all history")
                }
            }
            if model.history.isEmpty {
                EmptyState(icon: "text.badge.checkmark", title: "Nothing here yet",
                           message: "Your corrected sentences and lessons will appear here after your first Quick Fix or Teach Me.",
                           action: ("Try it with an example", {
                               model.clearDraft(); model.draft = "Please send me that thung when you have time."; model.showCoach()
                           }))
            } else {
                let recent = Array(model.history.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Color.hairline).padding(.leading, 18) }
                        HistoryRow(model: model, item: item)
                    }
                }
                .card(padding: 0)
            }
        }
    }

    private var banner: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                (Text("Write like ") + Text("yourself").italic() + Text(", just clearer."))
                    .font(.serif(28)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                // One line when it fits, otherwise break after the shortcut instead of truncating.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) { bannerPress; bannerRest }
                    VStack(alignment: .leading, spacing: 6) { HStack(spacing: 7) { bannerPress }; bannerRest }
                    VStack(alignment: .leading, spacing: 6) { bannerPress; bannerRest }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { bannerButtons }
                    VStack(alignment: .leading, spacing: 8) { bannerButtons }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Mascot(size: 84, mood: model.history.isEmpty ? .thinking : .happy)
        }
        .card(padding: 26, radius: 22)
    }

    @ViewBuilder private var bannerPress: some View {
        Text("Select text anywhere, press").font(.system(size: 13.5)).foregroundStyle(Color.ink.opacity(0.65)).fixedSize()
        ShortcutKeys(label: model.shortcutLabel, size: 12)
    }

    private var bannerRest: some View {
        Text(model.privacyIsLocal ? "and it is fixed on this Mac." : "and it is fixed.").font(.system(size: 13.5)).foregroundStyle(Color.ink.opacity(0.65)).fixedSize()
    }

    @ViewBuilder private var bannerButtons: some View {
        Button { model.showCoach() } label: { Label("Open the coach", systemImage: "sparkles").fixedSize() }
            .buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Open the coach")
        Button { model.section = .insights } label: { Text("See your progress").fixedSize() }
            .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("See your progress")
    }

    private var welcome: String {
        let first = NSFullUserName().split(separator: " ").first.map { $0.prefix(1).uppercased() + $0.dropFirst() } ?? ""
        let hello = model.history.isEmpty ? "Welcome" : "Welcome back"
        return first.isEmpty ? hello : "\(hello), \(first)"
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                bigStat(model.history.count, "sessions")
                bigStat(model.wordsCoached, "words coached")
                bigStat(model.dayStreak, model.dayStreak == 1 ? "day streak" : "day streak")
            }
            .padding(22)
            Divider().overlay(Color.hairline)
            VStack(alignment: .leading, spacing: 8) {
                Text("Mistakes mastered").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.ink)
                Text(model.masteredCount == 0 ? "Fix a sentence in Review to master your first." : "\(model.masteredCount) habits you no longer repeat.")
                    .font(.system(size: 12.5)).foregroundStyle(Color.ink.opacity(0.6)).fixedSize(horizontal: false, vertical: true)
                Text(model.masteredCount.formatted()).font(.serif(30)).foregroundStyle(Color.ink)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 0, radius: 22)
        .accessibilityElement(children: .contain)
    }

    private func bigStat(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(value.formatted()).font(.serif(34)).foregroundStyle(Color.ink).contentTransition(.numericText())
            Text(label).font(.system(size: 14)).foregroundStyle(Color.ink.opacity(0.6))
        }
        .accessibilityElement(children: .combine)
    }

    private var reviewCard: some View {
        HStack(spacing: 16) {
            Mascot(size: 46, mood: .proud)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(model.dueReviews.count) review card\(model.dueReviews.count == 1 ? "" : "s") due").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ink)
                Text("Fix sentences you wrote earlier so the corrections stick. About a minute.").font(.system(size: 13)).foregroundStyle(Color.ink.opacity(0.6))
            }
            Spacer()
            Button("Start review") { model.section = .review }.buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Start review")
        }
        .card(padding: 18)
    }

    private func setupRow(_ steps: [SetupStep]) -> some View {
        let done = steps.filter(\.done).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "Get set up · \(done) of \(steps.count)")
                    Headline(before: "A few ", italic: "quick", after: " steps", size: 26)
                }
                Spacer()
                Button { model.refreshStatus() } label: { Label("Recheck", systemImage: "arrow.clockwise") }
                    .buttonStyle(SecondaryButtonStyle()).accessibilityLabel("Recheck setup")
            }
            // Wraps to more rows instead of squeezing five cards until their titles break mid-word.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    setupCard(index: index + 1, step: step)
                }
            }
        }
    }

    private func setupCard(index: Int, step: SetupStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: "%02d", index)).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.ink.opacity(0.35))
                Spacer()
                Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15)).foregroundStyle(step.done ? Color.brand : Color.ink.opacity(0.25))
            }
            Text(step.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            Text(step.detail).font(.system(size: 11.5)).foregroundStyle(Color.ink.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !step.done, let action = action(for: index) {
                Button(action.0, action: action.1).buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brand).accessibilityLabel(action.0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .card(padding: 14, radius: 16)
        .opacity(step.done ? 0.6 : 1)
    }

    private func action(for index: Int) -> (String, () -> Void)? {
        switch index {
        case 1: return ("Choose →", { model.openDashboard(section: .settings) })
        case 2: return ("Try it →", { model.clearDraft(); model.rephraseOn = false; model.selectedMode = .quickFix; model.draft = "Please send me that thung when you have time."; model.showCoach() })
        case 3: return ("Try it →", { model.clearDraft(); model.rephraseOn = false; model.selectedMode = .teach; model.draft = "i dont think we shoud of went their yesterday"; model.showCoach() })
        case 4: return ("Turn on →", { AccessibilityBridge.requestTrust(); AccessibilityBridge.openSystemSettings() })
        default: return nil
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                SectionHeader(eyebrow: "History", title: "Everything you ", italic: "wrote", after: ", fixed", subtitle: "Every Quick Fix and Teach Me session, saved only on this Mac.")
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search \(model.history.count) sessions", text: $model.historySearch).textFieldStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.hairline))
                .frame(width: 260)
            }
            if model.history.isEmpty {
                EmptyState(icon: "clock.arrow.circlepath", title: "Nothing here yet",
                           message: "Sessions appear here after you use Quick Fix or Teach Me.",
                           action: ("Open coach", { model.showCoach() }))
            } else if model.filteredHistory.isEmpty {
                Text("No sessions match “\(model.historySearch)”.").foregroundStyle(.secondary).padding(.top, 20)
            } else {
                ForEach(model.historyByDay, id: \.day) { group in
                    DayGroup(model: model, day: group.day, items: group.items)
                }
            }
        }
    }
}

// MARK: - Dictionary

struct DictionaryView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(eyebrow: "Dictionary", title: "Words that stay ", italic: "yours", subtitle: "Names, jargon and words HeyHumanly must keep exactly as you wrote them. They're sent with every request to your local model.")
            HStack(spacing: 8) {
                TextField("Add a word or phrase", text: $model.newDictionaryWord)
                    .textFieldStyle(.plain).font(.system(size: 14))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.hairline))
                    .onSubmit(add)
                Button("Add", action: add).buttonStyle(PrimaryButtonStyle())
                    .disabled(model.newDictionaryWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Add")
            }
            if model.dictionary.isEmpty {
                EmptyState(icon: "character.book.closed", title: "Your dictionary is empty",
                           message: "Add product names, people's names or technical terms so corrections never change them.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(model.dictionary, id: \.self) { word in
                        HStack(spacing: 6) {
                            Text(word).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            Button { model.removeDictionaryWord(word) } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Remove \(word)")
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.hairline))
                    }
                }
            }
        }
    }
    private func add() { model.addDictionaryWord(model.newDictionaryWord); model.newDictionaryWord = "" }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeader(eyebrow: "Settings", title: "Make it ", italic: "yours")
            companionCard
            styleCard
            learningCard
            EngineSettingsCard(model: model)
            aiCard
            browserCard
            shortcutCard
            permissionsCard
            dataCard
        }
        .onChange(of: model.settingsEndpoint) { _, value in model.settings.endpoint = value; model.settings.save() }
        .onChange(of: model.settingsModel) { _, value in model.settings.model = value; model.settings.save() }
        .onDisappear { model.stopRecording() }
        .confirmationDialog("Delete all \(model.history.count) saved sessions?", isPresented: $model.confirmClearHistory) {
            Button("Delete all sessions", role: .destructive) { model.clearHistory() }
        } message: { Text("This can't be undone.") }
    }

    private func cardTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardTitle("Local AI (Ollama, Advanced)", icon: "cpu")
                Spacer()
                StatusDot(color: model.ollama.color(model: model.settings.model))
                Text(model.ollama.summary(model: model.settings.model)).font(.system(size: 12)).foregroundStyle(.secondary)
                Button { model.saveConnection() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Check again").accessibilityLabel("Check Ollama again")
            }
            recommendation
            field("Endpoint", text: $model.settingsEndpoint, prompt: "http://localhost:11434/api/generate")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Model").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    Text("Works with any local model in Ollama").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                if model.installedModels.isEmpty {
                    Text(model.ollama == .checking ? "Looking for installed models…" : "No installed models found in Ollama. Start Ollama, then run `ollama pull qwen2.5:7b` (or any model of your choice).")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(model.installedModels.enumerated()), id: \.element) { index, name in
                            if index > 0 { Divider().overlay(Color.hairline) }
                            Button { model.selectModel(name) } label: {
                                HStack {
                                    Image(systemName: model.settings.model == name ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(model.settings.model == name ? Color.brand : .secondary)
                                    Text(name).font(.system(size: 13, design: .monospaced))
                                    Spacer()
                                    if model.settings.model == name {
                                        Text("Active").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color.brand)
                                            .padding(.horizontal, 7).padding(.vertical, 2).background(Color.brandSoft, in: Capsule())
                                    } else {
                                        Text("Installed").font(.system(size: 10.5)).foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).accessibilityLabel("Use model \(name)")
                        }
                    }
                    .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.hairline))
                }
                field("Custom model or tag (any Ollama model)", text: $model.settingsModel, prompt: "e.g. qwen2.5:7b, llama3.2, mistral, deepseek-r1:8b")
                Text("HeyHumanly is model-agnostic: you can use any local model you have installed. We suggest the lowest friction baseline, but any Ollama model works seamlessly.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if model.privacyIsLocal {
                Label("Private: the endpoint is on this Mac, so your writing never leaves it. Works with Wi-Fi off. No account, no API key.", systemImage: "lock.shield.fill")
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(Color.added)
            } else {
                Label("This endpoint is not on this Mac. Your text will be sent to \(URLComponents(string: model.settings.endpoint)?.host ?? "another computer").", systemImage: "exclamationmark.shield.fill")
                    .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.orange)
            }
        }
        .card()
    }

    private func setting(_ change: (inout AppSettings) -> Void) {
        change(&model.settings); model.settings.save(); model.objectWillChange.send()
    }

    private var companionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                cardTitle("Companion", icon: "text.cursor")
                Spacer()
                Toggle("Check as I type", isOn: Binding(get: { model.settings.autoCheck }, set: { v in setting { $0.autoCheck = v } }))
                    .toggleStyle(.switch).controlSize(.small).tint(.switchOn)
            }
            Text(model.privacyIsLocal
                 ? "When you pause typing in a text field, HeyHumanly reads that one field and checks it on this Mac. Password fields and paused apps are never read. Nothing is saved unless you accept a suggestion or start a lesson."
                 : "Checking as you type is off while the AI endpoint isn't on this Mac, so nothing you type is sent anywhere automatically.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Learn").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Picker("Learn", selection: Binding(get: { model.settings.learnBySentence }, set: { v in setting { $0.learnBySentence = v } })) {
                        Text("A sentence at a time").tag(true)
                        Text("Word by word").tag(false)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 300)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Explain in").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Picker("Explain in", selection: Binding(get: { model.settings.explainLanguage }, set: { v in setting { $0.explainLanguage = v } })) {
                        ForEach(AppSettings.explainLanguages, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden().frame(width: 150)
                }
            }
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Clicking the dot").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Picker("Clicking the dot", selection: Binding(get: { model.settings.dotTeaches }, set: { v in setting { $0.dotTeaches = v } })) {
                        Text("Teaches me").tag(true)
                        Text("Shows the fix").tag(false)
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 300)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Check after I stop typing for").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Picker("Typing pause", selection: Binding(get: { model.settings.typingPause }, set: { v in setting { $0.typingPause = v } })) {
                        Text("1 second").tag(1.2); Text("2 seconds").tag(2.0); Text("4 seconds").tag(4.0)
                    }
                    .labelsHidden().frame(width: 150)
                }
            }
            Toggle("Also suggest clearer wording (softer underline). Off = real mistakes only (red)",
                   isOn: Binding(get: { model.settings.suggestStyle }, set: { v in setting { $0.suggestStyle = v } }))
                .toggleStyle(.checkbox).font(.system(size: 12.5))
            Toggle("Let me guess first (\"Which reads better?\") before showing the answer",
                   isOn: Binding(get: { model.settings.tryFirstInline }, set: { v in setting { $0.tryFirstInline = v } }))
                .toggleStyle(.checkbox).font(.system(size: 12.5))

            VStack(alignment: .leading, spacing: 8) {
                Text("Never read text in").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                FlowChips(items: model.settings.pausedApps.map { ($0, Self.appName($0)) }.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }) { id in
                    setting { $0.pausedApps.remove(id) }
                }
                Text("Password managers, terminals and code editors are paused by default. Pause any other app from the companion.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }

            HStack(spacing: 14) {
                ForEach([("⌃⌥↩", "Fix mistakes"), ("⌃⌥L", "Teach me"), ("⌃⌥Z", "Undo"), ("esc", "Close a card"), ("⌃⌥.", "Hide all")], id: \.0) { key, label in
                    HStack(spacing: 6) { KeyCap(key: key, size: 11); Text(label).font(.system(size: 12)).foregroundStyle(.secondary) }
                }
            }
            Text("These work only while suggestions are showing, so they never clash with other apps the rest of the time.")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            Divider().overlay(Color.hairline)
            HStack(spacing: 10) {
                Text(model.dismissedCount == 0 ? "No dismissed suggestions are being remembered."
                     : "\(model.dismissedCount) dismissed suggestion\(model.dismissedCount == 1 ? " is" : "s are") remembered and won't come back.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Forget dismissals") { model.resetDismissals() }.buttonStyle(SecondaryButtonStyle()).disabled(model.dismissedCount == 0)
                Button("Replay the tour") { model.onboardingStep = 0 }.buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    static let pausedAppNames = ["com.1password.1password": "1Password", "com.agilebits.onepassword7": "1Password 7", "com.bitwarden.desktop": "Bitwarden",
                            "com.apple.keychainaccess": "Keychain Access", "com.apple.Terminal": "Terminal", "com.googlecode.iterm2": "iTerm",
                            "dev.warp.Warp-Stable": "Warp", "com.mitchellh.ghostty": "Ghostty", "com.apple.dt.Xcode": "Xcode",
                            "com.microsoft.VSCode": "Visual Studio Code", "com.todesktop.230313mzl4w4u92": "Cursor"]

    static func appName(_ bundleID: String) -> String {
        if let known = pausedAppNames[bundleID] { return known }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("What should I teach you?", icon: "graduationcap")
            Text("Turn off what you already know. Those mistakes are still fixed, quietly, but not shown, counted in Insights or added to Review.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
                ForEach(MistakeCategory.allCases) { category in
                    let on = !model.isMuted(category)
                    HStack {
                        Image(systemName: category.icon).foregroundStyle(on ? category.color : Color.ink.opacity(0.3)).frame(width: 18)
                        Text(category.title).font(.system(size: 13, weight: .medium)).foregroundStyle(on ? Color.ink : Color.ink.opacity(0.45))
                        Spacer()
                        Toggle("", isOn: Binding(get: { on }, set: { model.setMuted(category, !$0) }))
                            .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.switchOn)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Teach me \(category.title)")
                }
            }
        }
        .card()
    }

    private var styleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("Writing style", icon: "slider.horizontal.3")
            Text("How much HeyHumanly may change by default. You can switch per request in the coach.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(WritingStyle.allCases) { style in
                    let on = model.settings.defaultStyle == style
                    Button {
                        model.settings.defaultStyle = style; model.settings.save(); model.selectedStyle = style
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(style.rawValue, systemImage: style.icon).font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(on ? Color.brand : .primary)
                            Text(style.blurb).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                        .padding(10)
                        .background(on ? Color.brandSoft : Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(on ? Color.brand.opacity(0.5) : Color.hairline))
                    }
                    .buttonStyle(.plain).accessibilityLabel("Default style \(style.rawValue)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Per-app style").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                ForEach(Self.knownApps, id: \.0) { bundle, name in
                    HStack {
                        Text(name).font(.system(size: 13))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.settings.appStyles[bundle] ?? model.settings.defaultStyle },
                            set: { var map = model.settings.appStyles; map[bundle] = $0; model.settings.appStyles = map; model.settings.save() })) {
                            ForEach(WritingStyle.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden().frame(width: 150).accessibilityLabel("Style for \(name)")
                    }
                }
                Text("Used when you capture text from that app. Other apps use the default style.").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .card()
    }

    static let knownApps: [(String, String)] = [
        ("com.apple.mail", "Mail"), ("com.microsoft.Outlook", "Outlook"), ("com.tinyspeck.slackmacgap", "Slack"),
        ("com.apple.MobileSMS", "Messages"), ("net.whatsapp.WhatsApp", "WhatsApp"), ("com.hnc.Discord", "Discord"),
    ]

    @ViewBuilder private var recommendation: some View {
        let rec = model.recommendedModel
        if case .running = model.ollama, !model.installedModels.contains(rec) || model.settings.model != rec {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").foregroundStyle(Color.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recommended for this Mac: \(rec)").font(.system(size: 13, weight: .semibold))
                    Text(model.installedModels.contains(rec)
                         ? "Installed. Catches more grammar mistakes and explains them better than smaller models."
                         : "About 4.7 GB, runs offline. Catches more grammar mistakes and explains them better.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    if let p = model.pullProgress {
                        ProgressView(value: p).tint(.brand).padding(.top, 4)
                        Text("\(model.pullStatus) \(Int(p * 100))%").font(.system(size: 11)).foregroundStyle(.secondary)
                    } else if !model.pullStatus.isEmpty {
                        Text(model.pullStatus).font(.system(size: 11)).foregroundStyle(Color.removed)
                    }
                }
                Spacer()
                if model.installedModels.contains(rec) {
                    Button("Use it") { model.selectModel(rec) }.buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Use \(rec)")
                } else if model.pullProgress == nil {
                    Button("Download") { model.download(model: rec) }.buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Download \(rec)")
                }
            }
            .padding(12)
            .background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.hairline))
                .onSubmit { model.saveConnection() }
                .accessibilityLabel(title)
        }
    }

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Shortcut", icon: "command")
            HStack(spacing: 12) {
                if model.isRecordingShortcut {
                    Text("Press your new shortcut…").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.brand)
                    Text("Esc cancels").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    ShortcutKeys(label: model.shortcutLabel, size: 14)
                    Text("Opens the coach with your selected text").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.isRecordingShortcut ? "Cancel" : "Change") {
                    model.isRecordingShortcut ? model.stopRecording() : model.recordShortcut()
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel(model.isRecordingShortcut ? "Cancel shortcut recording" : "Change shortcut")
            }
            .padding(12)
            .background(model.isRecordingShortcut ? Color.brandSoft : Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            if let error = model.shortcutError {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(Color.removed)
            }
            Text("Use Command, Control, Option or Shift plus a key. Shortcuts that macOS already uses are refused.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .card()
    }

    private var browserCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Chrome extension", icon: "globe")
            HStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension").font(.system(size: 18)).foregroundStyle(Color.brand)
                    .frame(width: 34, height: 34).background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Let the browser extension use your local model").font(.system(size: 13, weight: .semibold))
                    Text("Ollama blocks browser extensions by default. This allows only extensions and local pages to reach it on this Mac, keeps that after a restart, and restarts Ollama once.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.browserBusy {
                    ProgressView().controlSize(.small)
                } else if model.browserAllowed == true {
                    Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.added)
                } else {
                    Button("Allow") {
                        model.browserBusy = true; model.browserNote = nil
                        Task {
                            model.browserNote = await BrowserAccess.enable()
                            model.browserAllowed = await BrowserAccess.isAllowed(endpoint: "http://localhost:11434")
                            model.browserBusy = false; model.refreshStatus()
                        }
                    }.buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Allow the Chrome extension to use Ollama")
                }
            }
            if let note = model.browserNote { Text(note).font(.system(size: 11.5)).foregroundStyle(Color.removed) }
            HStack(spacing: 14) {
                Button("Get the extension") { NSWorkspace.shared.open(URL(string: "https://heyhumanly.com/extension/")!) }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink.opacity(0.7))
                if model.browserAllowed == true && !model.browserBusy {
                    Button("Turn off") {
                        model.browserBusy = true
                        Task { await BrowserAccess.disable(); model.browserAllowed = await BrowserAccess.isAllowed(endpoint: "http://localhost:11434"); model.browserBusy = false; model.refreshStatus() }
                    }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
        .card()
        .task { model.browserAllowed = await BrowserAccess.isAllowed(endpoint: "http://localhost:11434") }
    }

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Permissions", icon: "hand.raised")
            HStack(spacing: 12) {
                Image(systemName: "accessibility").font(.system(size: 18)).foregroundStyle(Color.brand)
                    .frame(width: 34, height: 34).background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility").font(.system(size: 13, weight: .semibold))
                    Text("Reads the text field you are typing in and pastes a fix back when you accept one. Never password fields.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.accessibilityTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.added)
                } else {
                    Button("Allow…") { AccessibilityBridge.requestTrust(); AccessibilityBridge.openSystemSettings() }
                        .buttonStyle(PrimaryButtonStyle()).accessibilityLabel("Open Accessibility Settings")
                }
            }
            if !model.accessibilityTrusted {
                Text("Already switched on? After a rebuild, remove HeyHumanly from the list with − and add it again with +.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Privacy & data", icon: "lock")
            Text("No account, analytics or telemetry. Sessions and your dictionary are stored on this Mac only.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
            HStack {
                Text("\(model.history.count) saved sessions · \(model.dictionary.count) dictionary words").font(.system(size: 12.5))
                Spacer()
                Button("Clear history…") { model.confirmClearHistory = true }
                    .buttonStyle(SecondaryButtonStyle()).foregroundStyle(Color.removed)
                    .disabled(model.history.isEmpty).accessibilityLabel("Clear history")
            }
        }
        .card()
    }
}


/// Removable chips that wrap onto new lines.
struct FlowChips: View {
    let items: [(id: String, title: String)]
    let remove: (String) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.id) { item in
                HStack(spacing: 5) {
                    Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Button { remove(item.id) } label: { Image(systemName: "xmark").font(.system(size: 8.5, weight: .bold)) }
                        .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Stop pausing \(item.title)")
                }
                .padding(.horizontal, 9).frame(height: 24)
                .background(Capsule().fill(Color.surfaceSunken))
                .overlay(Capsule().strokeBorder(Color.hairline))
            }
        }
    }
}
