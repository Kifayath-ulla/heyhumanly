import SwiftUI
import AppKit
import Carbon.HIToolbox
import os

@MainActor
final class CoachModel: ObservableObject {
    @Published var draft = ""
    @Published var result = CoachResult.empty
    @Published var resultMode: CoachMode?
    @Published var loadingMode: CoachMode?
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var settings = AppSettings()
    @Published var history: [HistoryItem] = []
    @Published var settingsEndpoint = ""
    @Published var settingsModel = ""
    @Published var section: DashboardSection = .home
    @Published var selectedMode: CoachMode = .quickFix
    @Published var historySearch = ""
    @Published var expandedHistoryID: UUID?
    @Published var ollama: OllamaStatus = .checking
    @Published var installedModels: [String] = []
    /// In-app model download (Ollama /api/pull). nil progress = not downloading.
    @Published var pullFraction: Double?
    @Published var pullDetail = ""
    @Published var pullError: String?
    var pullTask: Task<Void, Never>?
    @Published var accessibilityTrusted = AccessibilityBridge.isTrusted
    @Published var confirmClearHistory = false
    /// Exercise the user is practising, shown above the editor.
    @Published var practicePrompt: String?
    @Published var showRemovedWords = false
    /// The saved session the coach is showing (original text + result).
    @Published var currentItem: HistoryItem?
    @Published var isRecordingShortcut = false
    @Published var shortcutLabel = "⌃⌥Space"
    @Published var shortcutError: String?
    @Published var sourceAppName: String?
    @Published var dictionary: [String] = []
    @Published var newDictionaryWord = ""
    // Review & learning
    @Published var selectedStyle: WritingStyle = .fixOnly
    @Published var changeSet = ChangeSet()
    @Published var acceptedChanges: Set<UUID> = []
    @Published var explaining = false
    /// Rewrite text as it streams in.
    @Published var streamingText = ""
    @Published var lessonLoading = false
    @Published var reviews: [ReviewItem] = []
    @Published var reviewIndex = 0
    @Published var reviewAnswer = ""
    @Published var reviewFeedback: Bool?
    @Published var pullProgress: Double?
    @Published var pullStatus = ""
    private var sourceBundleID: String?
    /// In-app underlines + suggestion cards (the main experience).
    let inline = InlineSession()
    let watcher = TextWatcher()
    @Published var showQuietFixes = false
    // Make it better + interactive learning
    @Published var styleFindings: [StyleFinding] = []
    @Published var styleBusy: UUID?
    @Published var proposedRewrites: [UUID: String] = [:]
    @Published var openLesson: UUID?
    @Published var tryFirst = UserDefaults.standard.bool(forKey: "heyhumanly.tryFirst") {
        didSet { UserDefaults.standard.set(tryFirst, forKey: "heyhumanly.tryFirst") }
    }
    @Published var spotRevealed = true
    @Published var spotPicked: Set<Int> = []
    @Published var quiz: QuizState?
    /// First-run tour (nil = not showing).
    @Published var onboardingStep: Int?
    /// "Pause for an hour" from the menu bar.
    @Published var snoozedUntil: Date?
    @Published var dismissedCount = RewriteGuard.dismissed.count

    var isSnoozed: Bool { snoozedUntil.map { $0 > Date() } ?? false }
    /// Checking as you type is on and not snoozed.
    var coachingActive: Bool { settings.autoCheck && !isSnoozed }

    func setCoaching(_ on: Bool) {
        settings.autoCheck = on; settings.save(); snoozedUntil = nil
        if !on { inline.stop() }
    }
    func snooze(minutes: Int) {
        snoozedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        inline.stop()
    }
    func finishOnboarding() {
        onboardingStep = nil
        settings.onboarded = true; settings.save()
    }
    func resetDismissals() { RewriteGuard.clearDismissals(); dismissedCount = 0 }

    // MARK: Appearance

