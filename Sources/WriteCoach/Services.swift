import SwiftUI
import AppKit
import Carbon.HIToolbox
import os

/// Visible with: log show --last 10m --info --predicate 'subsystem == "com.heyhumanly.app"'
let appLog = Logger(subsystem: "com.heyhumanly.app", category: "coach")

struct AppSettings: Codable {
    var endpoint = "http://localhost:11434/api/generate"
    /// 16 GB Macs get the 7B model; smaller Macs get the 3B one.
    var model = ProcessInfo.processInfo.physicalMemory >= 12 * 1_073_741_824 ? "qwen2.5:7b" : "qwen2.5:3b"
    var shortcutHint = "Control + Option + Space"
    var shortcutKeyCode: UInt32 = UInt32(kVK_Space)
    var shortcutModifiers: UInt32 = UInt32(controlKey | optionKey)
    var shortcutLabel = "⌃⌥Space"
    // Optional so settings saved by older versions still decode.
    var defaultStyleRaw: String?
    var appStylesRaw: [String: String]?
    var onboarded: Bool?
    var mutedCategoriesRaw: [String]?
    var appearanceRaw: String?
    // Companion (added 2026-11-10); optional so older settings decode.
    var autoCheckRaw: Bool?
    var engineRaw: String?
    var onlineEndpointRaw: String?
    var onlineConsentRaw: Bool?
    var managedModelRaw: String?
    var explainLanguageRaw: String?
    var pausedAppsRaw: [String]?
    var learnLevelsRaw: [String]?
    var tryFirstInlineRaw: Bool?
    var learnByRaw: String?
    var dotActionRaw: String?
    var suggestStyleRaw: Bool?
    var typingPauseRaw: Double?
    var copyInsteadRaw: Bool?
    /// Chose "Copy instead" of Accessibility: the shortcut rewrites the clipboard right away.
    var copyInstead: Bool { get { copyInsteadRaw ?? false } set { copyInsteadRaw = newValue } }
    /// Clicking the dot starts a lesson (default) or opens the ready-made fix.
    var dotTeaches: Bool { get { dotActionRaw != "fix" } set { dotActionRaw = newValue ? "teach" : "fix" } }
    /// Also suggest clearer wording, not only real mistakes.
    var suggestStyle: Bool { get { suggestStyleRaw ?? true } set { suggestStyleRaw = newValue } }
    /// Seconds of no typing before a field is checked.
    var typingPause: Double { get { min(6, max(0.8, typingPauseRaw ?? 1.2)) } set { typingPauseRaw = newValue } }
    /// Learn a whole sentence at a time (default) or one change at a time.
    var learnBySentence: Bool { get { learnByRaw != "word" } set { learnByRaw = newValue ? "sentence" : "word" } }

    /// Check the focused field automatically after a typing pause.
    var autoCheck: Bool { get { autoCheckRaw ?? false } set { autoCheckRaw = newValue } }
    /// Language used for explanations ("English", "Hindi", …).
    var explainLanguage: String { get { explainLanguageRaw ?? "English" } set { explainLanguageRaw = newValue } }
    /// Bundle ids where the companion never reads text.
    var pausedApps: Set<String> { get { Set(pausedAppsRaw ?? Self.defaultPausedApps) } set { pausedAppsRaw = newValue.sorted() } }
    /// Which learning levels the Learn tour walks through.
    var learnLevels: Set<LearnLevel> {
        get { Set((learnLevelsRaw ?? LearnLevel.allCases.map(\.rawValue)).compactMap(LearnLevel.init(rawValue:))) }
        set { learnLevelsRaw = newValue.map(\.rawValue).sorted() }
    }
    /// Learn asks "which reads better?" before revealing the answer.
    var tryFirstInline: Bool { get { tryFirstInlineRaw ?? true } set { tryFirstInlineRaw = newValue } }
    /// Password managers, terminals and code editors are never read.
    static let defaultPausedApps = ["com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.apple.keychainaccess",
                                    "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
                                    "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92"]
    static let explainLanguages = ["English", "Hindi", "Urdu", "Arabic", "Spanish", "Portuguese", "French", "German", "Indonesian", "Japanese", "Korean", "Chinese"]

