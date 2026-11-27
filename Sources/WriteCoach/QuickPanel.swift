import SwiftUI
import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// The ⌃⌥Space panel: a small floating window next to the selection that rewrites it in one of five styles.
/// It never activates HeyHumanly, so the source app keeps focus; Enter pastes the rewrite over the selection.
@MainActor
final class QuickSession: ObservableObject {
    @Published var original = ""
    @Published var streamed = ""
    @Published var rewrite: String?
    @Published var changes: [Change] = []
    @Published var style: WritingStyle = .polish
    @Published var busy = false
    @Published var error: String?
    @Published var notice: String?
    @Published var showWhy = false
    @Published var appName = ""
    /// No Accessibility permission: the panel says so and offers Fix access; ⌘R rewrites the clipboard and Enter copies it.
    @Published var copyOnly = false

    weak var model: CoachModel?
    private var panel: QuickPanelWindow?
    private var element: AXUIElement?
    private var range: CFRange?
    private var pid: pid_t = 0
    private var anchor: NSRect?
    private var cache: [WritingStyle: String] = [:]
    private var task: Task<Void, Never>?
    private var generation = 0
    private var monitor: Any?
    private var undoKeys = SessionKeys(base: 300)
    private var undoExpiry: Task<Void, Never>?
    private var undoObserver: NSObjectProtocol?
    /// The welcome window's sample box, which is ours so it needs no permission.
    private weak var sample: NSTextView?
    private var sampleRange: NSRange?

    var isOpen: Bool { panel?.isVisible == true }
    var hasText: Bool { !original.isEmpty }

    // MARK: Opening

