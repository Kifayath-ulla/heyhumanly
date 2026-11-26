import SwiftUI
import AppKit

@main
struct HeyHumanlyApp: App {
    @StateObject private var model = CoachModel()

    init() {
        Self.registerFonts()
        // Developer check: `HeyHumanly --guard "<original>" "<rewrite>" [--style Professional | --fix-only]` prints the clean-up the
        // quick panel applies to that style's rewrite (Polish by default, which goes through the meaning guard).
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--guard"), i + 2 < args.count {
            let named = args.firstIndex(of: "--style").flatMap { $0 + 1 < args.count ? WritingStyle(rawValue: args[$0 + 1]) : nil }
            let style = args.contains("--fix-only") ? .fixOnly : named ?? .polish
            let (original, rewrite) = (args[i + 1], args[i + 2])
            print(style.guarded ? RewriteGuard.sanitize(original: original, rewrite: rewrite, preserve: [], fixOnly: style == .fixOnly)
                                : TextSafety.apply(original: original, rewrite: rewrite, keepSlang: style != .professional))
            exit(0)
        }
        // `HeyHumanly --teach "<text>"` runs one full check (rewrite, guard, explanations) and prints it.
        if let i = args.firstIndex(of: "--teach"), i + 1 < args.count {
            let text = args[i + 1], fixOnly = args.contains("--fix-only")
            let s = AppSettings.load()
            Task { @MainActor in
                do {
                    let raw = try await CompanionService.rewrite(text, style: fixOnly ? .fixOnly : .polish, appName: "Slack", preserve: [], endpoint: s.endpoint, model: s.model)
                    let clean = RewriteGuard.sanitize(original: text, rewrite: raw, preserve: [], fixOnly: fixOnly)
                    print("REWRITE: \(clean)")
                    let changes = ChangeSet(original: text, rewrite: clean).changes.map { c -> Change in var c = c; c.teach(original: text, location: c.location); return c }
                    for c in changes {
                        print("- [\(c.kind ?? "?")/\(c.category.rawValue)] \"\(c.from)\" -> \"\(c.to)\" | \(c.label ?? "") | \(c.reason)\(c.tip.map { " | TIP " + $0 } ?? "")\(c.practiceRight.map { " | TRY " + $0 } ?? "")")
                    }
                    print("TAKEAWAY: \(InlineSession.lessonTip(for: changes))")
                } catch { print("ERROR: \(error.localizedDescription)") }
                exit(0)
            }
            dispatchMain()
        }
    }

    /// Newsreader (headlines) and JetBrains Mono (labels), both SIL Open Font License, bundled in Resources/Fonts.
    static func registerFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension.lowercased() == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
    }

    var body: some Scene {
        // Menu bar only (LSUIElement): no Dock icon and no main window. ⌃⌥Space opens the quick panel.
        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        Settings {
            SettingsView(model: model)
        }
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: CoachModel
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Image(systemName: "text.cursor").accessibilityLabel("HeyHumanly")
            .onAppear { model.openSettingsAction = { openSettings() } }
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: CoachModel
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button("Fix selection  (\(model.shortcutLabel))") { model.fixSelectionFromMenu() }
        Picker("Style", selection: Binding(get: { model.settings.defaultStyle }, set: { model.settings.defaultStyle = $0; model.settings.save() })) {
            ForEach(WritingStyle.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        Menu("Engine") {
            ForEach(CoachEngine.allCases, id: \.self) { e in
                Toggle(e.label, isOn: Binding(get: { model.engine == e }, set: { _ in model.chooseEngine(e) }))
                    .disabled(!model.engineSelectable(e))
            }
            Divider()
            Text(model.engineSummary)
        }
        Divider()
        Button("Settings…") { NSApp.activate(ignoringOtherApps: true); openSettings() }.keyboardShortcut(",")
        Divider()
        Button("Quit HeyHumanly") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}
