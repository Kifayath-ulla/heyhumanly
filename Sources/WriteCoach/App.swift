import SwiftUI
import AppKit

@main
struct HeyHumanlyApp: App {
    @StateObject private var model = CoachModel()

    init() {
        // Developer check: `HeyHumanly --guard "<original>" "<rewrite>"` prints what the meaning guard lets through.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--guard"), i + 2 < args.count {
            print(RewriteGuard.sanitize(original: args[i + 1], rewrite: args[i + 2], preserve: []))
            exit(0)
        }
        // `HeyHumanly --teach "<text>"` runs one full check (rewrite, guard, explanations) and prints it.
        if let i = args.firstIndex(of: "--teach"), i + 1 < args.count {
            let text = args[i + 1], fixOnly = args.contains("--fix-only")
            let s = AppSettings.load()
            Task { @MainActor in
                do {
                    let raw = try await CompanionService.rewrite(text, tone: fixOnly ? .fixOnly : .auto, appName: "Slack", preserve: [], endpoint: s.endpoint, model: s.model)
                    let clean = RewriteGuard.sanitize(original: text, rewrite: raw, preserve: [])
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

    var body: some Scene {
        // Single dashboard window: openWindow(id:) brings it back instead of spawning copies.
        Window("HeyHumanly", id: "dashboard") {
            DashboardView(model: model)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.openDashboard(section: .settings) }.keyboardShortcut(",")
            }
            CommandGroup(after: .newItem) {
                Button("Open Coach") { model.showCoach() }.keyboardShortcut("k")
            }
        }

        // The coach is a floating NSPanel owned by CoachModel, so the shortcut works even when the dashboard is closed.
        MenuBarExtra {
            Button("Open Coach  (\(model.shortcutLabel))") { model.showCoach() }
            Button("Open Dashboard") { model.openDashboard(section: .home) }
            Divider()
            if model.isSnoozed {
                Button("Resume coaching now") { model.setCoaching(true) }
            } else if model.settings.autoCheck {
                Button("Pause coaching for 1 hour") { model.snooze(minutes: 60) }
                Button("Turn off checking as I type") { model.setCoaching(false) }
            } else {
                Button("Turn on checking as I type") { model.setCoaching(true) }
            }
            Divider()
            Text(model.ollama.summary(model: model.settings.model))
            Button("Settings…") { model.openDashboard(section: .settings) }
            Divider()
            Button("Quit HeyHumanly") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: model.coachingActive ? "leaf.fill" : "leaf").accessibilityLabel(model.coachingActive ? "HeyHumanly" : "HeyHumanly, paused")
        }
    }
}
