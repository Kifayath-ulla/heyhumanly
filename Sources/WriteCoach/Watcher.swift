import AppKit
import ApplicationServices

/// Notices when you pause typing in a text field and asks the companion to check it.
/// Reads only the focused field, never password fields or paused apps, and only when the model runs on this Mac.
@MainActor
final class TextWatcher {
    weak var model: CoachModel?
    weak var session: InlineSession?
    private var timer: Timer?
    private var lastValue = ""
    private var lastChange = Date.distantPast
    private var lastChecked = ""
    private var lastPID: pid_t = 0
    private var enabledPIDs = Set<pid_t>()
    /// Pause after the last keystroke before checking.
    private var idle: TimeInterval { model?.settings.typingPause ?? 1.2 }
    static let textRoles: Set<String> = ["AXTextArea", "AXTextField", "AXComboBox", "AXSearchField"]

    private var lastProbe = ""
    /// Logs what the focused element looks like once per change (role, value, bounds), for compatibility work.
    private func probe(_ el: AXUIElement?, _ bundle: String) {
        let desc: String
        if let el {
            let v = AXText.string(el, kAXValueAttribute)
            desc = "\(bundle) role=\(AXText.role(el) ?? "nil") sub=\(AXText.subrole(el) ?? "nil") value=\(v.map { "\($0.count)ch" } ?? "nil") range=\(AXText.rangeBounds(el, location: 0, length: 1) != nil) marker=\(AXText.markerBounds(el, location: 0, length: 3).map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "nil")"
        } else { desc = "\(bundle) focused=nil" }
        guard desc != lastProbe else { return }
        lastProbe = desc
        appLog.notice("probe \(desc, privacy: .public)")
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
    }

    private func tick() {
        guard let model, let session, model.coachingActive, AXIsProcessTrusted(),
              CompanionService.isLocal(model.settings.endpoint) else { return }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        let bundle = front.bundleIdentifier ?? ""
        if model.settings.pausedApps.contains(bundle) { if session.isActive { session.stop() }; return }
        if front.processIdentifier != lastPID {
            lastPID = front.processIdentifier
            lastValue = ""; lastChecked = ""
            if !enabledPIDs.contains(front.processIdentifier) {
                enabledPIDs.insert(front.processIdentifier)
                AXText.enableManualAccessibility(pid: front.processIdentifier)
            }
        }
        guard let el = AXText.focusedElement() else { probe(nil, bundle); return }
        probe(el, bundle)
        guard !AXText.isSecure(el),
              let role = AXText.role(el), Self.textRoles.contains(role),
              let value = AXText.string(el, kAXValueAttribute) else { return }
        // A suggestion card or Learn is open: don't re-check under the user.
        if session.isSameElement(el), session.openChangeID != nil || session.learn != nil || session.expanded { lastValue = value; return }
        if value != lastValue {
            lastValue = value; lastChange = Date()
            return
        }
        guard Date().timeIntervalSince(lastChange) >= idle, value != lastChecked else { return }
        // Our own edit (Fix all, Use this, Undo): nothing new to check, and the Undo pill stays.
        if session.isSameElement(el), value == session.lastWritten { lastChecked = value; return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // Too short to be worth a check, or looks like code / a URL / a search query.
        guard trimmed.split(whereSeparator: \.isWhitespace).count >= 4, trimmed.count <= 6000,
              !trimmed.hasPrefix("http"), !trimmed.contains("{\n"), !trimmed.hasPrefix("$ ") else { return }
        lastChecked = value
        _ = session.start(element: el, appName: front.localizedName ?? "this app", bundleID: bundle, auto: true)
    }
}