    /// Reads the selection in the frontmost app and opens the panel next to it.
    func open(model: CoachModel, front: NSRunningApplication) {
        self.model = model
        task?.cancel(); generation += 1
        clearUndo()
        appName = front.localizedName ?? "this app"
        pid = front.processIdentifier
        original = ""; streamed = ""; rewrite = nil; changes = []; error = nil; notice = nil; cache = [:]
        element = nil; range = nil; anchor = nil; sample = nil; sampleRange = nil; copyOnly = false
        style = front.bundleIdentifier.flatMap { model.settings.appStyles[$0] } ?? model.settings.defaultStyle

        AXText.enableManualAccessibility(pid: pid)
        if let el = AXText.focusedElement(), !AXText.isSecure(el), let r = AXText.selectedRange(el), r.length > 0,
           let value = AXText.string(el, kAXValueAttribute) {
            let ns = value as NSString
            if r.location >= 0, r.location + r.length <= ns.length {
                element = el; range = r
                original = ns.substring(with: NSRange(location: r.location, length: r.length))
            }
            anchor = AXText.bounds(el, location: r.location, length: r.length).map(AXText.toCocoa)
        } else if let el = AXText.focusedElement(), let r = AXText.selectedRange(el) {
            // No usable selection yet: remember the caret so the panel still opens beside it.
            anchor = (AXText.bounds(el, location: r.location, length: 0) ?? AXText.bounds(el, location: max(0, r.location - 1), length: 1)).map(AXText.toCocoa)
        }
        if original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = ""; element = nil; range = nil
            let gen = generation
            // Apps without an Accessibility text value (some web views): copy the selection with ⌘C.
            Task {
                let text = await AccessibilityBridge().selectedText()
                guard gen == self.generation else { return }
                if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.original = text }
                self.show()
                self.hasText ? self.start(bundleID: front.bundleIdentifier) : self.fail("Select some text in \(self.appName), then press \(model.shortcutLabel).")
            }
            return
        }
        show()
        start(bundleID: front.bundleIdentifier)
    }

    /// The sample box in the welcome window: same panel and rewrite, written back into the box.
    func openSample(model: CoachModel, textView: NSTextView) {
        self.model = model
        task?.cancel(); generation += 1
        clearUndo()
        appName = "HeyHumanly"; pid = ProcessInfo.processInfo.processIdentifier
        original = ""; streamed = ""; rewrite = nil; changes = []; error = nil; notice = nil; cache = [:]
        element = nil; range = nil; copyOnly = false
        style = model.settings.defaultStyle
        var r = textView.selectedRange()
        if r.length == 0 { r = NSRange(location: 0, length: (textView.string as NSString).length) }
        sample = textView; sampleRange = r
        original = (textView.string as NSString).substring(with: r)
        let rect = textView.firstRect(forCharacterRange: r, actualRange: nil)
        anchor = rect == .zero ? textView.window?.frame : rect
        show()
        original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fail("Type or select some text in the box, then press \(model.shortcutLabel).") : run()
    }

    /// Without Accessibility HeyHumanly can't read the selection. The panel says so and offers Fix access; the copied text
    /// is only rewritten when you ask (⌘R), unless you chose "Copy instead" in the welcome window. Enter copies the result.
    func openFromClipboard(model: CoachModel, front: NSRunningApplication) {
        self.model = model
        task?.cancel(); generation += 1
        clearUndo()
        appName = front.localizedName ?? "this app"
        pid = front.processIdentifier
        original = ""; streamed = ""; rewrite = nil; changes = []; error = nil; notice = nil; cache = [:]
        element = nil; range = nil; anchor = nil; sample = nil; sampleRange = nil; copyOnly = true
        style = front.bundleIdentifier.flatMap { model.settings.appStyles[$0] } ?? model.settings.defaultStyle
        original = NSPasteboard.general.string(forType: .string) ?? ""
        show()
        if original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            original = ""
            layout()
        } else if !model.settings.copyInstead {
            notice = "Shown: the text you last copied, not your selection. ⌘R rewrites it and Enter copies the result."
            layout()
        } else if model.isOnline {
            // The clipboard may hold something older than the selection, so nothing is sent online until you ask.
            notice = "This is the text you last copied. Press ⌘R to rewrite it online."
            layout()
        } else {
            start(bundleID: front.bundleIdentifier)
        }
    }

    /// Apps on the "Never read text in" list don't get an automatic rewrite: nothing is sent until you ask (⌘R, ⇥, ⌘1–5).
    private func start(bundleID: String?) {
        if let bundleID, model?.settings.pausedApps.contains(bundleID) == true {
            notice = "HeyHumanly doesn't read \(appName) on its own. Press ⌘R to rewrite this selection."
            layout()
        } else {
            run()
        }
    }

    func fixAccess() { model?.fixAccessibility(fromPanel: true) }

    /// Fix access worked: say so where the panel last was, so the next shortcut press replaces the selection.
    func accessRestored(model: CoachModel) {
        self.model = model
        task?.cancel(); generation += 1
        original = ""; streamed = ""; rewrite = nil; changes = []; error = nil; cache = [:]; copyOnly = false
        element = nil; range = nil; sample = nil; sampleRange = nil
        notice = "Accessibility is on again. Select text in \(appName) and press \(model.shortcutLabel) to replace it."
        show()
    }

    private func show() {
        if panel == nil {
            let p = QuickPanelWindow(rootView: AnyView(QuickPanelView(session: self)))
            p.onResignKey = { [weak self] in self?.close() }
            panel = p
        }
        guard let panel else { return }
        layout()
        // Key (so it gets Enter, Esc and Tab) without activating HeyHumanly: the source app stays frontmost.
        panel.makeKeyAndOrderFront(nil)
        installMonitor()
    }

    func close() {
        task?.cancel(); generation += 1
        busy = false
        removeMonitor()
        panel?.orderOut(nil)
        sample?.window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Placement

    private static let width: CGFloat = 480

    /// Below the selection when it fits, else above it; else near the caret or mouse; else the middle of the screen.
    func layout() {
        guard let panel, let host = panel.contentView else { return }
        let fitting = host.fittingSize
        let size = NSSize(width: Self.width, height: min(max(fitting.height, 96), 520))
        let gap: CGFloat = 8
        let target: NSRect = {
            if let a = anchor, a.width > 0 || a.height > 0, NSScreen.screens.contains(where: { $0.frame.intersects(a.insetBy(dx: -1, dy: -1)) }) { return a }
            let m = NSEvent.mouseLocation
            return NSRect(x: m.x, y: m.y, width: 1, height: 1)
        }()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: target.midX, y: target.midY)) }) ?? NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin: NSPoint
        if anchor == nil && !visible.contains(NSPoint(x: target.midX, y: target.midY)) {
            origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        } else {
            origin = NSPoint(x: target.minX, y: target.minY - gap - size.height)
            if origin.y < visible.minY { origin.y = target.maxY + gap }
            if origin.y + size.height > visible.maxY { origin.y = max(visible.minY, visible.maxY - size.height) }
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        // Keep the top edge still while the text streams in.
        if panel.isVisible, abs(panel.frame.width - size.width) < 1, panel.frame.minY > target.maxY {
            origin.y = panel.frame.minY
        } else if panel.isVisible, abs(panel.frame.width - size.width) < 1, panel.frame.maxY < target.minY + 1 {
            origin.y = panel.frame.maxY - size.height
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    // MARK: Rewriting

    func select(_ s: WritingStyle) {
        guard s != style || rewrite == nil && !busy else { return }
        style = s
        run()
    }

    func step(_ by: Int) {
        let all = WritingStyle.allCases
        let i = all.firstIndex(of: style) ?? 0
        select(all[(i + by + all.count) % all.count])
    }

    func retry() {
        cache[style] = nil
        run(temperature: 0.4)
    }

    func run(temperature: Double = 0.1) {
        guard let model, hasText else { return }
        task?.cancel(); generation += 1
        let gen = generation
        error = nil; notice = nil
        if let cached = cache[style] { finish(cached); return }
        // Same rule as the coach: no engine yet, or online without consent, shows the choice instead of a request.
        guard model.readyToCoach() else {
            if let message = model.errorMessage { model.errorMessage = nil; fail(message) } else { busy = false; layout() }
            return
        }
        busy = true; streamed = ""; rewrite = nil; changes = []
        layout()
        let text = original, chosen = style, app = appName, words: [String] = []
        let endpoint = model.activeEndpoint, modelName = model.activeModel, online = model.isOnline
        task = Task { [weak self] in
            do {
                var out: String
                if online {
                    // Only the text and goal go online; explanations come from the local rule book.
                    out = try await model.coachOnline(text: text, goal: OnlineCoach.goal(chosen)).rewrite
                } else {
                    out = try await CompanionService.streamRewrite(text, style: chosen, appName: app, preserve: words, endpoint: endpoint,
                                                                   model: modelName, temperature: temperature) { [weak self] token in
                        guard let self, gen == self.generation else { return }
                        self.streamed += token
                        self.layout()
                    }
                }
                guard let self, gen == self.generation, !Task.isCancelled else { return }
                // Light styles must not change meaning, slang or harmless wording.
                out = TextSafety.dropFiller(original: text, rewrite: out)
                out = chosen.guarded ? RewriteGuard.sanitize(original: text, rewrite: out, preserve: words, fixOnly: chosen == .fixOnly)
                                     : TextSafety.apply(original: text, rewrite: out, preserve: words, keepSlang: chosen != .professional)
                out = TextSafety.dropReply(original: text, rewrite: out, preserve: words, keepSlang: chosen != .professional)
                out = TextSafety.dropInvented(original: text, rewrite: out, preserve: words, keepSlang: chosen != .professional, friendly: chosen == .friendly)
                self.cache[chosen] = out
                self.finish(out)
            } catch {
                guard let self, gen == self.generation, !Task.isCancelled else { return }
                self.fail(error.localizedDescription)
            }
        }
    }

    private func finish(_ out: String) {
        busy = false
        rewrite = out
        // Explanations describe exactly the edits shown in the diff.
        changes = ChangeSet(original: original, rewrite: out).changes.map { c -> Change in
            var c = c; c.teach(original: original, location: c.location); return c
        }
        if out == original { notice = "Looks good. Nothing to change." }
        layout()
    }

    private func fail(_ message: String) {
        busy = false
        error = message
        layout()
    }

    var displayed: AttributedString {
        if let rewrite { return WordDiff.attributed(original, rewrite) }
        guard !streamed.isEmpty else { return AttributedString(original) }
        // While streaming, compare against the same number of original words so the diff grows with the text.
        let words = streamed.split(whereSeparator: \.isWhitespace).count
        var count = 0, end = original.endIndex
        var i = original.startIndex, inWord = false
        while i < original.endIndex {
            let ws = original[i].isWhitespace
            if !ws && !inWord { count += 1; if count > words { end = i; break } }
            inWord = !ws
            i = original.index(after: i)
        }
        let prefix = String(original[..<end]).trimmingCharacters(in: .whitespaces)
        return WordDiff.attributed(prefix, streamed, showRemoved: true)
    }

    // MARK: Actions

    func copy() {
        guard let text = rewrite else { return }
        let pb = NSPasteboard.general
        pb.clearContents(); pb.setString(text, forType: .string)
        notice = "Copied."
        layout()
    }

    func replace() {
        guard let text = rewrite, !busy else { return }
        guard text != original else { close(); return }
        if copyOnly {
            let pb = NSPasteboard.general
            pb.clearContents(); pb.setString(text, forType: .string)
            close()
            return
        }
        if let tv = sample, let r = sampleRange {
            close()
            if NSMaxRange(r) <= (tv.string as NSString).length, (tv.string as NSString).substring(with: r) == original {
                tv.insertText(text, replacementRange: r)
                tv.setSelectedRange(NSRange(location: r.location, length: (text as NSString).length))
            }
            return
        }
        let old = original, el = element, r = range, app = appName
        close()
        Task {
            var done = false, direct = false
            if let el, let r {
                (done, direct) = await Self.write(el, pid: pid, location: r.location, length: r.length, text: text, expecting: old)
            } else {
                await AccessibilityBridge().replaceSelectedText(with: text)
                // Without an Accessibility value the paste can't be checked, so the rewrite stays on the clipboard too.
                let pb = NSPasteboard.general
                pb.clearContents(); pb.setString(text, forType: .string)
                done = true
            }
            if !done {
                let pb = NSPasteboard.general
                pb.clearContents(); pb.setString(text, forType: .string)
                error = nil
                notice = "Couldn't replace the text in \(app). The rewrite is copied: press ⌘V."
                show()
                return
            }
            // A paste is undone by the app's own ⌘Z. A direct Accessibility write isn't, so ⌘Z is ours for a moment.
            if direct, let el, let r { armUndo(el, location: r.location, newText: text, oldText: old) }
        }
    }

    private func armUndo(_ el: AXUIElement, location: Int, newText: String, oldText: String) {
        undoKeys.register([(UInt32(kVK_ANSI_Z), UInt32(cmdKey), { [weak self] in
            guard let self else { return }
            self.clearUndo()
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == self.pid else { return }
            Task { _ = await Self.write(el, pid: self.pid, location: location, length: (newText as NSString).length, text: oldText, expecting: newText) }
        })])
        undoObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.clearUndo() }
        }
        undoExpiry = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            self?.clearUndo()
        }
    }

    private func clearUndo() {
        undoExpiry?.cancel(); undoExpiry = nil
        if let undoObserver { NSWorkspace.shared.notificationCenter.removeObserver(undoObserver) }
        undoObserver = nil
        undoKeys.unregisterAll()
    }

    /// Selects the original range and pastes over it (so the app's ⌘Z works), then checks it landed.
    /// Falls back to a direct Accessibility write. Returns (written, wroteDirectly).
    static func write(_ el: AXUIElement, pid: pid_t, location: Int, length: Int, text: String, expecting: String) async -> (Bool, Bool) {
        guard let value = AXText.string(el, kAXValueAttribute) else { return (false, false) }
        let ns = value as NSString
        guard location >= 0, location + length <= ns.length,
              ns.substring(with: NSRange(location: location, length: length)) == expecting else { return (false, false) }
        let expected = ns.replacingCharacters(in: NSRange(location: location, length: length), with: text)
        guard AXText.select(el, location: location, length: length) else { return (false, false) }
        await InlineSession.waitForModifierRelease()
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
            let pb = NSPasteboard.general
            let snapshot = PasteboardSnapshot(pb)
            pb.clearContents(); pb.setString(text, forType: .string)
            InlineSession.postCommand(CGKeyCode(kVK_ANSI_V))
            var ok = false
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                if let now = AXText.string(el, kAXValueAttribute), InlineSession.sameText(now, expected) { ok = true; break }
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            snapshot.restore(to: pb)
            if ok { return (true, false) }
            guard AXText.string(el, kAXValueAttribute) == value else { return (false, false) }
            AXText.select(el, location: location, length: length)
        }
        if AXText.replaceSelection(el, with: text), AXText.string(el, kAXValueAttribute).map({ InlineSession.sameText($0, expected) }) == true {
            return (true, true)
        }
        return (false, false)
    }

    func setUpOffline() {
        guard let model else { return }
        close()
        model.openOfflineSetup()
        model.openSettings(.engine)
    }

    /// Switches to the user's Ollama, then rewrites once it's connected (or shows why it couldn't).
    func useOllama() {
        guard let model else { return }
        model.errorMessage = nil
        model.useMyOllama()
        Task {
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if model.settings.engine == .ollama, !model.isOnline { model.onlineLimitHit = false; retry(); return }
                if let message = model.errorMessage { model.errorMessage = nil; fail(message); return }
            }
        }
    }

    func useOnline() {
        model?.consentToOnline()
        run()
    }

    // MARK: Keys

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func handle(_ e: NSEvent) -> Bool {
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command), shift = flags.contains(.shift)
        switch Int(e.keyCode) {
        case kVK_Escape: close(); return true
        case kVK_Return, kVK_ANSI_KeypadEnter: replace(); return true
        case kVK_Tab: step(shift ? -1 : 1); return true
        default: break
        }
        guard cmd else { return false }
        let numbers = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]
        if let i = numbers.firstIndex(of: Int(e.keyCode)) { select(WritingStyle.allCases[i]); return true }
        switch Int(e.keyCode) {
        case kVK_ANSI_C: copy(); return true
        case kVK_ANSI_R: retry(); return true
        case kVK_ANSI_Slash: showWhy.toggle(); layout(); return true
        case kVK_ANSI_W: close(); return true
        default: return false
        }
    }
}