    var appearanceName: String { settings.appearanceRaw ?? "System" }
    var appearanceIcon: String {
        switch appearanceName { case "Light": return "sun.max"; case "Dark": return "moon"; default: return "circle.lefthalf.filled" }
    }
    func cycleAppearance() {
        let order = ["System", "Light", "Dark"]
        let next = order[((order.firstIndex(of: appearanceName) ?? 0) + 1) % order.count]
        settings.appearanceRaw = next; settings.save(); applyAppearance(); objectWillChange.send()
    }
    func applyAppearance() {
        switch appearanceName {
        case "Light": NSApp?.appearance = NSAppearance(named: .aqua)
        case "Dark": NSApp?.appearance = NSAppearance(named: .darkAqua)
        default: NSApp?.appearance = nil
        }
    }

    // MARK: Muted ("I already know this") categories

    func isMuted(_ category: MistakeCategory) -> Bool { settings.mutedCategories.contains(category) }

    func setMuted(_ category: MistakeCategory, _ muted: Bool) {
        var set = settings.mutedCategories
        if muted { set.insert(category) } else { set.remove(category) }
        settings.mutedCategories = set; settings.save()
        if muted {
            // Make sure muted fixes are applied, and drop their review cards.
            for c in changeSet.changes where c.category == category { acceptedChanges.insert(c.id) }
            reviews.removeAll { $0.category == category }; ReviewItem.saveAll(reviews)
        }
        objectWillChange.send()
    }

    /// Changes shown in the review list (muted categories are applied silently).
    var visibleChanges: [Change] { changeSet.changes.filter { !isMuted($0.category) } }
    var quietChanges: [Change] { changeSet.changes.filter { isMuted($0.category) } }

    var isLoading: Bool { loadingMode != nil }
    var openDashboardAction: (() -> Void)?

    private var shortcutMonitor: Any?
    private let bridge = AccessibilityBridge()
    private let coach = CoachService()
    private var coachWindow: NSPanel?
    private var sourceApp: NSRunningApplication?

    init() {
        settings = AppSettings.load()
        settingsEndpoint = settings.endpoint
        settingsModel = settings.model
        history = HistoryItem.loadAll()
        reviews = ReviewItem.loadAll()
        selectedStyle = settings.defaultStyle
        applyAppearance()
        dictionary = UserDefaults.standard.stringArray(forKey: "heyhumanly.dictionary") ?? []
        shortcutLabel = settings.shortcutLabel
        if settings.onboarded != true { onboardingStep = 0 }
        refreshStatus()
        inline.model = self
        watcher.model = self; watcher.session = inline; watcher.start()
        let status = registerHotKey(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
        if HotKey.isUsedByMacOS(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers) {
            shortcutError = "\(shortcutLabel) is also a macOS shortcut, so it may not reach HeyHumanly. Pick a different shortcut in Settings."
        } else if status != noErr {
            shortcutError = "\(shortcutLabel) couldn't be registered (error \(status)). It may be taken by macOS or another app. Pick a different shortcut in Settings."
        }
    }

    // MARK: Windows

    func showCoach() {
        if coachWindow == nil {
            let host = NSHostingView(rootView: CoachPanelView(model: self))
            let panel = CoachPanel(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            panel.title = "Writing coach"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.contentView = host
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(button)?.isHidden = true }
            panel.minSize = NSSize(width: 520, height: 360)
            if let screen = NSScreen.main {   // Spotlight-style: centred, upper third
                let f = screen.visibleFrame
                panel.setFrameOrigin(NSPoint(x: f.midX - 320, y: max(f.minY + 20, f.maxY - 720 - f.height * 0.05)))
            }
            coachWindow = panel
        }
        refreshStatus()
        NSApp.activate(ignoringOtherApps: true)
        coachWindow?.makeKeyAndOrderFront(nil)
        // Put the cursor in the editor so the user can type straight away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let panel = self?.coachWindow, let content = panel.contentView,
                  let textView = Self.firstTextView(in: content) else { return }
            panel.makeFirstResponder(textView)
        }
    }

    private static func firstTextView(in view: NSView) -> NSTextView? {
        if let tv = view as? NSTextView, tv.isEditable { return tv }
        for sub in view.subviews { if let found = firstTextView(in: sub) { return found } }
        return nil
    }

