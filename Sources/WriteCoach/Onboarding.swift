import SwiftUI
import AppKit

/// Three short screens: try the shortcut on a sample, allow Accessibility (or copy instead), pick an engine.
struct OnboardingView: View {
    @ObservedObject var model: CoachModel
    @State private var step = 0
    @State private var picking = false
    @State private var copyInstead = false
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in Capsule().fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.25)).frame(width: 22, height: 4) }
                Spacer()
                Text("\(step + 1) of 3").font(.caption).foregroundStyle(.secondary)
            }
            Group {
                switch step {
                case 0: tryIt
                case 1: permission
                default: engine
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                if step < 2 {
                    Button(step == 1 && !model.accessibilityTrusted && !copyInstead ? "Skip" : "Continue") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") { model.finishOnboarding() }.keyboardShortcut(.defaultAction).disabled(model.engine == nil)
                }
            }
        }
        .padding(.horizontal, 28).padding(.top, 30).padding(.bottom, 22)
        .frame(width: 520, height: 440)
        .background(VisualEffect(material: .windowBackground).ignoresSafeArea())
        .onReceive(poll) { _ in model.accessibilityTrusted = AccessibilityBridge.isTrusted }
    }

    private func title(_ s: String) -> some View { Text(s).font(.system(size: 22, weight: .semibold)) }
    private func detail(_ s: String) -> some View { Text(s).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Select text anywhere and press \(model.shortcutLabel)")
            detail("A small panel shows the rewrite next to your text. Press Enter to use it, Esc to close. Try it here:")
            SampleTextBox(model: model)
                .frame(height: 110)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.3)))
            HStack(spacing: 6) {
                Text("Select the sentence, then press").font(.callout).foregroundStyle(.secondary)
                ShortcutKeys(label: model.shortcutLabel, size: 11)
                Text("or").font(.callout).foregroundStyle(.secondary)
                Button("Try it") { if let tv = model.onboardingSample { model.quick.openSample(model: model, textView: tv) } }
            }
        }
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Replace text in other apps")
            detail("To read your selection and put the rewrite back in Mail, Notes, Slack and other apps, macOS needs you to allow HeyHumanly in Accessibility. It's used only when you press \(model.shortcutLabel).")
            if model.accessibilityTrusted {
                Label("Accessibility is on", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if model.fixingAccess {
                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Waiting for the switch…").foregroundStyle(.secondary) }
                detail(model.fixingAccessHelp).font(.callout)
                HStack(spacing: 12) {
                    OpenAccessibilityLink()
                    Button("Copy instead") { model.stopFixingAccess(); copyInstead = true; model.settings.copyInstead = true; model.settings.save() }.buttonStyle(.link)
                }.font(.callout)
            } else if copyInstead {
                Label("Copy instead: copy text with ⌘C, press \(model.shortcutLabel), and Enter copies the rewrite.", systemImage: "doc.on.clipboard")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Allow Accessibility after all") { copyInstead = false; model.settings.copyInstead = false; model.settings.save(); model.fixAccessibility() }.buttonStyle(.link)
            } else {
                HStack {
                    Button("Allow Accessibility…") { model.fixAccessibility() }.controlSize(.large)
                    Button("Copy instead") { copyInstead = true; model.settings.copyInstead = true; model.settings.save() }.controlSize(.large)
                }
                detail("You can change this any time in Settings.").font(.caption)
            }
        }
    }

    private var engine: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Who does the rewriting")
            if picking {
                ProgressView().controlSize(.small)
            } else if let e = model.engine, e != .online || model.settings.onlineConsent {
                Label(e.label, systemImage: "checkmark.circle.fill").font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                detail(e == .online ? "Only the text you rewrite is sent to HeyHumanly and Cloudflare Workers AI; nothing is stored. 10 free a day."
                       : "Your text never leaves this Mac.")
            } else {
                detail("This Mac has no Apple Intelligence or Ollama, so HeyHumanly can use free online rewrites (10 a day).")
                detail("Only the text you rewrite is sent to HeyHumanly and Cloudflare Workers AI; nothing is stored.")
                HStack {
                    Button("Use free online rewrites") { model.consentToOnline() }.controlSize(.large)
                    Button("Set up offline instead…") { model.chooseEngine(.offlineManaged) }.controlSize(.large)
                }
            }
            Button("Change in Settings…") { model.openSettings(.engine) }.buttonStyle(.link).font(.callout)
        }
        .task {
            guard model.engine == nil else { return }
            picking = true
            await model.autoPickEngine()
            picking = false
        }
    }
}

/// Plain text view owned by HeyHumanly, so ⌃⌥Space works on it before any permission.
private struct SampleTextBox: NSViewRepresentable {
    let model: CoachModel
    static let sample = "Hi team, I has reviewed the proposal and we was hoping to send it tomorow."

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        let tv = scroll.documentView as! NSTextView
        tv.string = Self.sample
        tv.font = .systemFont(ofSize: 14)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.setAccessibilityLabel("Sample text")
        model.onboardingSample = tv
        DispatchQueue.main.async {
            tv.window?.makeFirstResponder(tv)
            tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {}
}

extension CoachModel {
    var ollamaRunning: Bool { if case .running = ollama { return true }; return false }
}
