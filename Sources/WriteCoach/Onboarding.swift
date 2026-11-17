import SwiftUI
import AppKit

/// First-run tour: five short cards over the dashboard. Skippable at any point, replayable from Settings.
struct OnboardingView: View {
    @ObservedObject var model: CoachModel
    private let last = 4
    private let poll = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        let step = min(max(model.onboardingStep ?? 0, 0), last)
        ZStack {
            Color.black.opacity(0.38).ignoresSafeArea()
                .onTapGesture { }   // swallow clicks on the dashboard behind
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 5) {
                        ForEach(0...last, id: \.self) { i in
                            Capsule().fill(i == step ? Color.brand : Color.ink.opacity(i < step ? 0.35 : 0.12))
                                .frame(width: i == step ? 20 : 7, height: 7)
                        }
                    }
                    .accessibilityLabel("Step \(step + 1) of \(last + 1)")
                    Spacer()
                    Button("Skip") { model.finishOnboarding() }
                        .buttonStyle(.plain).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.secondary)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Skip the tour")
                }
                .padding(.bottom, 22)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: howItWorks
                    case 2: teachOrFix
                    case 3: permission
                    default: ready
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)

                HStack(spacing: 8) {
                    if step > 0 { Button("Back") { model.onboardingStep = step - 1 }.buttonStyle(SecondaryButtonStyle()) }
                    Spacer()
                    if step == last {
                        Button("Try an example") {
                            model.finishOnboarding()
                            model.clearDraft(); model.draft = "Please send me that thung when you have time."; model.showCoach()
                        }.buttonStyle(SecondaryButtonStyle())
                        Button("Start writing") { model.finishOnboarding() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                    } else {
                        Button("Next") { model.onboardingStep = step + 1 }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                    }
                }
                .padding(.top, 18)
            }
            .padding(28)
            .frame(width: 560)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.hairline))
            .shadow(color: .black.opacity(0.28), radius: 40, y: 18)
        }
        .onReceive(poll) { _ in
            // Permission and model status update while the tour is open, so "Allowed" appears without a restart.
            if model.accessibilityTrusted != AccessibilityBridge.isTrusted { model.accessibilityTrusted = AccessibilityBridge.isTrusted }
            if step == last, model.ollama != .checking, !(model.ollamaRunning && model.modelInstalled) { model.refreshStatus() }
        }
    }

    private func title(_ before: String, _ italic: String, _ after: String = "") -> some View {
        (Text(before) + Text(italic).italic().foregroundColor(Color.teach) + Text(after))
            .font(.serif(30, weight: .medium)).foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func bodyText(_ s: String) -> some View {
        Text(s).font(.system(size: 14)).foregroundStyle(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }

    private func point(_ icon: String, _ head: String, _ detail: String, tint: Color = .brand) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 30, height: 30).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(head).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64).accessibilityHidden(true)
            title("Fix it now, or learn ", "why", ".")
            bodyText("HeyHumanly sits beside whatever you're writing, in Slack, Mail, your browser or Notes. It catches mistakes, and when you have a minute it teaches you the rule so you stop making them.")
            point("lock.shield.fill", "Everything stays on this Mac", "The AI model runs locally. No account, no cloud, nothing is sent anywhere.", tint: .added)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Just write. Then ", "pause", ".")
            // A small picture of what appears on screen.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("hey can you send the ").foregroundStyle(Color.ink)
                    Text("reprot").foregroundStyle(Color.ink)
                        .overlay(alignment: .bottom) { WavyLine().stroke(Color.removed, lineWidth: 1.6).frame(height: 4).offset(y: 3) }
                    Text(" before the meeting").foregroundStyle(Color.ink)
                    Spacer(minLength: 8)
                    ZStack { Circle().fill(Color.removed); Text("1").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white) }
                        .frame(width: 24, height: 24)
                }
                .font(.system(size: 14))
                .padding(.horizontal, 14).padding(.vertical, 13)
            }
            .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.hairline))
            .accessibilityLabel("Example: the word reprot is underlined in red and a dot shows 1 suggestion")
            point("pause.circle", "It waits until you stop typing", "Nothing appears while you type. After a short pause, mistakes get a red underline and a small dot shows the count.")
            point("eye.slash", "It stays off your words", "The dot sits outside the text box. Start typing again and it hides.")
        }
    }

    private var teachOrFix: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Two speeds: ", "Teach me", " or Fix now.")
            point("graduationcap.fill", "Teach me (click the dot)", "You pick the right version, see the rule in one line, then put the fix back yourself. That's what makes it stick.", tint: .teach)
            point("bolt.fill", "Fix now (⌃⌥↩)", "In a hurry? One shortcut fixes every mistake. ⌘Z in the app undoes it.")
            point("xmark.circle", "Dismiss (esc)", "Don't agree? Dismiss it and it won't come back for those words. You can also stop a whole type, like punctuation.", tint: .secondary)
            bodyText("Nothing is ever changed unless you click or press a shortcut.")
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("One permission: ", "Accessibility", ".")
            bodyText("macOS only lets an app see the text box you're typing in if you allow it. HeyHumanly uses this to read that one box after you pause, and to paste a fix you accepted. It never reads password fields, password managers, terminals or code editors.")
            HStack(spacing: 12) {
                Image(systemName: "accessibility").font(.system(size: 18)).foregroundStyle(Color.brand)
                    .frame(width: 36, height: 36).background(Color.brandSoft, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility").font(.system(size: 13.5, weight: .semibold))
                    Text(model.accessibilityTrusted ? "Allowed. You're set." : "System Settings › Privacy & Security › Accessibility › turn on HeyHumanly")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.accessibilityTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.added)
                } else {
                    Button("Open Settings") { AccessibilityBridge.requestTrust(); AccessibilityBridge.openSystemSettings() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(12)
            .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !model.accessibilityTrusted {
                bodyText("You can do this later. Until then, the coach window still works with text you type or paste into it.")
            }
        }
    }

    private var ready: some View {
        let running = model.ollamaRunning
        return VStack(alignment: .leading, spacing: 16) {
            title("You're ", "ready", ".")
            statusRow(ok: running, okText: "Local AI is running", badText: "Ollama isn't running",
                      detail: running ? "Ollama, on this Mac." : "HeyHumanly notices when it starts.")
            statusRow(ok: running && model.modelInstalled, okText: "Model \(model.settings.model) is installed", badText: "Model \(model.settings.model) isn't installed",
                      detail: running && model.modelInstalled ? "Works with Wi-Fi off." : "Download it below, or pick another installed model in Settings.")
            if !(running && model.modelInstalled) { ModelSetupCard(model: model) }
            statusRow(ok: model.accessibilityTrusted, okText: "Accessibility is allowed", badText: "Accessibility is off",
                      detail: model.accessibilityTrusted ? "HeyHumanly can coach you in other apps." : "Go back one step to turn it on, or do it later in Settings.")
            HStack(spacing: 10) {
                ShortcutKeys(label: model.shortcutLabel, size: 12)
                Text("checks the box you're in right away, or opens the coach with your selected text. Change it in Settings.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            bodyText("Pause coaching any time from the leaf in the menu bar.")
        }
    }

    private func statusRow(ok: Bool, okText: String, badText: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundStyle(ok ? Color.added : Color.orange).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(ok ? okText : badText).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
        }
    }
}

private struct WavyLine: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); var x = r.minX; var up = true
        p.move(to: CGPoint(x: x, y: r.midY))
        while x < r.maxX { let n = min(x + 2.4, r.maxX); p.addQuadCurve(to: CGPoint(x: n, y: r.midY), control: CGPoint(x: (x + n) / 2, y: r.midY + (up ? -2.2 : 2.2))); x = n; up.toggle() }
        return p
    }
}

extension CoachModel {
    var ollamaRunning: Bool { if case .running = ollama { return true }; return false }
}
