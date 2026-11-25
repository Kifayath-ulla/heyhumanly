import SwiftUI
import AppKit

/// The standard Settings window: General, Engine and Privacy.
struct SettingsView: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        TabView(selection: $model.settingsTab) {
            GeneralSettings(model: model).tabItem { Label("General", systemImage: "gearshape") }.tag(SettingsTab.general)
            EngineSettings(model: model).tabItem { Label("Engine", systemImage: "cpu") }.tag(SettingsTab.engine)
            PrivacySettings(model: model).tabItem { Label("Privacy", systemImage: "hand.raised") }.tag(SettingsTab.privacy)
        }
        .frame(width: 560)
        .onAppear { model.accessibilityTrusted = AccessibilityBridge.isTrusted; model.refreshStatus() }
    }
}

private struct GeneralSettings: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        Form {
            Section {
                LabeledContent("Fix selection") {
                    HStack(spacing: 8) {
                        if model.isRecordingShortcut {
                            Text("Press the new shortcut…").foregroundStyle(.secondary)
                            Button("Cancel") { model.stopRecording() }
                        } else {
                            ShortcutKeys(label: model.shortcutLabel)
                            Button("Change") { model.recordShortcut() }
                        }
                    }
                }
                if let error = model.shortcutError {
                    Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Picker("Default style", selection: Binding(get: { model.settings.defaultStyle }, set: { model.settings.defaultStyle = $0; model.settings.save() })) {
                    ForEach(WritingStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
            }
            Section {
                LabeledContent("Accessibility") {
                    if model.accessibilityTrusted {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Allow…") { AccessibilityBridge.requestTrust() }
                    }
                }
            } footer: {
                Text(model.accessibilityTrusted ? "HeyHumanly can read your selection and replace it in other apps."
                     : "Without it, copy text first: ⌃⌥Space rewrites what you copied and Enter copies the result.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Never read text in") {
                ForEach(pausedApps, id: \.id) { app in
                    HStack {
                        Text(app.title)
                        Spacer()
                        Button { setPaused(app.id, false) } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).accessibilityLabel("Stop pausing \(app.title)")
                    }
                }
                Button("Add App…", action: addApp)
            }
            Section {
                Toggle("Labs: check as I type", isOn: Binding(get: { model.settings.autoCheck }, set: { model.setCoaching($0) }))
                if model.dismissedCount > 0 {
                    LabeledContent("\(model.dismissedCount) dismissed suggestion\(model.dismissedCount == 1 ? "" : "s")") {
                        Button("Forget dismissed suggestions") { model.resetDismissals() }
                    }
                }
            } footer: {
                Text("Underlines mistakes in text fields when you pause typing. Only with an engine on this Mac; password fields and the apps above are never read.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Show Welcome Again") { model.showOnboarding() }
            }
        }
        .formStyle(.grouped)
        .frame(height: 560)
    }

    private var pausedApps: [(id: String, title: String)] {
        model.settings.pausedApps.map { ($0, Self.appName($0)) }.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func setPaused(_ id: String, _ paused: Bool) {
        if paused { model.settings.pausedApps.insert(id) } else { model.settings.pausedApps.remove(id) }
        model.settings.save()
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { if let id = Bundle(url: url)?.bundleIdentifier { setPaused(id, true) } }
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
}

private struct EngineSettings: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if model.showConsent && !model.settings.onlineConsent { OnlineConsentCard(model: model) }
                EngineSettingsCard(model: model)
                ollamaCard
            }
            .padding(20)
        }
        .frame(height: 560)
    }

    private var ollamaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("My Ollama", systemImage: "server.rack").font(.system(size: 14, weight: .semibold))
                Spacer()
                StatusDot(color: model.ollama.color(model: model.settings.model))
                Text(model.ollama.summary(model: model.settings.model)).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if !model.writingModels.isEmpty {
                Picker("Model", selection: Binding(get: { model.settings.model }, set: { model.selectModel($0) })) {
                    ForEach(model.writingModels, id: \.self) { Text($0).tag($0) }
                    if !model.writingModels.contains(where: { CoachModel.sameModel($0, model.settings.model) }) {
                        Text(model.settings.model).tag(model.settings.model)
                    }
                }
            }
            HStack {
                TextField("Endpoint", text: $model.settingsEndpoint)
                    .textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                    .onSubmit { model.saveConnection() }.accessibilityLabel("Ollama endpoint")
                Button("Check") { model.saveConnection() }
            }
            Text("Uses Ollama you run yourself. Press Return to save the endpoint.").font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .card()
    }
}

private struct PrivacySettings: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        Form {
            Section("Where your text goes") {
                row("On this Mac (Apple)", "Apple's on-device model. Your text never leaves your Mac.")
                row("On this Mac (offline)", "Ollama run by HeyHumanly on this Mac. Your text never leaves your Mac.")
                row("On this Mac (Ollama)", "Your own Ollama at \(model.settings.endpoint). On this Mac unless you point it elsewhere or pick a cloud model.")
                row("Online (Cloudflare)", "Only the text you rewrite is sent to HeyHumanly's server and Cloudflare Workers AI, with a random install ID for the daily limit. Not stored or logged. Only after you allow it.")
            }
            Section("Always") {
                row("Nothing is saved", "HeyHumanly keeps no history of your text.")
                row("Only when you ask", "Text is read when you press \(model.shortcutLabel), or as you type if you turn on Labs. Password fields and the apps in General are never read.")
                row("No analytics", "HeyHumanly doesn't track you or send usage data.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 560)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