/// The panel's warning when Accessibility is off, with the one-click fix.
struct AccessMissing: View {
    @ObservedObject var model: CoachModel
    let fix: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 6) {
                Text("HeyHumanly can't read or replace your selection: Accessibility access is missing.")
                    .font(.system(size: 12.5, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Text(model.fixingAccess ? model.fixingAccessHelp : model.accessibilityHelp)
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if model.fixingAccess {
                    HStack(spacing: 6) { ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 14, height: 14); Text("Waiting for the switch…").font(.system(size: 12)).foregroundStyle(.secondary) }
                } else {
                    Button("Fix access", action: fix).controlSize(.small)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.12)))
    }
}

/// Borderless, non-activating, but able to take key so the panel's shortcuts work.
final class QuickPanelWindow: NSPanel {
    var onResignKey: (() -> Void)?
    init(rootView: AnyView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 160), styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let host = NSHostingView(rootView: rootView)
        host.frame = contentRect(forFrameRect: frame)
        host.autoresizingMask = [.width, .height]
        contentView = host
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

// MARK: - View

struct QuickPanelView: View {
    @ObservedObject var session: QuickSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            styles
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffect(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }

    private var styles: some View {
        HStack(spacing: 2) {
            ForEach(Array(WritingStyle.allCases.enumerated()), id: \.element) { i, s in
                Button { session.select(s) } label: {
                    Text(s.title)
                        .font(.system(size: 12, weight: session.style == s ? .semibold : .regular))
                        .foregroundStyle(session.style == s ? Color.primary : Color.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(session.style == s ? Color.primary.opacity(0.09) : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(s.blurb) ⌘\(i + 1)")
            }
            Spacer(minLength: 4)
            if session.busy { ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 16, height: 16) }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.copyOnly, let model = session.model { AccessMissing(model: model) { session.fixAccess() } }
            if session.hasText {
                ScrollView {
                    Text(session.displayed)
                        .font(.system(size: 14))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: textHeight)
            }
            if let error = session.error {
                Text(error).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let notice = session.notice {
                Text(notice).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            engineChoice
            if session.showWhy, session.rewrite != nil { why }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Shown only when coaching can't run: online consent, the daily limit, or offline setup.
    @ViewBuilder private var engineChoice: some View {
        if let model = session.model {
            if model.onlineLimitHit && model.isOnline {
                HStack(spacing: 8) {
                    Button("Set up offline coaching") { session.setUpOffline() }
                    if model.ollamaDetected { Button("Use my Ollama") { session.useOllama() } }
                    Spacer()
                    Text("Resets at \(model.allowance?.resetText ?? "midnight UTC")").font(.system(size: 11)).foregroundStyle(.tertiary)
                }.controlSize(.small)
            } else if model.engine == nil || (model.isOnline && !model.settings.onlineConsent) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Online coaching sends this text to HeyHumanly's server, where Cloudflare Workers AI rewrites it. It isn't stored or logged. Offline coaching keeps it on this Mac.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button("Try online coaching") { session.useOnline() }.keyboardShortcut(.defaultAction)
                        Button("Set up offline coaching") { session.setUpOffline() }
                        if model.ollamaDetected { Button("Use my Ollama") { session.useOllama() } }
                    }.controlSize(.small)
                }
            }
        }
    }

    private var why: some View {
        VStack(alignment: .leading, spacing: 6) {
            if session.changes.isEmpty {
                Text("No changes to explain.").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            ForEach(session.changes.prefix(8)) { c in
                VStack(alignment: .leading, spacing: 1) {
                    (Text(c.from.isEmpty ? "added" : c.from).strikethrough(!c.from.isEmpty).foregroundColor(c.from.isEmpty ? .secondary : .removed)
                     + Text("  →  ").foregroundColor(.secondary)
                     + Text(c.to.isEmpty ? "removed" : c.to).foregroundColor(c.to.isEmpty ? .secondary : .added))
                        .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Text(c.reason).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if session.changes.count > 8 {
                Text("and \(session.changes.count - 8) more").font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            key("↩", session.copyOnly ? "Copy" : "Replace"); key("⇥", "Style"); key("⌘1–5", ""); key("⌘/", "Why"); key("⌘R", "Retry"); key("⌘C", "Copy"); key("esc", "")
            Spacer(minLength: 4)
            if let model = session.model {
                Circle().fill(dotColor(model)).frame(width: 7, height: 7)
                    .help(dotHelp(model))
                    .accessibilityLabel(dotHelp(model))
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 7)
    }

    private func key(_ k: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(k).fontWeight(.medium).foregroundStyle(.primary.opacity(0.75))
            if !label.isEmpty { Text(label) }
        }
    }

    private func dotColor(_ m: CoachModel) -> Color {
        if !m.engineReady || (m.isOnline && m.onlineLimitHit) { return .orange }
        return m.isOnline ? .blue : .green
    }

    private func dotHelp(_ m: CoachModel) -> String {
        if m.isOnline, let a = m.allowance { return "Online · \(a.remaining) of \(a.limit) free coachings left today" }
        return m.engineSummary
    }

    /// About 62 characters a line at 14pt in 448pt.
    private var textHeight: CGFloat {
        let text = session.rewrite.map { session.original + " " + $0 } ?? (session.streamed.isEmpty ? session.original : session.original + " " + session.streamed)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / 60))) }
        return min(300, CGFloat(max(1, lines)) * 19 + 4)
    }
}