    /// Mistake types the user already knows: still fixed automatically, but not shown, taught or reviewed.
    var mutedCategories: Set<MistakeCategory> {
        get { Set((mutedCategoriesRaw ?? []).compactMap(MistakeCategory.init(rawValue:))) }
        set { mutedCategoriesRaw = newValue.map(\.rawValue).sorted() }
    }

    var defaultStyle: WritingStyle {
        get { defaultStyleRaw.flatMap(WritingStyle.init(rawValue:)) ?? .polish }
        set { defaultStyleRaw = newValue.rawValue }
    }
    /// Per-app default styles, keyed by bundle identifier.
    var appStyles: [String: WritingStyle] {
        get {
            guard let raw = appStylesRaw else { return Self.suggestedAppStyles }
            return raw.compactMapValues(WritingStyle.init(rawValue:))
        }
        set { appStylesRaw = newValue.mapValues(\.rawValue) }
    }
    static let suggestedAppStyles: [String: WritingStyle] = [
        "com.tinyspeck.slackmacgap": .friendly, "com.apple.MobileSMS": .friendly, "net.whatsapp.WhatsApp": .friendly,
        "com.hnc.Discord": .friendly, "com.apple.mail": .professional, "com.microsoft.Outlook": .professional,
    ]
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "heyhumanly.settings"), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }
    /// History, review cards and the dictionary were removed in 0.2; delete what older versions saved.
    static func removeRetiredData() {
        for key in ["heyhumanly.history", "heyhumanly.reviews", "heyhumanly.dictionary", "heyhumanly.tryFirst"] { UserDefaults.standard.removeObject(forKey: key) }
    }
    func save() { if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: "heyhumanly.settings") } }
}

enum CoachError: LocalizedError {
    case noEndpoint, ollamaNotRunning, modelMissing(String), server(Int, String), invalidResponse, appleUnavailable(String), tooLongForApple

    var errorDescription: String? {
        switch self {
        case .noEndpoint: return "No AI endpoint is set. Add the Ollama URL in Settings (default http://localhost:11434/api/generate)."
        case .ollamaNotRunning: return "Ollama isn't running. Open the Ollama app or run `ollama serve`, then try again."
        case .modelMissing(let model): return "The model \(model) isn't installed. Run `ollama pull \(model)` in Terminal, or pick an installed model in Settings."
        case .server(let code, let body): return "Ollama returned an error (\(code)): \(body.prefix(200))"
        case .invalidResponse: return "The model returned a response HeyHumanly couldn't read. Try again, or try a different model."
        case .appleUnavailable(let why): return "Apple's on-device model isn't available. \(why)"
        case .tooLongForApple: return "That's too long for Apple's on-device model. Select a shorter part, or switch to offline coaching in Settings."
        }
    }
}

