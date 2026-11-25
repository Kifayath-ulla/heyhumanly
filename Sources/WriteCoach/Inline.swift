import SwiftUI
import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine

// MARK: - Accessibility helpers for the focused text field

enum AXText {
    static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func string(_ el: AXUIElement, _ attr: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &value) == .success else { return nil }
        return value as? String
    }

    static func selectedRange(_ el: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    /// Screen rectangle (top-left origin, points) of a character range.
    /// Native fields answer AXBoundsForRange; Chromium/Electron fields (Slack, browsers) answer through text markers.
    static func bounds(_ el: AXUIElement, location: Int, length: Int) -> CGRect? {
        if let r = rangeBounds(el, location: location, length: length) { return r }
        return markerBounds(el, location: location, length: length)
    }

    static func markerBounds(_ el: AXUIElement, location: Int, length: Int) -> CGRect? {
        func marker(_ i: Int) -> CFTypeRef? {
            var out: CFTypeRef?
            guard AXUIElementCopyParameterizedAttributeValue(el, "AXTextMarkerForIndex" as CFString, NSNumber(value: i), &out) == .success else { return nil }
            return out
        }
        guard let a = marker(location), let b = marker(location + max(1, length)) else { return nil }
        var range: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, "AXTextMarkerRangeForUnorderedTextMarkers" as CFString, [a, b] as CFArray, &range) == .success,
              let range else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, "AXBoundsForTextMarkerRange" as CFString, range, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect), rect.width > 0, rect.height > 0 else { return nil }
        // Some apps answer with the whole window. Only trust a rect that is line-sized and inside the field.
        guard rect.height < 80 || length > 40 else { return nil }
        if let f = frame(el), !f.insetBy(dx: -4, dy: -4).contains(CGPoint(x: rect.midX, y: rect.midY)) { return nil }
        return rect
    }

    static func rangeBounds(_ el: AXUIElement, location: Int, length: Int) -> CGRect? {
        var range = CFRange(location: location, length: max(1, length))
        guard let param = AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(el, kAXBoundsForRangeParameterizedAttribute as CFString, param, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect), rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    /// Frame of the element itself (top-left origin).
    static func frame(_ el: AXUIElement) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success,
              let p, let s else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point); AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    static func role(_ el: AXUIElement) -> String? { string(el, kAXRoleAttribute) }
    static func subrole(_ el: AXUIElement) -> String? { string(el, kAXSubroleAttribute) }

    /// Password and other secure fields are never read.
    static func isSecure(_ el: AXUIElement) -> Bool {
        subrole(el) == (kAXSecureTextFieldSubrole as String) || role(el) == "AXSecureTextField"
    }

    @discardableResult
    static func select(_ el: AXUIElement, location: Int, length: Int) -> Bool {
        var range = CFRange(location: location, length: length)
        guard let value = AXValueCreate(.cfRange, &range) else { return false }
        return AXUIElementSetAttributeValue(el, kAXSelectedTextRangeAttribute as CFString, value) == .success
    }

    @discardableResult
    static func replaceSelection(_ el: AXUIElement, with text: String) -> Bool {
        AXUIElementSetAttributeValue(el, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }

    static func pid(_ el: AXUIElement) -> pid_t {
        var pid: pid_t = 0; AXUIElementGetPid(el, &pid); return pid
    }

    /// Converts an Accessibility rect (top-left origin) to AppKit screen coordinates (bottom-left origin).
    static func toCocoa(_ r: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    /// Electron apps (Slack, Discord, Notion…) only build their accessibility tree when asked.
    static func enableManualAccessibility(pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
}

// MARK: - Inline session: the companion that lives on top of the field you're typing in

@MainActor
final class InlineSession: ObservableObject {
    enum Phase: Equatable { case idle, checking, ready, done(String), failed(String) }

    struct Edit { let location: Int; let newText: String; let oldText: String; let label: String }

    struct LearnState {
        /// Each step is one change (word by word) or every change in one sentence.
        var queue: [[UUID]]
        var bySentence: Bool
        var index = 0
        var picked: Bool?            // true = picked the better version
        var betterFirst = true
        /// Second beat: they put the new wording back themselves. nil = not tried yet.
        var recall: Bool?
        var right = 0
        var answered = 0
        var finished = false
        /// Steps already done, and the rules they covered (for the progress dots and the summary).
        var completed = 0
        var learned: [String] = []
    }

    /// What one Learn step shows: the original and improved text of its span, with a little context.
    struct LearnStep {
        let ids: [UUID]; let start: Int; let length: Int
        let before: String; let after: String
        let prefix: String; let suffix: String
        let changes: [Change]
    }

    @Published var phase: Phase = .idle
    @Published var changes: [Change] = []
    @Published var openChangeID: UUID?
    @Published var appName = ""
    @Published var bundleID = ""
    @Published var expanded = false
    @Published var tone: WritingStyle = .polish
    @Published var proposal = ""          // whole-message rewrite for the current tone
    @Published var toneBusy = false
    @Published var showLanguages = false { didSet { if oldValue != showLanguages { placeCompanion() } } }
    @Published var explaining = false
    @Published var tip = ""
    @Published var learn: LearnState?
    @Published var undoStack: [Edit] = []
    @Published var toast: String?
    @Published var hoverID: UUID?
    @Published var showRemoved = false { didSet { placeCompanion() } }

    weak var model: CoachModel?
    private(set) var isAuto = false
    /// The field reports where each character is on screen (so underlines can be drawn).
    @Published private(set) var canLocate = true
    /// The field's text right after our own last edit; the watcher doesn't re-check it.
    private(set) var lastWritten: String?
    /// The user is typing; the companion stays hidden until the next check lands.
    private var typingHidden = false
    private var element: AXUIElement?
    private var pid: pid_t = 0
    private var baseOffset = 0
    private(set) var checkedText = ""
    private var lastValue = ""
    private var rewriteForChanges = ""
    private var historyID: UUID?
    private var underlines: [UUID: [UnderlinePanel]] = [:]
    private var card: FloatingPanel?
    private var companion: FloatingPanel?
    private var orbAnchor: CGPoint?
    private var timer: Timer?
    private var task: Task<Void, Never>?
    private var teachTask: Task<Void, Never>?
    private var keys = SessionKeys()
    private var escKey = SessionKeys(base: 50)
    private var escOn = false
    private var generation = 0

    private var refit: AnyCancellable?
    init() {
        refit = objectWillChange.debounce(for: .milliseconds(16), scheduler: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.refitCard() }
        }
    }

    /// Card content changed (answer picked, reasons expanded, explanation arrived): resize it in place.
    func refitCard() {
        guard let card, card.isVisible, let fit = card.contentView?.fittingSize.height else { return }
        let h = max(80, min(cardMaxHeight, fit))
        guard abs(card.frame.height - h) > 0.5 else { return }
        var f = card.frame
        if !cardAbove { f.origin.y += f.height - h }   // keep the top (arrow) in place
        f.size.height = h
        if let vf = (card.screen ?? NSScreen.main)?.visibleFrame {   // growing must not push it off screen
            f.origin.y = min(max(f.origin.y, vf.minY + 4), vf.maxY - h - 4)
        }
        card.setFrame(f, display: true)
    }

    var visible: [Change] { changes.filter { !(model?.isMuted($0.category) ?? false) } }
    var quiet: [Change] { changes.filter { model?.isMuted($0.category) ?? false } }
    var errorCount: Int { visible.filter(\.isError).count }
    var styleCount: Int { visible.count - errorCount }
    var isActive: Bool { element != nil }
    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    func isSameElement(_ el: AXUIElement) -> Bool { element.map { CFEqual($0, el) } ?? false }

    // MARK: Start / stop

    /// Checks the field. Returns false when it can't be read or located on screen (caller may fall back to the coach).
    @discardableResult
    func start(element el: AXUIElement, appName: String, bundleID: String, auto: Bool) -> Bool {
        // Inline checks run without an explicit request, so they only ever use an engine on this Mac.
        guard model?.engineIsLocal == true else { return false }
        guard let value = AXText.string(el, kAXValueAttribute), !value.isEmpty, !AXText.isSecure(el) else { return false }
        // Fields that can't say where words are (some Electron/web editors) still get the companion,
        // docked to the field, with no underlines rather than misplaced ones.
        // HH_NO_LOCATE=1 (developer testing) makes every field behave like Slack/Discord, which report no word positions.
        canLocate = AXText.bounds(el, location: 0, length: 1) != nil && ProcessInfo.processInfo.environment["HH_NO_LOCATE"] == nil
        let same = isSameElement(el)
        if !same { stop() }
        generation += 1
        element = el; pid = AXText.pid(el); self.appName = appName; self.bundleID = bundleID; isAuto = auto
        lastValue = value
        let ns = value as NSString
        if !auto, let sel = AXText.selectedRange(el), sel.length > 0, sel.location + sel.length <= ns.length {
            baseOffset = sel.location
            checkedText = ns.substring(with: NSRange(location: sel.location, length: sel.length))
        } else if ns.length > 2400 {
            let caret = AXText.selectedRange(el)?.location ?? 0
            let para = ns.paragraphRange(for: NSRange(location: min(caret, ns.length - 1), length: 0))
            baseOffset = para.location; checkedText = ns.substring(with: para)
        } else {
            baseOffset = 0; checkedText = value
        }
        guard !checkedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if !same { tone = (model?.settings.suggestStyle ?? true) ? Self.savedTone : .fixOnly }
        learn = nil; openChangeID = nil; showLanguages = false; tip = ""
        phase = .checking
        typingHidden = false
        showCompanion()
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        }
        run()
        return true
    }

    func stop() {
        task?.cancel(); task = nil; teachTask?.cancel(); teachTask = nil
        timer?.invalidate(); timer = nil
        underlines.values.flatMap { $0 }.forEach { $0.orderOut(nil) }; underlines = [:]
        card?.orderOut(nil); card = nil
        companion?.orderOut(nil); companion = nil
        keys.unregisterAll(); escKey.unregisterAll(); escOn = false
        changes = []; openChangeID = nil; element = nil; phase = .idle; expanded = false
        learn = nil; proposal = ""; toneBusy = false; toast = nil; tip = ""; showLanguages = false
        undoStack = []; historyID = nil; orbAnchor = nil
    }

    private static var savedTone: WritingStyle {
        UserDefaults.standard.string(forKey: "heyhumanly.companionTone") == "fixOnly" ? .fixOnly : .polish
    }

    // MARK: Checking

    private func run() {
        guard let model else { return }
        task?.cancel(); teachTask?.cancel()
        let text = checkedText, app = appName, words: [String] = [], chosen = tone
        let endpoint = model.activeEndpoint, modelName = model.activeModel
        let gen = generation
        let started = Date()
        task = Task { [weak self] in
            do {
                let raw = try await CompanionService.rewrite(text, style: chosen == .fixOnly ? .fixOnly : .polish, appName: app, preserve: words,
                                                             endpoint: endpoint, model: modelName)
                guard let self, !Task.isCancelled, gen == self.generation else { return }
                // Nothing reaches the screen until each change has been checked against what was written.
                let rewrite = RewriteGuard.sanitize(original: text, rewrite: raw, preserve: words)
                appLog.notice("companion check \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s")
                // The user kept typing while we waited: their text wins; the watcher will check again.
                guard let el = self.element, let now = AXText.string(el, kAXValueAttribute),
                      (now as NSString).length >= self.baseOffset + (text as NSString).length,
                      (now as NSString).substring(with: NSRange(location: self.baseOffset, length: (text as NSString).length)) == text else { return }
                self.apply(rewrite: rewrite, for: text)
            } catch {
                guard let self, !Task.isCancelled, gen == self.generation else { return }
                self.phase = .failed(error.localizedDescription)
                self.layout()
            }
        }
    }

    private func apply(rewrite: String, for text: String) {
        rewriteForChanges = rewrite
        proposal = rewrite
        let set = ChangeSet(original: text, rewrite: rewrite)
        changes = set.changes.map { var c = $0; c.teach(original: text, location: $0.location); c.location = ($0.location ?? 0) + baseOffset; return c }
        if changes.isEmpty {
            phase = .done("Looks good")
            layout()
            let gen = generation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard let self, gen == self.generation, case .done = self.phase else { return }
                self.hideOverlays()
            }
            return
        }
        phase = .ready
        layout()
        explain(text: text, rewrite: rewrite)
    }

    /// Explanations come from the built-in rule book, so they are on screen with the marks.
    /// Only a non-English explanation language needs the model (to translate them).
    private func explain(text: String, rewrite: String) {
        tip = Self.lessonTip(for: changes)
        guard let model, model.settings.explainLanguage != "English" else { return }
        let pending = changes
        let endpoint = model.activeEndpoint, modelName = model.activeModel, language = model.settings.explainLanguage
        explaining = true
        teachTask = Task { [weak self] in
            for p in pending {
                guard !Task.isCancelled else { return }
                guard let out = try? await CompanionService.translate(p.reason, to: language, endpoint: endpoint, model: modelName) else { continue }
                guard let self, !Task.isCancelled else { return }
                if let i = self.changes.firstIndex(where: { $0.id == p.id }) { self.changes[i].reason = out }
            }
            guard let self, !Task.isCancelled else { return }
            self.explaining = false
            self.layout()
        }
    }

    /// One thing to take away from this message, taken from what was actually found.
    static func lessonTip(for changes: [Change]) -> String {
        let taught = changes.filter { $0.tip != nil || $0.practiceRight != nil }
        let groups = Dictionary(grouping: taught, by: { $0.label ?? $0.category.title })
        if let (label, items) = groups.max(by: { $0.value.count < $1.value.count }), items.count >= 2 {
            return "\(label) came up \(items.count) times in this message. " + (items[0].tip ?? "That's the one to watch.")
        }
        if let first = taught.first(where: \.isError) ?? taught.first { return first.tip ?? first.reason }
        return ""
    }

    // MARK: Keep overlays glued to the text

    private func tick() {
        guard let el = element else { return }
        // Our own paste is landing: the write keeps positions in step itself. Reacting here too would shift them twice.
        if isWriting { return }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { hideForAway(); return }
        if let focused = AXText.focusedElement(), !CFEqual(focused, el) { hideForAway(); return }
        guard let value = AXText.string(el, kAXValueAttribute) else { stop(); return }
        if value != lastValue {
            shiftForTyping(old: lastValue, new: value)
            lastValue = value
            // You're typing: get the dot out of the way until the next check.
            if !expanded && learn == nil, value != lastWritten { typingHidden = true }
            if learn == nil { openChangeID = nil }
            // Field emptied (sent or cleared) or nothing left to show: go away.
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { stop(); return }
            if phase == .ready && visible.isEmpty && !expanded && learn == nil { hideOverlays() }
        }
        layout()
    }

    /// The user typed: move suggestions after the edit, drop the ones they touched (Grammarly-style; no wrong positions).
    private func shiftForTyping(old: String, new: String) {
        let a = Array(old.utf16), b = Array(new.utf16)
        var p = 0
        while p < a.count && p < b.count && a[p] == b[p] { p += 1 }
        var s = 0
        while s < a.count - p && s < b.count - p && a[a.count - 1 - s] == b[b.count - 1 - s] { s += 1 }
        let oldEnd = a.count - s, delta = b.count - a.count
        changes.removeAll { c in
            guard let l = c.location, let n = c.length else { return true }
            return l < oldEnd && l + max(n, 1) > p
        }
        for i in changes.indices where (changes[i].location ?? 0) >= oldEnd { changes[i].location = (changes[i].location ?? 0) + delta }
        // The checked text itself moved or changed; whole-message proposals are stale.
        if p < baseOffset + (checkedText as NSString).length { proposal = "" }
        if baseOffset >= oldEnd { baseOffset += delta }
    }

    /// The user went to another app or field: hide, keep nothing on screen.
    private func hideForAway() { stop() }

    /// Everything resolved; fade the companion out after a beat.
    private func hideOverlays() {
        underlines.values.flatMap { $0 }.forEach { $0.orderOut(nil) }; underlines = [:]
        card?.orderOut(nil)
        companion?.orderOut(nil); companion = nil
        keys.unregisterAll(); escKey.unregisterAll(); escOn = false
        expanded = false
    }

    /// Esc belongs to HeyHumanly only while one of its cards is open; the rest of the time the app gets it.
    private func syncEscape() {
        let want = openChangeID != nil || expanded || learn != nil
        guard want != escOn else { return }
        escOn = want
        if want { escKey.register([(UInt32(kVK_Escape), 0, { [weak self] in self?.escape() })]) } else { escKey.unregisterAll() }
    }

    func escape() {
        if openChangeID != nil { closeCard() }
        else if learn != nil { endLearn() }
        else if expanded { expanded = false; layout() }
    }

    func layout() {
        syncEscape()
        guard let el = element else { return }
        var seen = Set<UUID>()
        let focusIDs: Set<UUID> = learn.flatMap { $0.index < $0.queue.count ? Set($0.queue[$0.index]) : nil } ?? []
        for (n, change) in visible.enumerated() where canLocate {
            guard let loc = change.location, let len = change.length else { continue }
            // Insertions have no width: mark the character before them.
            let at = len == 0 ? max(0, loc - 1) : loc
            var rects = lineRects(el, location: at, length: max(1, len))
                .filter { r in r.width < 3000 && NSScreen.screens.contains(where: { $0.frame.intersects(r) }) }
            // One character can report a tighter box than the line it is on; borrow the line's height.
            if rects.count == 1, max(1, len) <= 2, let wide = AXText.bounds(el, location: max(0, at - 2), length: 5).map(AXText.toCocoa),
               wide.height < rects[0].height * 2.2, wide.height > rects[0].height, wide.minY <= rects[0].minY + 0.5 {
                rects[0] = CGRect(x: rects[0].minX, y: wide.minY, width: rects[0].width, height: wide.height)
            }
            guard !rects.isEmpty else { continue }
            seen.insert(change.id)
            let style: UnderlineView.Style = change.isError ? .error : .style
            let color = NSColor(change.isError ? Color.removed : Color.teach)
            var panels = underlines[change.id] ?? []
            while panels.count < rects.count {
                panels.append(UnderlinePanel(color: color, style: style, delay: Double(n) * 0.05 + Double(panels.count) * 0.12,
                                             onClick: { [weak self] in self?.openCard(change.id) },
                                             onHover: { [weak self] inside in self?.hover(change.id, inside) }))
            }
            while panels.count > rects.count { panels.removeLast().orderOut(nil) }
            for (panel, rect) in zip(panels, rects) {
                panel.setStyle(style, color: color)
                panel.place(over: rect)
                panel.isHighlighted = openChangeID == change.id || focusIDs.contains(change.id)
                panel.isDimmed = !focusIDs.isEmpty && !focusIDs.contains(change.id)
            }
            underlines[change.id] = panels
        }
        for (id, panels) in underlines where !seen.contains(id) { panels.forEach { $0.orderOut(nil) }; underlines[id] = nil }
        let cardShown: Bool
        if let step = learnStep {
            cardShown = placeCard(location: step.start, length: step.length)
        } else if learn == nil, let id = openChangeID, let change = changes.first(where: { $0.id == id }), let loc = change.location {
            cardShown = placeCard(location: loc, length: change.length ?? 1)
        } else { card?.orderOut(nil); cardShown = false }
        // A lesson with no card (Slack often has no word positions that we can trust) must not
        // hide the only control the user can click.
        placeCompanion(keepVisible: learn != nil && !cardShown)
    }

    /// One rectangle per visual line (AXBoundsForRange returns one big box for text that wraps).
    private func lineRects(_ el: AXUIElement, location: Int, length: Int) -> [CGRect] {
        guard let full = AXText.bounds(el, location: location, length: length) else { return [] }
        guard let first = AXText.bounds(el, location: location, length: 1), full.height > first.height * 1.5 else { return [AXText.toCocoa(full)] }
        let ns = lastValue as NSString
        guard location + length <= ns.length else { return [] }
        var lines: [CGRect] = []
        var count = 0
        ns.enumerateSubstrings(in: NSRange(location: location, length: length), options: .byWords) { _, r, _, stop in
            count += 1; if count > 120 { stop.pointee = true; return }
            guard let w = AXText.bounds(el, location: r.location, length: r.length) else { return }
            if let last = lines.last, abs(last.midY - w.midY) < first.height * 0.5 { lines[lines.count - 1] = last.union(w) }
            else { lines.append(w) }
        }
        return lines.map(AXText.toCocoa)
    }

    // MARK: Companion placement

    private func textEndRect() -> CGRect? {
        guard let el = element, canLocate else { return nil }
        let end = baseOffset + (checkedText as NSString).length
        let value = (lastValue as NSString)
        var i = min(end, value.length) - 1
        while i > 0, let ch = Unicode.Scalar(value.character(at: i)), CharacterSet.whitespacesAndNewlines.contains(ch) { i -= 1 }
        if i >= 0, let r = AXText.bounds(el, location: i, length: 1) { return AXText.toCocoa(r) }
        return AXText.frame(el).map(AXText.toCocoa)
    }

    private func showCompanion() {
        if companion == nil {
            companion = FloatingPanel(size: NSSize(width: 34, height: 34), rootView: AnyView(CompanionView(session: self)))
        }
        placeCompanion(keepVisible: false)
    }

    func placeCompanion(keepVisible: Bool = false) {
        guard let panel = companion else { return }
        let size = CompanionView.size(for: self)
        var origin: NSPoint
        // During Learn the card does the pointing. Keep the dot only when the card could not be placed.
        if let l = learn, !l.finished, !keepVisible { panel.orderOut(nil); return }
        // A suggestion card is open: it has every action, and the dot would sit on its corner.
        if openChangeID != nil, !expanded, toast == nil, card?.isVisible == true { panel.orderOut(nil); return }
        // Never on top of the text: hidden while you type, and docked off the text when shown.
        if typingHidden && !expanded && learn == nil { panel.orderOut(nil); return }
        let field = element.flatMap(AXText.frame).map(AXText.toCocoa)
        let isComposer = field.map { $0.height < 260 } ?? false   // chat boxes, email fields, search boxes
        if !isComposer, let end = textEndRect() {
            // Documents: just below the end of the last line, where there's no text yet.
            origin = NSPoint(x: end.maxX - 17, y: end.minY - 36)
            if expanded || learn?.finished == true { origin = NSPoint(x: end.minX, y: end.minY - size.height - 8) }
        } else if let f = field {
            // Message boxes: fully outside the box, on the top-right corner, so it cannot cover a line of text.
            origin = NSPoint(x: f.maxX - 22, y: f.maxY + 4)
            if expanded || learn?.finished == true || size.width > 40 {
                origin = NSPoint(x: f.maxX - size.width, y: f.maxY + 8)
                if let screen = NSScreen.main, origin.y + size.height > screen.visibleFrame.maxY - 6 {
                    origin.y = f.minY - size.height - 8
                }
            }
        } else { return }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(origin) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 6), vf.maxX - size.width - 6)
            // Clamp vertically, but never back into a message box.
            let clampedY = min(max(origin.y, vf.minY + 6), vf.maxY - size.height - 6)
            if let f = field, isComposer, CGRect(x: origin.x, y: clampedY, width: size.width, height: size.height).intersects(f.insetBy(dx: 2, dy: 2)) {
                origin.y = f.maxY + 4
            } else {
                origin.y = clampedY
            }
        }
        let frame = NSRect(origin: origin, size: size)
        guard panel.frame != frame else { if !panel.isVisible { panel.orderFrontRegardless() }; return }
        let far = hypot(panel.frame.minX - frame.minX, panel.frame.minY - frame.minY) > 24
        if panel.isVisible && far && !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.32
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        panel.orderFrontRegardless()
    }

    func toggleExpanded() {
        appLog.notice("companion toggle expanded=\(self.expanded) phase=\(String(describing: self.phase), privacy: .public)")
        // Coaching is the default. The rewrite panel is what you get after "Just correct".
        if learn != nil { showRewrite(); return }
        if !expanded && !visible.isEmpty && (model?.settings.dotTeaches ?? true) { startLearn(); return }
        expanded.toggle()
        openChangeID = nil
        if expanded && proposal.isEmpty && phase == .ready { setTone(tone) }
        layout()
    }

    /// Leave the lesson and show the paste-the-rewrite panel.
    func showRewrite() {
        learn = nil
        expanded = true
        openChangeID = nil
        if proposal.isEmpty && phase == .ready { setTone(tone) }
        layout()
    }

    // MARK: Card

    private var hoverWork: DispatchWorkItem?
    func hover(_ id: UUID, _ inside: Bool) {
        hoverWork?.cancel()
        guard learn == nil, inside, openChangeID != id else { return }
        // Small delay so passing the mouse over text doesn't flash cards.
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.openCard(id, toggle: false) } }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    func openCard(_ id: UUID, toggle: Bool = true) {
        guard learn == nil else { return }
        expanded = false
        openChangeID = (toggle && openChangeID == id) ? nil : id
        layout()
    }

    func closeCard() { openChangeID = nil; layout() }

    @discardableResult
    private func placeCard(location loc: Int, length: Int) -> Bool {
        guard let el = element else { return false }
        let at = length == 0 ? max(0, loc - 1) : loc
        var lines = canLocate ? lineRects(el, location: at, length: max(1, length)) : []
        let field = AXText.frame(el).map(AXText.toCocoa)
        // No word positions: anchor to the field's top edge. The card itself stays outside the field.
        if lines.isEmpty, let f = field { lines = [CGRect(x: f.maxX - 60, y: f.maxY - 1, width: 40, height: 1)] }
        guard let firstLine = lines.first, let lastLine = lines.last else { return false }
        if card == nil { card = FloatingPanel(size: NSSize(width: 380, height: 200), rootView: AnyView(SuggestionCardView(session: self))) }
        let fit = card?.contentView?.fittingSize.height ?? 200
        let size = NSSize(width: 380, height: max(80, min(cardMaxHeight, fit)))
        let anchor = lines.reduce(CGRect.null) { $0.union($1) }
        // Below the last line of the span, arrow under its first word.
        var origin = NSPoint(x: firstLine.minX - 22, y: lastLine.minY - size.height - 8)
        var above = false
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(firstLine) }) ?? NSScreen.main {
            if origin.y < screen.visibleFrame.minY + 4 || !canLocate { origin.y = firstLine.maxY + 8; above = true }
            origin.x = min(max(origin.x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - size.width - 8)
            origin.y = min(origin.y, screen.visibleFrame.maxY - size.height - 4)
        }
        if let field, field.height < 260 {
            let cardRect = CGRect(origin: origin, size: size)
            if cardRect.intersects(field.insetBy(dx: 6, dy: 6)) {
                above = true
                origin.y = field.maxY + 8
            }
        } else if CGRect(origin: origin, size: size).intersects(anchor.insetBy(dx: -2, dy: -2)) {
            above = true
            origin.y = anchor.maxY + 8
        }
        // Never past the top of the screen: if there is no room above, go below the span, else pin to the top edge.
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(firstLine) }) ?? NSScreen.main,
           origin.y + size.height > screen.visibleFrame.maxY - 4 {
            let below = lastLine.minY - size.height - 8
            if below >= screen.visibleFrame.minY + 4 { origin.y = below; above = false }
            else { origin.y = screen.visibleFrame.maxY - size.height - 4 }
        }
        cardAbove = above
        cardArrowX = max(18, min(size.width - 30, firstLine.minX - origin.x + min(firstLine.width, 40) / 2))
        guard let card else { return false }
        let target = NSRect(origin: origin, size: size)
        if card.isVisible && card.frame != target && hypot(card.frame.minX - origin.x, card.frame.minY - origin.y) > 20 && !reduceMotion {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.34
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
                card.animator().setFrame(target, display: true)
            }
        } else if card.frame != target { card.setFrame(target, display: true) }
        card.orderFrontRegardless()
        return true
    }
    /// Tall enough for a whole lesson step without scrolling, but never taller than the screen allows.
    var cardMaxHeight: CGFloat { min(600, (NSScreen.main?.visibleFrame.height ?? 800) - 140) }
    @Published var cardAbove = false
    @Published var cardArrowX: CGFloat = 30

    // MARK: Writing into the app (paste so the app's own ⌘Z works; verified afterwards)

    private var isWriting = false
    private func write(location: Int, length: Int, text: String, expecting: String?) async -> Bool {
        guard let el = element, let value = AXText.string(el, kAXValueAttribute) else { return false }
        isWriting = true
        defer { isWriting = false }
        let ns = value as NSString
        guard location >= 0, location + length <= ns.length else { return false }
        if let expecting, ns.substring(with: NSRange(location: location, length: length)) != expecting { return false }
        let expected = ns.replacingCharacters(in: NSRange(location: location, length: length), with: text)
        // If you were typing at the end, put the cursor back at the end afterwards.
        let caretAtEnd = (AXText.selectedRange(el)?.location ?? -1) >= ns.length
        guard AXText.select(el, location: location, length: length) else { return false }
        await Self.waitForModifierRelease()
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
            let pb = NSPasteboard.general
            let snapshot = PasteboardSnapshot(pb)
            pb.clearContents(); pb.setString(text, forType: .string)
            Self.postCommand(CGKeyCode(kVK_ANSI_V))
            var ok = false
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 20_000_000)
                // Web editors may store spaces as non-breaking ones; compare what the user sees.
                if let now = AXText.string(el, kAXValueAttribute), Self.sameText(now, expected) { ok = true; break }
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
            snapshot.restore(to: pb)
            appLog.notice("write paste ok=\(ok)")
            if ok {
                let now = AXText.string(el, kAXValueAttribute) ?? expected
                if caretAtEnd { AXText.select(el, location: (now as NSString).length, length: 0) }
                lastValue = now; lastWritten = now
                syncChecked(location: location, length: length, newLength: (text as NSString).length)
                return true
            }
            // Paste didn't land; check nothing was half-written before trying the direct route.
            guard AXText.string(el, kAXValueAttribute) == value else { lastValue = AXText.string(el, kAXValueAttribute) ?? lastValue; return false }
            AXText.select(el, location: location, length: length)
        }
        if AXText.replaceSelection(el, with: text), AXText.string(el, kAXValueAttribute) == expected {
            lastValue = expected; lastWritten = expected
            syncChecked(location: location, length: length, newLength: (text as NSString).length)
            return true
        }
        return false
    }

    /// Our own edit changed the checked message: keep `checkedText` equal to what is in the field.
    private func syncChecked(location: Int, length: Int, newLength: Int) {
        let clen = (checkedText as NSString).length, ns = lastValue as NSString
        guard location >= baseOffset, location + length <= baseOffset + clen else { return }
        let updated = clen + newLength - length
        guard updated >= 0, baseOffset + updated <= ns.length else { return }
        checkedText = ns.substring(with: NSRange(location: baseOffset, length: updated))
    }

    /// The ready-made version = what's in the field now plus every suggestion still open.
    private func rebuildProposal() {
        guard tone.guarded else { proposal = ""; return }
        let clen = (checkedText as NSString).length
        let m = NSMutableString(string: checkedText)
        for c in changes.sorted(by: { ($0.location ?? 0) > ($1.location ?? 0) }) {
            guard let l = c.location, let n = c.length, l >= baseOffset, l + n <= baseOffset + clen,
                  m.substring(with: NSRange(location: l - baseOffset, length: n)) == c.from else { continue }
            m.replaceCharacters(in: NSRange(location: l - baseOffset, length: n), with: c.to)
        }
        proposal = Self.tidy(m as String, like: checkedText)
        rewriteForChanges = proposal
    }

    /// Like `tidy`, but keeps the edges exactly (a step sits inside a longer text).
    static func tidyInner(_ text: String, like old: String) -> String {
        var new = text
        if !old.contains("  ") { while new.contains("  ") { new = new.replacingOccurrences(of: "  ", with: " ") } }
        for p in [",", ".", "!", "?", ";", ":"] where !old.contains(" " + p) { new = new.replacingOccurrences(of: " " + p, with: p) }
        return new
    }

    /// Deleting a word leaves two spaces or a space before punctuation; tidy that, unless the original had it.
    static func tidy(_ text: String, like old: String) -> String {
        var new = text
        if !old.contains("  ") { while new.contains("  ") { new = new.replacingOccurrences(of: "  ", with: " ") } }
        for p in [",", ".", "!", "?", ";", ":"] where !old.contains(" " + p) { new = new.replacingOccurrences(of: " " + p, with: p) }
        if old.last?.isWhitespace != true { while new.last?.isWhitespace == true { new.removeLast() } }
        if old.first?.isWhitespace != true { while new.first?.isWhitespace == true { new.removeFirst() } }
        return new
    }

    static func sameText(_ a: String, _ b: String) -> Bool {
        func n(_ s: String) -> String {
            s.replacingOccurrences(of: "\u{00A0}", with: " ").split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        }
        return a == b || n(a) == n(b)
    }

    static func waitForModifierRelease() async {
        let deadline = Date().addingTimeInterval(1.0)
        let mask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        while Date() < deadline, !CGEventSource.flagsState(.combinedSessionState).intersection(mask).isEmpty {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    static func postCommand(_ key: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }

    // MARK: Actions

    func accept(_ id: UUID, advance: Bool = false) {
        guard let change = changes.first(where: { $0.id == id }), let loc = change.location, var len = change.length else { return }
        var expecting = change.from
        // Removing a word: take one of the spaces around it too, so no double space is left.
        let ns = lastValue as NSString
        if change.to.isEmpty, loc + len < ns.length, ns.character(at: loc + len) == 32, loc == 0 || ns.character(at: loc - 1) == 32 {
            len += 1; expecting += " "
        }
        Task {
            guard await write(location: loc, length: len, text: change.to, expecting: expecting) else {
                flash("\(appName) didn't take that edit. Nothing was changed.")
                return
            }
            recordIfNeeded()
            model?.noteInlineAccepted(change)
            undoStack.append(Edit(location: loc, newText: change.to, oldText: change.from, label: change.label ?? change.category.title))
            changes.removeAll { $0.id == id }
            let delta = (change.to as NSString).length - len
            for i in changes.indices where (changes[i].location ?? 0) >= loc + len { changes[i].location = (changes[i].location ?? 0) + delta }
            openChangeID = nil
            rebuildProposal()
            if advance { nextLearn() } else { afterEdit() }
        }
    }

    func ignore(_ id: UUID) {
        if let c = changes.first(where: { $0.id == id }) { RewriteGuard.rememberDismissal(from: c.from, to: c.to) }
        changes.removeAll { $0.id == id }
        rebuildProposal()   // the ready-made version still had it
        openChangeID = nil
        afterEdit()
    }

    func muteCategory(of id: UUID) {
        guard let change = changes.first(where: { $0.id == id }) else { return }
        model?.setMuted(change.category, true)
        openChangeID = nil
        flash("You won't see \(change.category.title.lowercased()) again. It's still fixed by Fix all.")
        if learn != nil {
            let muted = Set(changes.filter { $0.category == change.category }.map(\.id))
            if let queue = learn?.queue { learn?.queue = queue.map { $0.filter { !muted.contains($0) } } }
            prepareLearnStep()
        }
        afterEdit()
    }

    /// One paste for the whole message: every remaining suggestion (muted ones too), so a single ⌘Z undoes it.
    func fixAll() {
        appLog.notice("fixAll phase=\(String(describing: self.phase), privacy: .public) changes=\(self.changes.count)")
        guard phase == .ready, !changes.isEmpty, let el = element, let value = AXText.string(el, kAXValueAttribute) else { return }
        let ns = value as NSString
        let sorted = changes.sorted { ($0.location ?? 0) > ($1.location ?? 0) }
        let start = sorted.last?.location ?? 0
        let end = sorted.map { ($0.location ?? 0) + ($0.length ?? 0) }.max() ?? 0
        guard end <= ns.length else { return }
        let old = ns.substring(with: NSRange(location: start, length: end - start))
        let mutable = NSMutableString(string: old)
        for c in sorted {
            guard let l = c.location, let n = c.length else { continue }
            let r = NSRange(location: l - start, length: n)
            guard mutable.substring(with: r) == c.from else { flash("The text changed. Checking again…"); return }
            mutable.replaceCharacters(in: r, with: c.to)
        }
        let new = Self.tidy(mutable as String, like: old)
        Task {
            guard await write(location: start, length: end - start, text: new, expecting: old) else {
                flash("\(appName) didn't take the edit. Nothing was changed."); return
            }
            recordIfNeeded()
            changes.forEach { model?.noteInlineAccepted($0) }
            undoStack.append(Edit(location: start, newText: new, oldText: old, label: "Fix all"))
            changes = []
            expanded = false   // back to the small "Fixed · Undo" pill
            afterEdit(message: "Fixed")
        }
    }

    /// Replaces the checked message with the current tone's version.
    func useProposal() {
        guard !proposal.isEmpty, let el = element, let value = AXText.string(el, kAXValueAttribute) else { return }
        let ns = value as NSString, len = (checkedText as NSString).length
        guard baseOffset + len <= ns.length, ns.substring(with: NSRange(location: baseOffset, length: len)) == checkedText else {
            flash("The text changed. Checking again…"); return
        }
        let new = proposal, old = checkedText, at = baseOffset, label = tone.title
        Task {
            guard await write(location: at, length: len, text: new, expecting: old) else {
                flash("\(appName) didn't take the edit. Nothing was changed."); return
            }
            recordIfNeeded()
            undoStack.append(Edit(location: at, newText: new, oldText: old, label: label))
            checkedText = new
            changes = []
            expanded = false
            afterEdit(message: "Replaced")
        }
    }

    func undo() {
        appLog.notice("undo stack=\(self.undoStack.count) active=\(self.isActive)")
        guard let edit = undoStack.last else { return }
        Task {
            guard await write(location: edit.location, length: (edit.newText as NSString).length, text: edit.oldText, expecting: edit.newText) else {
                flash("Couldn't undo: the text around it changed. Try ⌘Z in \(appName)."); return
            }
            undoStack.removeLast()
            flash("Undone: \(edit.label)")
            // Re-check what's there now so the suggestions come back.
            if let el = element { start(element: el, appName: appName, bundleID: bundleID, auto: isAuto) }
        }
    }

    private func afterEdit(message: String = "All set") {
        if visible.isEmpty && learn == nil {
            phase = .done(message)
            layout()
            let gen = generation
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 4_000_000_000)   // leaves time for Undo
                guard let self, gen == self.generation, case .done = self.phase else { return }
                self.hideOverlays()
            }
        } else { layout() }
    }

    private func flash(_ text: String) {
        toast = text
        layout()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if self?.toast == text { self?.toast = nil; self?.layout() }
        }
    }

    private func recordIfNeeded() {}

    // MARK: Styles

    func setTone(_ t: WritingStyle) {
        guard let model else { return }
        tone = t
        if t.guarded { UserDefaults.standard.set(t == .fixOnly ? "fixOnly" : "auto", forKey: "heyhumanly.companionTone") }
        showLanguages = false
        if t == .polish && !rewriteForChanges.isEmpty { proposal = rewriteForChanges; layout(); return }
        toneBusy = true; proposal = ""
        layout()
        // Tones start from the clean suggested version: small local models invent less that way.
        let base = (t == .fixOnly || rewriteForChanges.isEmpty) ? checkedText : rewriteForChanges
        let text = base, app = appName, words: [String] = []
        let endpoint = model.activeEndpoint, modelName = model.activeModel
        // Ollama answers one request at a time: pause the background explanations so the tone you
        // asked for comes first, then pick them up again.
        let resumeExplain = explaining
        if resumeExplain { teachTask?.cancel(); explaining = false }
        Task { [weak self] in
            var out = try? await CompanionService.rewrite(text, style: t, appName: app, preserve: words, endpoint: endpoint, model: modelName)
            guard let self else { return }
            if let raw = out { out = t.guarded ? RewriteGuard.sanitize(original: text, rewrite: raw, preserve: words) : TextSafety.apply(original: text, rewrite: raw, preserve: words) }
            if resumeExplain, self.changes.contains(where: \.pending) { self.explain(text: self.checkedText, rewrite: self.rewriteForChanges) }
            guard self.tone == t else { return }
            self.toneBusy = false
            self.proposal = out ?? ""
            if out == nil { self.flash("Couldn't make that version. Is Ollama running?") }
            self.layout()
        }
    }

    func pauseThisApp() {
        guard let model, !bundleID.isEmpty else { return }
        model.settings.pausedApps.insert(bundleID); model.settings.save(); model.objectWillChange.send()
        stop()
    }

    // MARK: Learn (a guided tour: a card walks from one change to the next)

    func startLearn(bySentence: Bool? = nil) {
        guard let model else { return }
        expanded = false; openChangeID = nil
        let sentence = bySentence ?? model.settings.learnBySentence
        if bySentence != nil { model.settings.learnBySentence = sentence; model.settings.save() }
        let sorted = visible.sorted { ($0.location ?? 0) < ($1.location ?? 0) }
        var queue: [[UUID]] = []
        // Group by sentence first (both modes use it).
        do {
            var groupEnd = -1
            for c in sorted {
                let span = sentenceSpan(start: c.location ?? 0, end: (c.location ?? 0) + (c.length ?? 0))
                if let last = queue.indices.last, span.lowerBound < groupEnd { queue[last].append(c.id); groupEnd = max(groupEnd, span.upperBound) }
                else { queue.append([c.id]); groupEnd = span.upperBound }
            }
            // A rewrite can move words across sentences ("…, so" + "I might not be available.").
            // Join a step with the next until its improved text ends like a sentence.
            var i = 0
            while i < queue.count - 1 {
                let after = step(for: queue[i], bySentence: true)?.after.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if let last = after.last, ".!?".contains(last) { i += 1 } else { queue[i] += queue.remove(at: i + 1) }
            }
        }
        if !sentence {
            // Word by word, except sentences that were largely rewritten: single swaps there make no sense alone.
            queue = queue.flatMap { ids -> [[UUID]] in
                guard let st = step(for: ids, bySentence: true) else { return ids.map { [$0] } }
                let changed = st.changes.reduce(0) { $0 + max($1.from.count, $1.to.count) }
                return Double(changed) / Double(max(1, st.before.count)) > 0.35 ? [ids] : ids.map { [$0] }
            }
        }
        learn = LearnState(queue: queue, bySentence: sentence)
        recordIfNeeded()
        prepareLearnStep()
    }

    /// Expands a range to whole sentences of the current text, staying inside the checked message.
    private func sentenceSpan(start: Int, end: Int) -> Range<Int> {
        let ns = lastValue as NSString
        let lo = baseOffset, hi = min(ns.length, baseOffset + (checkedText as NSString).length)
        func isStop(_ i: Int) -> Bool { guard i >= 0, i < ns.length, let u = Unicode.Scalar(ns.character(at: i)) else { return false }; return ".!?\n".unicodeScalars.contains(u) }
        var s0 = min(max(start, lo), hi)
        while s0 > lo && !isStop(s0 - 1) { s0 -= 1 }
        while s0 < hi, let u = Unicode.Scalar(ns.character(at: s0)), CharacterSet.whitespacesAndNewlines.contains(u) { s0 += 1 }
        var e0 = min(max(end, s0), hi)
        // Run on to the end of the sentence, including its closing punctuation.
        if !(e0 > s0 && isStop(e0 - 1)) { while e0 < hi { e0 += 1; if isStop(e0 - 1) { break } } }
        return s0..<max(e0, min(end, hi))
    }

    var learnStep: LearnStep? {
        guard let l = learn, !l.finished, l.index < l.queue.count else { return nil }
        let ids = l.queue[l.index]
        return step(for: ids, bySentence: l.bySentence || ids.count > 1)
    }

    func step(for ids: [UUID], bySentence: Bool) -> LearnStep? {
        let cs = changes.filter { ids.contains($0.id) && $0.location != nil }.sorted { $0.location! < $1.location! }
        guard let first = cs.first else { return nil }
        let ns = lastValue as NSString
        var start = first.location!, end = cs.map { $0.location! + ($0.length ?? 0) }.max()!
        if bySentence { let r = sentenceSpan(start: start, end: end); start = min(start, r.lowerBound); end = max(end, r.upperBound) }
        guard end <= ns.length else { return nil }
        let before = ns.substring(with: NSRange(location: start, length: end - start))
        let after = NSMutableString(string: before)
        for c in cs.reversed() { after.replaceCharacters(in: NSRange(location: c.location! - start, length: c.length ?? 0), with: c.to) }
        var prefix = "", suffix = ""
        if !bySentence {
            // Up to four words either side, so a single swap still reads in context.
            let pre = ns.substring(with: NSRange(location: max(baseOffset, start - 40), length: start - max(baseOffset, start - 40)))
            let words = pre.split(separator: " ", omittingEmptySubsequences: false)
            prefix = ((words.count > 4 ? "…" : "") + words.suffix(4).joined(separator: " ")).trimmingCharacters(in: .whitespaces)
            let hi = min(ns.length, end + 40)
            let post = ns.substring(with: NSRange(location: end, length: hi - end))
            let pw = post.split(separator: " ", omittingEmptySubsequences: false)
            suffix = (pw.prefix(5).joined(separator: " ") + (pw.count > 5 ? "…" : "")).trimmingCharacters(in: .whitespaces)
        }
        // Removing a word must not leave a double space behind.
        return LearnStep(ids: ids, start: start, length: end - start, before: before, after: Self.tidyInner(after as String, like: before), prefix: prefix, suffix: suffix, changes: cs)
    }

    /// A sentence that was largely rewritten is taught as one idea, not as its diff fragments.
    func heavyNote(for step: LearnStep) -> String? {
        guard step.changes.count >= 3 else { return nil }
        // Changes that each have a rule to teach are taught one by one, however many there are.
        let taught = step.changes.filter { $0.tip != nil || $0.practiceRight != nil }.count
        guard taught * 2 < step.changes.count else { return nil }
        let changed = step.changes.reduce(0) { $0 + max($1.from.count, $1.to.count) }
        guard Double(changed) / Double(max(1, step.before.count)) > 0.35 else { return nil }
        let words = RuleBook.words(step.before)
        // The longest run of 3+ words that appears twice: a thought that was started over.
        for n in stride(from: min(6, words.count / 2), through: 3, by: -1) {
            var seen = Set<String>()
            for i in 0...(words.count - n) {
                let gram = words[i..<(i + n)].joined(separator: " ")
                if !seen.insert(gram).inserted {
                    return "You started this thought more than once (“\(gram) …” appears twice). Decide the one thing you want to say, then say it once, main point first."
                }
            }
        }
        if step.after.count < step.before.count * 3 / 4 {
            return "Your version circles the point before reaching it. This one puts the point first and drops the words that don't add anything."
        }
        return "Each part of your sentence was understandable, but together they were hard to follow. This version puts the ideas in the order a reader expects."
    }

    func prepareLearnStep() {
        guard var l = learn else { return }
        // Drop steps whose changes are gone (typed over, muted).
        for i in l.queue.indices { l.queue[i].removeAll { id in !changes.contains { $0.id == id } } }
        let current = l.index < l.queue.count ? l.queue[l.index] : []
        l.queue.removeAll(where: \.isEmpty)
        if let i = l.queue.firstIndex(of: current) { l.index = i }
        if l.index >= l.queue.count { l.finished = true; learn = l; layout(); return }
        l.picked = nil
        l.recall = nil
        l.betterFirst = (l.queue[l.index][0].uuid.0 & 1) == 1
        learn = l
        layout()
    }

    func pick(better: Bool) {
        guard var l = learn, l.picked == nil else { return }
        l.picked = better
        l.answered += 1
        if better { l.right += 1 }
        learn = l
    }

    func reveal() { guard var l = learn else { return }; l.picked = true; learn = l }

    /// They put the corrected wording back, after seeing why.
    func recall(correct: Bool) {
        guard var l = learn, l.recall == nil else { return }
        l.recall = correct
        learn = l
    }

    private func noteLearned(_ step: LearnStep) {
        let names = heavyNote(for: step) != nil ? ["Clearer sentence"] : step.changes.filter { $0.tip != nil || $0.practiceRight != nil }.compactMap(\.label)
        for n in names where learn?.learned.contains(n) == false { learn?.learned.append(n) }
    }

    func learnUse() {
        guard let step = learnStep else { return }
        noteLearned(step)
        Task {
            guard await write(location: step.start, length: step.length, text: step.after, expecting: step.before) else {
                flash("\(appName) didn't take that edit. Nothing was changed."); return
            }
            step.changes.forEach { model?.noteInlineAccepted($0) }
            undoStack.append(Edit(location: step.start, newText: step.after, oldText: step.before, label: step.changes.first?.label ?? "Edit"))
            changes.removeAll { step.ids.contains($0.id) }
            let delta = (step.after as NSString).length - step.length
            for i in changes.indices where (changes[i].location ?? 0) >= step.start + step.length { changes[i].location = (changes[i].location ?? 0) + delta }
            rebuildProposal()
            nextLearn()
        }
    }

    func learnKeep() {
        guard let step = learnStep else { return }
        noteLearned(step)
        step.changes.forEach { RewriteGuard.rememberDismissal(from: $0.from, to: $0.to) }
        changes.removeAll { step.ids.contains($0.id) }
        rebuildProposal()
        nextLearn()
    }

    func nextLearn() {
        guard var l = learn else { return }
        l.index += 1
        l.completed += 1
        learn = l
        prepareLearnStep()
    }

    func endLearn() {
        learn = nil
        afterEdit()
    }
}

/// Global shortcuts that exist only while the companion is showing suggestions.
@MainActor
final class SessionKeys {
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private let base: UInt32
    static let signature = OSType(0x48485354) // 'HHST'
    init(base: UInt32 = 0) { self.base = base }

    func register(_ items: [(UInt32, UInt32, () -> Void)]) {
        unregisterAll()
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard id.signature == SessionKeys.signature else { return OSStatus(eventNotHandledErr) }
                let keys = Unmanaged<SessionKeys>.fromOpaque(userData).takeUnretainedValue()
                let n = id.id
                // Another SessionKeys instance may own this id: let it through.
                guard MainActor.assumeIsolated({ keys.actions[n] != nil }) else { return OSStatus(eventNotHandledErr) }
                DispatchQueue.main.async { MainActor.assumeIsolated { keys.actions[n]?() } }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        }
        for (i, item) in items.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: base + UInt32(i + 1))
            if RegisterEventHotKey(item.0, item.1, id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                refs.append(ref); actions[base + UInt32(i + 1)] = item.2
            }
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []; actions = [:]
    }
}