    func closeCoach() { coachWindow?.orderOut(nil) }

    func openDashboard(section: DashboardSection? = nil) {
        if let section { self.section = section }
        NSApp.activate(ignoringOtherApps: true)
        openDashboardAction?()
    }

    // MARK: Status

    /// Re-checks Ollama (and the installed models) and Accessibility. Cheap; called when windows appear.
    func refreshStatus() {
        accessibilityTrusted = AccessibilityBridge.isTrusted
        dismissedCount = RewriteGuard.dismissed.count
        let endpoint = settings.endpoint
        if ollama == .noEndpoint || ollama == .notRunning { ollama = .checking }
        Task {
            let status = await OllamaStatus.check(endpoint: endpoint)
            ollama = status
            if case .running(let models) = status {
                installedModels = models
                if models.contains(settings.model) { await CoachService.prewarm(endpoint: endpoint, model: settings.model) }
            }
        }
    }

    var modelInstalled: Bool { installedModels.contains(settings.model) }

    func selectModel(_ name: String) {
        settings.model = name; settingsModel = name; settings.save()
        refreshStatus()   // also pre-warms the newly selected model
    }

    func saveConnection() {
        settings.endpoint = settingsEndpoint.trimmingCharacters(in: .whitespaces)
        settings.model = settingsModel.trimmingCharacters(in: .whitespaces)
        settings.save()
        refreshStatus()
    }

    // MARK: Stats (all computed from saved sessions)

    var lessonCount: Int { history.filter { $0.mode == .teach }.count }
    var wordsCoached: Int { history.reduce(0) { $0 + $1.original.split(whereSeparator: \.isWhitespace).count } }
    var dayStreak: Int {
        let cal = Calendar.current
        let days = Set(history.map { cal.startOfDay(for: $0.date) })
        var day = cal.startOfDay(for: Date())
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        var streak = 0
        while days.contains(day) { streak += 1; day = cal.date(byAdding: .day, value: -1, to: day)! }
        return streak
    }

    var setupSteps: [SetupStep] {
        let running: Bool = { if case .running = ollama { return true }; return false }()
        return [
            SetupStep(title: "Start Ollama", detail: "Local AI that runs on this Mac", done: running),
            SetupStep(title: "Install \(settings.model)", detail: "ollama pull \(settings.model)", done: running && modelInstalled),
            SetupStep(title: "Allow Accessibility", detail: "Read and replace selected text", done: accessibilityTrusted),
            SetupStep(title: "Try Quick Fix", detail: "Fix a sentence in one step", done: history.contains { $0.mode == .quickFix }),
            SetupStep(title: "Try Teach Me", detail: "Get a lesson and an exercise", done: history.contains { $0.mode == .teach }),
        ]
    }

    // MARK: History