struct CoachService {
    /// Asks the model to categorise and explain changes that were computed locally (so none are missed).
    static func explain(original: String, rewrite: String, changes: [Change], endpoint: String, model: String) async -> [(MistakeCategory, String)]? {
        guard !changes.isEmpty, let url = URL(string: endpoint) else { return nil }
        let cats = MistakeCategory.allCases.map(\.rawValue)
        let lines = changes.enumerated().map { "\($0.offset + 1). \"\($0.element.from)\" -> \"\($0.element.to)\"" }.joined(separator: "\n")
        let prompt = """
        You are a writing teacher. A text was corrected.
        Original: \(original)
        Corrected: \(rewrite)
        Changes:
        \(lines)
        For EACH numbered change write one short sentence (max 14 words) explaining the grammar or spelling rule, addressed to the writer as "you", for example "Use 'have' after 'should', not 'of'." Then give its category (one of \(cats)). Return JSON {"items":[{"from":"<original words>","reason":"<sentence>","category":"<category>"}]}, one item per change, in order.
        """
        let schema: [String: Any] = ["type": "object", "required": ["items"], "properties": ["items": ["type": "array", "items": [
            "type": "object", "required": ["from", "reason", "category"],
            "properties": ["from": ["type": "string"], "reason": ["type": "string"], "category": ["type": "string", "enum": cats]]]]]]
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": false, "think": false, "format": schema, "keep_alive": "30m", "options": ["temperature": 0.1, "num_predict": 60 + 40 * changes.count]])
        struct Outer: Decodable { let response: String }
        struct Items: Decodable { struct I: Decodable { let from: String?; let category: String; let reason: String }; let items: [I] }
        guard let (data, _) = try? await LLM.data(for: request),
              let outer = try? JSONDecoder().decode(Outer.self, from: data),
              let parsed = try? JSONDecoder().decode(Items.self, from: Data(outer.response.utf8)) else { return nil }
        let norm = { (s: String) in s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
        return changes.indices.map { i in
            // Prefer the item that echoes this change's words; numbering from a small model can drift.
            let byWords = parsed.items.first { norm($0.from ?? "") == norm(changes[i].from) && !norm(changes[i].from).isEmpty }
            let item = byWords ?? (i < parsed.items.count ? parsed.items[i] : nil)
            return (MistakeCategory(rawValue: item?.category ?? "") ?? changes[i].category, item?.reason ?? "")
        }
    }

    // MARK: Streaming rewrite (fast path)

    /// Streams the corrected text as plain tokens so the user sees it appear immediately.
    /// Capped with num_predict so a small model can never run away.
    static func streamRewrite(text: String, style: WritingStyle, appName: String?, preserve: [String],
                              endpoint: String, model: String, onToken: @escaping @MainActor (String) -> Void) async throws -> String {
        guard !endpoint.isEmpty else { throw CoachError.noEndpoint }
        let preserveRule = preserve.isEmpty ? "" : "\nKeep these words and phrases exactly as written: " + preserve.map { "\"\($0)\"" }.joined(separator: ", ") + "."
        let context = appName.map { "\nThe text is being written in \($0)." } ?? ""
        let prompt = """
        You are HeyHumanly, a writing coach.
        \(style.instruction)
        Correct obvious typos when the meaning makes the intended word clear (for example, "thung" becomes "thing"). Keep names, numbers, links, line breaks and technical terms exactly, and leave anything between backticks (`like this`) exactly as written. Never replace a vague word such as "thing", "stuff" or "it" with a more specific noun, and never swap a correct word for one with a different meaning.
        If the writer repeats a phrase back to back ("I don't know, I don't know"), keep it once. Never introduce a repeated phrase.\(preserveRule)\(context)
        Reply with ONLY the corrected text. No quotes, no labels, no notes.
        Text:
        \(text)
        """
        let limit = min(2048, max(200, text.count / 2 + 120))
        return try await stream(prompt: prompt, endpoint: endpoint, model: model, limit: limit, temperature: 0.1, onToken: onToken)
    }

    /// Streams one prompt from the active engine (Apple answers in one piece). Returns the cleaned answer.
    static func stream(prompt: String, endpoint: String, model: String, limit: Int, temperature: Double,
                       onToken: @escaping @MainActor (String) -> Void) async throws -> String {
        guard !endpoint.isEmpty, let url = URL(string: endpoint) else { throw CoachError.noEndpoint }
        if LLM.isApple(endpoint) {
            guard prompt.count <= AppleModel.maxInputChars + 1200 else { throw CoachError.tooLongForApple }
            let answer = try await AppleModel.respond(prompt: prompt, maxTokens: limit, temperature: temperature)
            await onToken(answer)
            let cleaned = cleanRewrite(answer)
            guard !cleaned.isEmpty else { throw CoachError.invalidResponse }
            return cleaned
        }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "prompt": prompt, "stream": true, "think": false, "keep_alive": "30m",
                                                                       "options": ["temperature": temperature, "num_predict": limit]])
        let bytes: URLSession.AsyncBytes, response: URLResponse
        do { (bytes, response) = try await URLSession.shared.bytes(for: request) }
        catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet].contains(error.code) {
            throw CoachError.ollamaNotRunning
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard status < 300 else {
            var body = ""; for try await line in bytes.lines { body += line }
            if status == 404 || body.localizedCaseInsensitiveContains("not found") { throw CoachError.modelMissing(model) }
            throw CoachError.server(status, body)
        }
        struct Chunk: Decodable { let response: String?; let error: String? }
        var out = ""
        let started = Date(); var firstToken: TimeInterval?
        // Tokens go to the UI in batches (~10 a second): a main-actor hop and redraw per token falls behind on long text.
        var pending = "", lastSent = Date.distantPast
        defer { appLog.notice("rewrite \(model, privacy: .public): first token \(firstToken ?? -1, format: .fixed(precision: 2))s, total \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s, \(out.count) chars") }
        for try await line in bytes.lines {
            if firstToken == nil { firstToken = Date().timeIntervalSince(started) }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: Data(line.utf8)) else { continue }
            if let error = chunk.error { throw CoachError.server(500, error) }
            if let token = chunk.response, !token.isEmpty {
                out += token; pending += token
                if Date().timeIntervalSince(lastSent) >= 0.1 { await onToken(pending); pending = ""; lastSent = Date() }
            }
        }
        if !pending.isEmpty { await onToken(pending) }
        let cleaned = cleanRewrite(out)
        guard !cleaned.isEmpty else { throw CoachError.invalidResponse }
        return cleaned
    }

    /// Removes labels or wrapping quotes a model sometimes adds around the answer.
    static func cleanRewrite(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Corrected text:", "Corrected:", "Here is the corrected text:", "Here's the corrected text:", "Rewrite:"] where s.lowercased().hasPrefix(prefix.lowercased()) {
            s = String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s.count > 1, let f = s.first, let l = s.last, (f == "\"" && l == "\"") || (f == "“" && l == "”") { s = String(s.dropFirst().dropLast()) }
        return StyleChecker.collapseRepetitions(s)
    }

    static func pull(model: String, endpoint: String, progress: @escaping @MainActor (Double, String) -> Void) async throws {
        guard var comps = URLComponents(string: endpoint) else { throw CoachError.noEndpoint }
        comps.path = "/api/pull"; comps.query = nil
        guard let url = comps.url else { throw CoachError.noEndpoint }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 3600
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true, "think": false])
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CoachError.server((response as? HTTPURLResponse)?.statusCode ?? 0, "pull failed") }
        struct Line: Decodable { let status: String?; let total: Double?; let completed: Double?; let error: String? }
        for try await raw in bytes.lines {
            guard let line = try? JSONDecoder().decode(Line.self, from: Data(raw.utf8)) else { continue }
            if let error = line.error { throw CoachError.server(500, error) }
            let fraction = (line.total ?? 0) > 0 ? (line.completed ?? 0) / line.total! : 0
            let status = line.status ?? ""
            await progress(status == "success" ? 1 : fraction, status)
        }
    }

    /// Loads the model into memory (empty prompt) so the first real request doesn't pay the cold-start cost.
    static func prewarm(endpoint: String, model: String) async {
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["model": model, "keep_alive": "30m", "stream": false, "think": false])
        _ = try? await LLM.data(for: request)
    }
}

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]
    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { dict[type] = data } }
            return dict
        }
    }
    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

