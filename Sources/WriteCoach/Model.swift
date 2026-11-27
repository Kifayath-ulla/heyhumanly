import SwiftUI
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class CoachModel: ObservableObject {
    @Published var allowance: Allowance?
    @Published var onlineLimitHit = false
    @Published var onlineFailed = false
    @Published var showConsent = false
    @Published var showOfflineSetup = false
    @Published var appleAvailability = AppleModel.availabilityDescription
    let runtime = OfflineRuntime.shared
    @Published var browserAllowed: Bool? = nil
    @Published var browserBusy = false
    @Published var browserNote: String? = nil
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var settings = AppSettings()
    @Published var settingsEndpoint = ""
    @Published var settingsModel = ""
    @Published var ollama: OllamaStatus = .checking
    @Published var installedModels: [String] = []
    @Published var accessibilityTrusted = AccessibilityBridge.isTrusted
    /// Fix access was pressed and HeyHumanly is waiting for the Accessibility switch.
    @Published var fixingAccess = false
    private var accessPoll: Task<Void, Never>?
    @Published var isRecordingShortcut = false
    @Published var shortcutLabel = "⌃⌥Space"
    @Published var shortcutError: String?
    @Published var pullProgress: Double?
    @Published var pullStatus = ""
    @Published var snoozedUntil: Date?
    @Published var dismissedCount = RewriteGuard.dismissed.count
    @Published var settingsTab: SettingsTab = .general

    let inline = InlineSession()
    let quick = QuickSession()
    let watcher = TextWatcher()
    /// Opens the Settings scene; set by the menu bar item, which has SwiftUI's openSettings action.
    var openSettingsAction: (() -> Void)?
    /// The sample box in the welcome window, so ⌃⌥Space works there before any permission.
    weak var onboardingSample: NSTextView?
    private var onboardingWindow: NSWindow?
    private var shortcutMonitor: Any?

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
    /// Brings back dismissed suggestions and mistake types muted with "Stop flagging…".
    func resetDismissals() {
        RewriteGuard.clearDismissals(); dismissedCount = 0
        settings.mutedCategories = []; settings.save()
    }
    func isMuted(_ category: MistakeCategory) -> Bool { settings.mutedCategories.contains(category) }

    func setMuted(_ category: MistakeCategory, _ muted: Bool) {
        var set = settings.mutedCategories
        if muted { set.insert(category) } else { set.remove(category) }
        settings.mutedCategories = set; settings.save()
        objectWillChange.send()
    }

    init() {
        settings = AppSettings.load()
        AppSettings.removeRetiredData()
        settingsEndpoint = settings.endpoint
        settingsModel = settings.model
        shortcutLabel = settings.shortcutLabel
        appLog.notice("apple on-device availability: \(AppleModel.availabilityDescription, privacy: .public)")
        startEngineOnLaunch()
        refreshStatus()
        Task { await autoPickEngine() }
        inline.model = self
        watcher.model = self; watcher.session = inline; watcher.start()
        let status = registerHotKey(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
        appLog.notice("accessibility trusted at launch: \(self.accessibilityTrusted)")
        if HotKey.isUsedByMacOS(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers) {
            shortcutError = shortcutConflict
        } else if status != noErr {
            shortcutError = "\(shortcutLabel) couldn't be registered (error \(status)). It may be taken by macOS or another app. Pick a different shortcut in Settings."
        }
        if settings.onboarded != true { DispatchQueue.main.async { [weak self] in self?.showOnboarding() } }
    }

    // MARK: Windows

    func openSettings(_ tab: SettingsTab? = nil) {
        if let tab { settingsTab = tab }
        NSApp.activate(ignoringOtherApps: true)
        openSettingsAction?()
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 440), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.center()
            onboardingWindow = w
        }
        // A fresh view each time, so Show Welcome Again starts on the first step.
        if onboardingWindow?.isVisible != true { onboardingWindow?.contentView = NSHostingView(rootView: OnboardingView(model: self)) }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    func finishOnboarding() {
        settings.onboarded = true; settings.save()
        onboardingWindow?.close()
    }

    /// Starts HeyHumanly at login (macOS asks the user to confirm in System Settings > General > Login Items).
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do { newValue ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
            catch { statusMessage = "Couldn't change Open at Login: \(error.localizedDescription)" }
            objectWillChange.send()
        }
    }

    // MARK: Status

    /// Re-checks Ollama (and the installed models) and Accessibility. Cheap; called when windows appear.
    func refreshStatus() {
        accessibilityTrusted = AccessibilityBridge.isTrusted
        refreshShortcutConflict()
        dismissedCount = RewriteGuard.dismissed.count
        appleAvailability = AppleModel.availabilityDescription
        if settings.engine == .offlineManaged { Task { await runtime.startServer() } }
        refreshAllowance()
        let endpoint = settings.endpoint
        if ollama == .noEndpoint || ollama == .notRunning { ollama = .checking }
        Task {
            let status = await OllamaStatus.check(endpoint: endpoint)
            ollama = status
            if case .running(let models) = status {
                installedModels = models
                if settings.engine == .ollama, models.contains(where: { CoachModel.sameModel($0, settings.model) }) { await CoachService.prewarm(endpoint: endpoint, model: settings.model) }
            }
        }
    }

    /// Keeps the status dots in step with what a coaching just found: Ollama stopped (or its model gone),
    /// or working again after an outage. Only for the user's own Ollama, so other engines never probe it.
    func syncOllamaStatus(after error: Error?) {
        guard settings.engine == .ollama else { return }
        if let error {
            switch error as? CoachError {
            case .ollamaNotRunning, .modelMissing: refreshStatus()
            default: break
            }
        } else if !ollamaRunning || !modelInstalled {
            refreshStatus()
        }
    }

    var modelInstalled: Bool { installedModels.contains { CoachModel.sameModel($0, settings.model) } }

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
        let isDefault = keyCode == UInt32(kVK_Space) && modifiers == UInt32(controlKey | optionKey)
        // The default ⌃⌥Space is always allowed back (as at launch, macOS's input-source shortcut only gets a warning).
        if !isDefault, HotKey.isUsedByMacOS(keyCode: keyCode, modifiers: modifiers) {
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
            shortcutError = isDefault && HotKey.isUsedByMacOS(keyCode: keyCode, modifiers: modifiers) ? shortcutConflict : nil
        } else {
            // Put the previous shortcut back so the user is never left without one.
            registerHotKey(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
            shortcutError = "\(label) couldn't be registered (error \(status)). It's probably used by macOS or another app. Still using \(shortcutLabel)."
        }
    }

    private var shortcutConflict: String { "\(shortcutLabel) is also a macOS shortcut, so it may not reach HeyHumanly. Pick a different shortcut in Settings." }

    /// Input sources can be added or removed while HeyHumanly runs, so the warning is checked again when windows appear.
    private func refreshShortcutConflict() {
        let used = HotKey.isUsedByMacOS(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
        if used, shortcutError == nil { shortcutError = shortcutConflict } else if !used, shortcutError == shortcutConflict { shortcutError = nil }
    }

    // MARK: Accessibility

    /// One plain sentence on why access is missing, for Settings, the panel and the welcome window.
    let accessibilityHelp = "macOS needs HeyHumanly switched on in Accessibility, and again after each update, even if its switch already looks on."
    let fixingAccessHelp = "In the macOS prompt, click Open System Settings, then switch HeyHumanly on. HeyHumanly picks it up by itself."

    /// Fix access: removes HeyHumanly's stale Accessibility entry, asks macOS again and waits for the switch.
    /// System Settings isn't opened here: it would cover the macOS prompt, and the list only gains HeyHumanly once
    /// the prompt is answered. The prompt's own button opens the list; views offer a link in case no prompt appears.
    func fixAccessibility(fromPanel: Bool = false) {
        fixingAccess = true
        Task {
            let reset = await AccessibilityBridge.resetOwnGrant()
            appLog.notice("fix access: tccutil reset ok=\(reset)")
            AccessibilityBridge.requestTrust()
            watchAccessibility(fromPanel: fromPanel)
        }
    }

    /// Stops waiting for the switch, e.g. when the user picks Copy instead after declining the prompt.
    func stopFixingAccess() {
        accessPoll?.cancel()
        fixingAccess = false
    }

    private func watchAccessibility(fromPanel: Bool) {
        accessPoll?.cancel()
        let started = Date()
        accessPoll = Task { [weak self] in
            // Up to 10 minutes, once a second: macOS reports the new switch without a relaunch.
            for _ in 0..<600 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.accessibilityTrusted = AccessibilityBridge.isTrusted
                if self.accessibilityTrusted {
                    self.fixingAccess = false
                    appLog.notice("fix access: trusted again after \(Int(Date().timeIntervalSince(started)))s")
                    if fromPanel { self.quick.accessRestored(model: self) }
                    return
                }
            }
            self?.fixingAccess = false
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

    // MARK: Capture

    /// ⌃⌥Space: rewrite the selection in the frontmost app (or the welcome window's sample box).
    func captureSelection() {
        appLog.notice("hotkey fired; frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil", privacy: .public)")
        errorMessage = nil
        statusMessage = nil
        // The shortcut again while the panel is open closes it.
        if quick.isOpen { quick.close(); return }
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        if front.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            if let sample = onboardingSample, sample.window?.isVisible == true { quick.openSample(model: self, textView: sample) }
            return
        }
        accessibilityTrusted = AccessibilityBridge.isTrusted
        guard accessibilityTrusted else { quick.openFromClipboard(model: self, front: front); return }
        quick.open(model: self, front: front)
    }

    /// The menu closes first so the source app is frontmost again when the selection is read.
    func fixSelectionFromMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.captureSelection() }
    }

    func engineSelectable(_ e: CoachEngine) -> Bool {
        switch e {
        case .appleOnDevice: return appleAvailability == "available"
        case .ollama: return ollamaDetected
        case .online, .offlineManaged: return true
        }
    }

    /// Same as picking it in Settings: online asks for consent and offline runs setup there first.
    func chooseEngine(_ e: CoachEngine) {
        if e == .online && !settings.onlineConsent { showConsent = true; openSettings(.engine) }
        else if e == .offlineManaged && !(OfflineRuntime.isInstalled && settings.managedModelRaw != nil) { runtime.prepare(); openSettings(.engine) }
        else if e == .ollama { useMyOllama() }
        else { setEngine(e) }
    }

    func noteInlineAccepted(_ change: Change) {
        appLog.notice("inline accepted \(change.category.rawValue, privacy: .public)")
    }

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
                // Only pick it if Settings still points at the server it was downloaded to.
                guard settings.endpoint == endpoint else { refreshStatus(); return }
                selectModel(name)
                refreshStatus()
            } catch {
                pullProgress = nil; pullStatus = "Download failed: \(error.localizedDescription)"
            }
        }
    }
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


enum SettingsTab: Hashable { case general, engine, privacy }