    var filteredHistory: [HistoryItem] {
        let q = historySearch.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return history }
        return history.filter { $0.original.localizedCaseInsensitiveContains(q) || $0.result.rewrite.localizedCaseInsensitiveContains(q) }
    }

    /// Sessions grouped by calendar day, newest first.
    var historyByDay: [(day: Date, items: [HistoryItem])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filteredHistory) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }

    func deleteHistoryItem(_ id: UUID) {
        history.removeAll { $0.id == id }
        HistoryItem.saveAll(history)
    }

    func clearHistory() {
        history = []; HistoryItem.saveAll(history); confirmClearHistory = false
    }

    func reopen(_ item: HistoryItem) {
        currentItem = item
        changeSet = ChangeSet(original: item.original, rewrite: item.result.rewrite)
        if let saved = item.changes, saved.count == changeSet.changes.count { changeSet.changes = saved }
        acceptedChanges = Set(changeSet.changes.map(\.id))
        selectedStyle = item.style ?? settings.defaultStyle
        spotRevealed = true; quiz = nil; proposedRewrites = [:]
        draft = item.original; result = item.result; resultMode = item.mode; selectedMode = item.mode
        sourceApp = nil; sourceAppName = nil; errorMessage = nil; statusMessage = nil
        refreshStyle()
        showCoach()
    }

    // MARK: Dictionary

    func addDictionaryWord(_ raw: String) {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !dictionary.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { return }
        dictionary.append(word)
        UserDefaults.standard.set(dictionary, forKey: "heyhumanly.dictionary")
    }

    func removeDictionaryWord(_ word: String) {
        dictionary.removeAll { $0 == word }
        UserDefaults.standard.set(dictionary, forKey: "heyhumanly.dictionary")
    }

    // MARK: Shortcut

    @discardableResult
    private func registerHotKey(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        HotKey.shared.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.captureSelection()
        }
    }

    func recordShortcut() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        shortcutError = nil
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Copy plain values out of the (non-Sendable) NSEvent before hopping to the main actor.
            let keyCode = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let chars = event.charactersIgnoringModifiers
            let consumed: Bool = MainActor.assumeIsolated {
                guard let self, self.isRecordingShortcut else { return false }
                return self.handleRecordedKey(keyCode: keyCode, flags: flags, chars: chars)
            }
            return consumed ? nil : event
        }
    }

    private func handleRecordedKey(keyCode: UInt16, flags: NSEvent.ModifierFlags, chars: String?) -> Bool {
        if keyCode == UInt16(kVK_Escape) { stopRecording(); return true }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        guard modifiers != 0 else {
            shortcutError = "Hold at least one of Command, Control, Option or Shift with the key. Press Esc to cancel."
            return true
        }
        applyShortcut(keyCode: UInt32(keyCode), modifiers: modifiers, label: Self.label(keyCode: keyCode, chars: chars, modifiers: modifiers))
        stopRecording()
        return true
    }

    func stopRecording() {
        isRecordingShortcut = false
        if let monitor = shortcutMonitor { NSEvent.removeMonitor(monitor); shortcutMonitor = nil }
    }

    private func applyShortcut(keyCode: UInt32, modifiers: UInt32, label: String) {
        if HotKey.isUsedByMacOS(keyCode: keyCode, modifiers: modifiers) {
            // RegisterEventHotKey reports success for combos macOS already owns (e.g. ⌘Space for Spotlight),
            // but those never reach the app, so refuse them up front.
            shortcutError = "\(label) is already used by macOS (System Settings > Keyboard > Keyboard Shortcuts). Still using \(shortcutLabel)."
            appLog.notice("rejected shortcut \(label, privacy: .public): used by macOS")
            return
        }
        let status = registerHotKey(keyCode: keyCode, modifiers: modifiers)
        if status == noErr {
            settings.shortcutKeyCode = keyCode
            settings.shortcutModifiers = modifiers
            settings.shortcutLabel = label
            settings.save()
            shortcutLabel = label
            shortcutError = nil
        } else {
            // Put the previous shortcut back so the user is never left without one.
            registerHotKey(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
            shortcutError = "\(label) couldn't be registered (error \(status)). It's probably used by macOS or another app. Still using \(shortcutLabel)."
        }
    }

    private static let keyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete",
        kVK_ForwardDelete: "Fwd Delete", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
    ]

    static func label(keyCode: UInt16, chars: String?, modifiers: UInt32) -> String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        let key = keyNames[Int(keyCode)]
            ?? chars?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return value + ((key?.isEmpty == false) ? key! : "Key \(keyCode)")
    }

    // MARK: Capture and replace

    func captureSelection() {
        appLog.notice("hotkey fired; frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)")
        errorMessage = nil
        statusMessage = nil
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            showCoach()   // pressed while HeyHumanly is in front: just open the coach
            return
        }
        guard AccessibilityBridge.isTrusted else {
            sourceApp = nil; sourceAppName = nil
            errorMessage = "HeyHumanly needs Accessibility permission to read and replace selected text. Turn it on in System Settings > Privacy & Security > Accessibility, then try again."
            AccessibilityBridge.requestTrust()
            showCoach()
            return
        }
        // Preferred: check the text right inside the app, with underlines and cards.
        // The shortcut on a field that's already being coached opens (or closes) the companion.
        if let el = AXText.focusedElement(), inline.isSameElement(el), inline.phase == .ready {
            inline.toggleExpanded(); return
        }
        AXText.enableManualAccessibility(pid: front.processIdentifier)
        if let el = AXText.focusedElement(),
           inline.start(element: el, appName: front.localizedName ?? "this app", bundleID: front.bundleIdentifier ?? "", auto: false) {
            appLog.notice("inline session started in \(front.localizedName ?? "?", privacy: .public)")
            return
        }
        Task {
            let text = await bridge.selectedText()
            if let text {
                draft = text
                result = .empty; resultMode = nil; statusMessage = nil; practicePrompt = nil; currentItem = nil
                sourceApp = front
                sourceAppName = front.localizedName ?? "the original app"
                sourceBundleID = front.bundleIdentifier
                selectedStyle = front.bundleIdentifier.flatMap { settings.appStyles[$0] } ?? settings.defaultStyle
            } else {
                sourceApp = nil; sourceAppName = nil
                errorMessage = "No text was selected in \(front.localizedName ?? "that app"). Select some text and press \(shortcutLabel), or type or paste here."
            }
            showCoach()
        }
    }

    func apply() {
        errorMessage = nil; statusMessage = nil
        guard !result.rewrite.isEmpty else { return }
        guard let app = sourceApp else {
            errorMessage = "There's no captured selection to replace. Select text in another app and press \(shortcutLabel), or use Copy rewrite."
            return
        }
        let name = sourceAppName ?? "the original app"
        guard !app.isTerminated else {
            sourceApp = nil
            errorMessage = "\(name) is no longer open. Use Copy rewrite instead."
            return
        }
        guard AccessibilityBridge.isTrusted else {
            errorMessage = "Accessibility permission is off, so HeyHumanly can't paste into \(name). Turn it on in System Settings > Privacy & Security > Accessibility."
            return
        }
        let rewrite = finalText
        app.activate(options: [])
        Task {
            var switched = false
            for _ in 0..<50 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { switched = true; break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard switched else {
                errorMessage = "Couldn't switch back to \(name). Use Copy rewrite instead."
                return
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            await bridge.replaceSelectedText(with: rewrite)
            statusMessage = "Replaced in \(name) · ⌘Z there to undo"
            sourceApp = nil   // the original selection no longer exists
        }
    }

    func copyRewrite() {
        guard !result.rewrite.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(finalText, forType: .string)
        errorMessage = nil
        statusMessage = "Copied to clipboard"
    }

    // MARK: Coaching

    func run() { analyze(mode: selectedMode) }

    // MARK: Change review

    /// The result with only the accepted changes applied.
    var finalText: String {
        changeSet.changes.isEmpty ? result.rewrite : changeSet.text(accepted: acceptedChanges)
    }

    func toggleChange(_ id: UUID) {
        if acceptedChanges.contains(id) { acceptedChanges.remove(id) } else { acceptedChanges.insert(id) }
        statusMessage = nil
        refreshStyle()
    }

    func setAllChanges(_ on: Bool) {
        acceptedChanges = on ? Set(changeSet.changes.map(\.id)) : []
    }

    /// Second, short model call: category + reason for every locally computed change.
    private func explainChanges(itemID: UUID, original: String, rewrite: String, endpoint: String, model: String) async {
        // Mechanical edits (spelling, capitals, punctuation) are already categorised locally; the model
        // only explains the rest, which keeps this call short.
        // The rule book answers first: exact, instant, and never invented.
        for i in changeSet.changes.indices {
            let loc = changeSet.changes[i].location
            if RuleBook.match(from: changeSet.changes[i].from, to: changeSet.changes[i].to, original: original, location: loc) != nil {
                changeSet.changes[i].teach(original: original, location: loc)
            }
        }
        let pendingIndices = changeSet.changes.indices.filter { changeSet.changes[$0].pending }
        guard !pendingIndices.isEmpty else {
            if let index = history.firstIndex(where: { $0.id == itemID }) {
                history[index].changes = changeSet.changes
                if currentItem?.id == itemID { currentItem = history[index] }
                HistoryItem.saveAll(history); addReviews(from: history[index])
            }
            return
        }
        explaining = true
        let subset = pendingIndices.map { changeSet.changes[$0] }
        let explainedSubset = await CoachService.explain(original: original, rewrite: rewrite, changes: subset, endpoint: endpoint, model: model)
        explaining = false
        var explained: [Int: (MistakeCategory, String)] = [:]
        if let explainedSubset { for (k, i) in pendingIndices.enumerated() where k < explainedSubset.count { explained[i] = explainedSubset[k] } }
        var updated = changeSet
        for i in updated.changes.indices {
            let guess = ChangeSet.guessCategory(from: updated.changes[i].from, to: updated.changes[i].to)
            if let e = explained[i] {
                // Mechanical categories from the local check beat the model's guess.
                updated.changes[i].category = guess ?? e.0
                if !e.1.isEmpty { updated.changes[i].reason = e.1 }
            }
            if updated.changes[i].reason.isEmpty { updated.changes[i].reason = updated.changes[i].category.fallbackReason }
            updated.changes[i].pending = false
        }
        // Only update if the coach is still showing this session.
        if currentItem?.id == itemID { changeSet = updated }
        if let index = history.firstIndex(where: { $0.id == itemID }) {
            history[index].changes = updated.changes
            if currentItem?.id == itemID { currentItem = history[index] }
            HistoryItem.saveAll(history)
            addReviews(from: history[index])
        }
    }

    private func loadLesson(itemID: UUID, original: String, rewrite: String, endpoint: String, model: String) async {
        lessonLoading = true
        let lesson = await CoachService.lesson(original: original, rewrite: rewrite, endpoint: endpoint, model: model)
        lessonLoading = false
        guard let (explanation, exercise) = lesson else { return }
        let updated = CoachResult(rewrite: rewrite, explanation: explanation, exercise: exercise)
        if currentItem?.id == itemID { result = updated }
        if let index = history.firstIndex(where: { $0.id == itemID }) {
            let old = history[index]
            let item = HistoryItem(copying: old, result: updated)
            history[index] = item
            if currentItem?.id == itemID { currentItem = item }
            HistoryItem.saveAll(history)
        }
    }

    // MARK: Inline session bookkeeping

    /// Saves an inline check as a session so Insights and Review learn from it. Returns its id.
    func recordInline(original: String, rewrite: String, style: WritingStyle, appName: String, changes: [Change]) -> UUID {
        let item = HistoryItem(original: original, result: CoachResult(rewrite: rewrite, explanation: "", exercise: ""),
                               mode: .quickFix, style: style, appName: appName, changes: changes)
        history.insert(item, at: 0)
        history = Array(history.prefix(500)); HistoryItem.saveAll(history)
        return item.id
    }

    func updateInline(historyID: UUID, changes: [Change]) {
        guard let index = history.firstIndex(where: { $0.id == historyID }) else { return }
        history[index].changes = changes
        HistoryItem.saveAll(history)
        addReviews(from: history[index])
    }

    func noteInlineAccepted(_ change: Change) {
        appLog.notice("inline accepted \(change.category.rawValue, privacy: .public)")
    }

    /// Menu / button entry point: check the text field of the app that was frontmost before HeyHumanly.
    func checkFrontApp() { captureSelection() }

    // MARK: Review (spaced repetition of the user's own mistakes)

    var dueReviews: [ReviewItem] { reviews.filter { $0.due <= Date() && !isMuted($0.category) }.sorted { $0.due < $1.due } }
    /// The card on screen. Pinned after answering so the feedback stays with the card it belongs to.
    @Published var pinnedReviewID: UUID?
    var currentReview: ReviewItem? {
        if let id = pinnedReviewID, let item = reviews.first(where: { $0.id == id }) { return item }
        let due = dueReviews; return reviewIndex < due.count ? due[reviewIndex] : nil
    }

    private func addReviews(from item: HistoryItem) {
        guard let changes = item.changes else { return }
        var added = 0
        for change in changes where change.category != .capitalization && change.category != .punctuation && change.category != .tone && !isMuted(change.category) {
            guard !change.from.isEmpty, !change.to.isEmpty,
                  !reviews.contains(where: { $0.from.lowercased() == change.from.lowercased() && $0.to.lowercased() == change.to.lowercased() }) else { continue }
            let (sentence, corrected) = Self.sentencePair(original: item.original, rewrite: item.result.rewrite, containing: change.from)
            reviews.append(ReviewItem(created: Date(), sentence: sentence, corrected: corrected, from: change.from, to: change.to,
                                      category: change.category, reason: change.reason,
                                      due: Date().addingTimeInterval(20 * 3600)))   // first review tomorrow
            added += 1
            if added >= 3 { break }
        }
        if added > 0 { ReviewItem.saveAll(reviews) }
    }

    /// The sentence that contains the mistake, and its corrected counterpart.
    static func sentencePair(original: String, rewrite: String, containing fragment: String) -> (String, String) {
        func sentences(_ t: String) -> [String] {
            var out: [String] = []
            t.enumerateSubstrings(in: t.startIndex..., options: .bySentences) { s, _, _, _ in
                if let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { out.append(s) }
            }
            return out.isEmpty ? [t] : out
        }
        let o = sentences(original), r = sentences(rewrite)
        guard let i = o.firstIndex(where: { $0.contains(fragment) }) else { return (original, rewrite) }
        if o.count == r.count { return (o[i], r[i]) }
        // Sentence counts differ (e.g. a comma splice became two sentences): pick the corrected
        // sentence(s) that share the most words with the original sentence.
        let words = { (s: String) in Set(s.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)) }
        let target = words(o[i])
        var best = (score: -1, text: rewrite)
        for start in r.indices {
            for end in start..<min(r.count, start + 3) {
                let candidate = r[start...end].joined(separator: " ")
                let cw = words(candidate)
                let score = target.intersection(cw).count * 2 - cw.subtracting(target).count - target.subtracting(cw).count
                if score > best.score { best = (score, candidate) }
            }
        }
        return (o[i], best.text)
    }

    @Published var reviewHintShown = false

    func checkReview() {
        guard let item = currentReview, let idx = reviews.firstIndex(where: { $0.id == item.id }) else { return }
        let correct = item.check(reviewAnswer)
        pinnedReviewID = item.id
        reviewFeedback = correct
        reviews[idx].record(correct: correct)
        ReviewItem.saveAll(reviews)
    }

    func nextReview() {
        reviewAnswer = ""; reviewFeedback = nil; reviewHintShown = false; pinnedReviewID = nil
        // The answered item moved out of "due" (or to 10 minutes later), so index 0 is the next one.
        reviewIndex = 0
    }

    func skipReview() {
        guard let item = currentReview, let idx = reviews.firstIndex(where: { $0.id == item.id }) else { return }
        reviews[idx].due = Date().addingTimeInterval(86_400)
        ReviewItem.saveAll(reviews); nextReview()
    }

    var masteredCount: Int { reviews.filter(\.mastered).count }

    // MARK: Model download

    /// Bigger models give much better corrections; 7B runs well on 16 GB Apple silicon Macs.
    var recommendedModel: String { ProcessInfo.processInfo.physicalMemory >= 15_000_000_000 ? "qwen2.5:7b" : "qwen2.5:3b" }

    func download(model name: String) {
        guard pullProgress == nil else { return }
        pullProgress = 0; pullStatus = "Starting download…"
        let endpoint = settings.endpoint
        Task {
            do {
                try await CoachService.pull(model: name, endpoint: endpoint) { [weak self] fraction, status in
                    self?.pullProgress = fraction
                    self?.pullStatus = status == "success" ? "Installed" : (status.hasPrefix("pulling") ? "Downloading" : status.capitalized)
                }
                pullProgress = nil; pullStatus = ""
                selectModel(name)
                refreshStatus()
            } catch {
                pullProgress = nil; pullStatus = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Insights

    var categoryStats: [CategoryStat] { Insights.stats(history: history).filter { !isMuted($0.category) } }

    var privacyIsLocal: Bool {
        guard let host = URLComponents(string: settings.endpoint)?.host?.lowercased() else { return false }
        return ["localhost", "127.0.0.1", "::1", "0.0.0.0"].contains(host)
    }

    func practice(_ item: HistoryItem) {
        clearDraft()
        practicePrompt = item.result.exercise
        selectedMode = .quickFix
        showCoach()
    }

    func clearDraft() {
        practicePrompt = nil
        currentItem = nil
        draft = ""; result = .empty; resultMode = nil; errorMessage = nil; statusMessage = nil
        sourceApp = nil; sourceAppName = nil; sourceBundleID = nil
        changeSet = ChangeSet(); acceptedChanges = []; selectedStyle = settings.defaultStyle
        styleFindings = []; proposedRewrites = [:]; quiz = nil; spotPicked = []; spotRevealed = true
    }

    func analyze(mode: CoachMode) {
        selectedMode = mode
        let original = draft
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Type or paste some text first."
            return
        }
        loadingMode = mode; errorMessage = nil; statusMessage = nil
        let endpoint = settings.endpoint, modelName = settings.model, words = dictionary
        let style = selectedStyle, app = sourceAppName
        streamingText = ""
        // Keep macOS from App-Napping us mid-request (we're often not the frontmost app).
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Coaching text")
        Task {
            defer { ProcessInfo.processInfo.endActivity(activity) }
            do {
                var rewrite = try await CoachService.streamRewrite(text: original, style: style, appName: app, preserve: words,
                                                                   endpoint: endpoint, model: modelName) { [weak self] token in
                    self?.streamingText += token
                }
                // Light styles must not change meaning, slang or harmless wording.
                if style == .fixOnly || style == .polish { rewrite = RewriteGuard.sanitize(original: original, rewrite: rewrite, preserve: words) }
                let response = CoachResult(rewrite: rewrite, explanation: "", exercise: "")
                let set = ChangeSet(original: original, rewrite: response.rewrite)
                changeSet = set
                acceptedChanges = Set(set.changes.map(\.id))
                result = response; resultMode = mode; loadingMode = nil
                refreshStyle()
                quiz = nil; spotPicked = []
                spotRevealed = !(tryFirst && !visibleChanges.isEmpty)
                let item = HistoryItem(original: original, result: response, mode: mode, style: style, appName: app, changes: set.changes)
                currentItem = item
                history.insert(item, at: 0)
                history = Array(history.prefix(500)); HistoryItem.saveAll(history)
                await explainChanges(itemID: item.id, original: original, rewrite: response.rewrite, endpoint: endpoint, model: modelName)
                if mode == .teach { await loadLesson(itemID: item.id, original: original, rewrite: rewrite, endpoint: endpoint, model: modelName) }
            } catch {
                appLog.error("analyze failed: \(String(describing: error), privacy: .public)")
                errorMessage = error.localizedDescription
                loadingMode = nil
            }
        }
    }
}

enum DashboardSection: String, CaseIterable, Identifiable {
    case home = "Home", insights = "Insights", review = "Review", history = "History", dictionary = "Dictionary", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .insights: return "chart.bar.xaxis"
        case .review: return "rectangle.stack"
        case .dictionary: return "character.book.closed"
        case .settings: return "gearshape"
        }
    }
}

struct SetupStep: Identifiable {
    let title: String; let detail: String; let done: Bool
    var id: String { title }
}

enum OllamaStatus: Equatable {
    case checking, running([String]), notRunning, noEndpoint

    /// GET <host>/api/tags lists installed models; derived from the generate endpoint's host.
    static func check(endpoint: String) async -> OllamaStatus {
        guard var comps = URLComponents(string: endpoint), comps.host != nil else { return .noEndpoint }
        comps.path = "/api/tags"; comps.query = nil
        guard let url = comps.url else { return .noEndpoint }
        var request = URLRequest(url: url); request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return .notRunning }
        struct Tags: Decodable { struct M: Decodable { let name: String }; let models: [M] }
        let names = (try? JSONDecoder().decode(Tags.self, from: data))?.models.map(\.name) ?? []
        return .running(names.sorted())
    }
}

/// Floating, key-capable panel for the coach. Esc closes it.
final class CoachPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