@MainActor
final class AccessibilityBridge {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Removes HeyHumanly's own Accessibility entry (never another app's). An ad-hoc signed update no longer matches
    /// the old entry, so macOS ignores it even though its switch still looks on; a fresh entry has to be granted.
    static func resetOwnGrant() async -> Bool {
        guard let id = Bundle.main.bundleIdentifier, !id.isEmpty else { return false }
        return await withCheckedContinuation { done in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            p.arguments = ["reset", "Accessibility", id]
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            p.terminationHandler = { done.resume(returning: $0.terminationStatus == 0) }
            do { try p.run() } catch { done.resume(returning: false) }
        }
    }

    /// 1) Accessibility API, 2) simulated Cmd+C with the clipboard saved and restored.
    func selectedText() async -> String? {
        if let text = axSelectedText() { return text }
        await waitForModifierRelease()
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let before = pasteboard.changeCount
        postCommand(key: CGKeyCode(kVK_ANSI_C))
        var copied: String?
        for _ in 0..<25 {   // up to ~0.5s
            try? await Task.sleep(nanoseconds: 20_000_000)
            if pasteboard.changeCount != before { copied = pasteboard.string(forType: .string); break }
        }
        snapshot.restore(to: pasteboard)
        guard let copied, !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return copied
    }

    func replaceSelectedText(with text: String) async {
        await waitForModifierRelease()
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postCommand(key: CGKeyCode(kVK_ANSI_V))
        try? await Task.sleep(nanoseconds: 500_000_000)   // let the target app read the clipboard
        snapshot.restore(to: pasteboard)
    }

    private func axSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        var selection: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selection) == .success,
              let text = selection as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// The shortcut's modifiers are usually still held; wait so Cmd+C isn't sent as Ctrl+Opt+Cmd+C.
    private func waitForModifierRelease(timeout: TimeInterval = 1.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        let mask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        while Date() < deadline {
            if CGEventSource.flagsState(.hidSystemState).intersection(mask).isEmpty { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func postCommand(key: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}

@MainActor
final class HotKey {
    static let shared = HotKey()
    private var handler: (@MainActor () -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    /// True when an enabled macOS symbolic hotkey (Spotlight, input sources, Mission Control…) uses this combo.
    /// The input-source shortcuts (⌃Space, ⌃⌥Space by default) only count with two or more keyboard input sources:
    /// with one, macOS has nothing to switch to and the shortcut still reaches HeyHumanly.
    static func isUsedByMacOS(keyCode: UInt32, modifiers: UInt32) -> Bool {
        var unmanaged: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanaged) == noErr, let array = unmanaged?.takeRetainedValue() as? [[String: Any]] else { return false }
        let mask = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        let matches = array.filter { entry in
            guard (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true,
                  let code = entry[kHISymbolicHotKeyCode as String] as? Int,
                  let mods = entry[kHISymbolicHotKeyModifiers as String] as? Int else { return false }
            return UInt32(code) == keyCode && (UInt32(mods) & mask) == (modifiers & mask)
        }.count
        guard matches > 0 else { return false }
        let inputSource = inputSourceHotKeys().filter { $0.keyCode == keyCode && $0.modifiers == modifiers & mask }.count
        return matches > inputSource || keyboardInputSourceCount() > 1
    }

    /// The enabled "Select the previous / next input source" shortcuts (ids 60 and 61 in com.apple.symbolichotkeys).
    static func inputSourceHotKeys() -> [(keyCode: UInt32, modifiers: UInt32)] {
        let saved = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        let defaults: [String: (keyCode: UInt32, modifiers: UInt32)] = ["60": (UInt32(kVK_Space), UInt32(controlKey)),
                                                                         "61": (UInt32(kVK_Space), UInt32(controlKey | optionKey))]
        return defaults.compactMap { id, standard in
            // Never changed in System Settings: on, with the standard keys.
            guard let entry = saved[id] as? [String: Any] else { return standard }
            guard (entry["enabled"] as? Bool) == true else { return nil }
            guard let p = (entry["value"] as? [String: Any])?["parameters"] as? [Int], p.count == 3 else { return standard }
            let cocoa = NSEvent.ModifierFlags(rawValue: UInt(p[2]))
            var carbon = 0
            if cocoa.contains(.command) { carbon |= cmdKey }
            if cocoa.contains(.shift) { carbon |= shiftKey }
            if cocoa.contains(.option) { carbon |= optionKey }
            if cocoa.contains(.control) { carbon |= controlKey }
            return (UInt32(p[1]), UInt32(carbon))
        }
    }

    /// Enabled keyboard layouts and input methods the input-source shortcuts cycle through.
    static func keyboardInputSourceCount() -> Int {
        let filter = [kTISPropertyInputSourceIsSelectCapable as String: true,
                      kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String] as CFDictionary
        return (TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource])?.count ?? 0
    }

    /// Installs the Carbon event handler once, then (re)registers the key. Returns the OSStatus.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, _ handler: @escaping @MainActor () -> Void) -> OSStatus {
        self.handler = handler
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                guard id.signature == OSType(0x57524348) else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { MainActor.assumeIsolated { hotKey.handler?() } }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
            guard status == noErr else { return status }
            handlerInstalled = true
        }
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        var newRef: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x57524348), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &newRef)
        if status == noErr { ref = newRef }
        appLog.notice("RegisterEventHotKey keyCode=\(keyCode) modifiers=\(modifiers) status=\(status)")
        return status
    }
}

