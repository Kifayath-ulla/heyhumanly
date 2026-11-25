import SwiftUI

private func sunken<V: View>(_ v: V) -> some View {
    v.padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
}

private func gb(_ bytes: Int64) -> String { String(format: bytes >= 1_000_000_000 ? "%.1f GB" : "%.0f MB", Double(bytes) / (bytes >= 1_000_000_000 ? 1e9 : 1e6)) }

/// Asked once, before the first online request.
struct OnlineConsentCard: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        sunken(VStack(alignment: .leading, spacing: 10) {
            Label("Try coaching now", systemImage: "sparkles").font(.system(size: 14, weight: .semibold))
            Text("Online coaching sends the text you choose to HeyHumanly's server, where Cloudflare Workers AI rewrites it. HeyHumanly doesn't store or log it. Cloudflare says it doesn't keep or train on it. Prefer it never leaves your Mac? Use offline coaching.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Try online coaching") { model.consentToOnline() }.buttonStyle(PrimaryButtonStyle())
                Button("Set up offline coaching instead") { model.openOfflineSetup() }.buttonStyle(SecondaryButtonStyle())
            }
            if model.ollamaDetected {
                Button("Use my Ollama (found \(model.writingModels.count) model\(model.writingModels.count == 1 ? "" : "s"))") { model.useMyOllama() }
                    .buttonStyle(.link).font(.system(size: 12))
            }
        })
        .accessibilityElement(children: .contain)
    }
}

/// Remaining free uses, the low-allowance warning, and what to do at the limit or when the service fails.
struct OnlineStatusStack: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        if model.isOnline, model.settings.onlineConsent {
            VStack(alignment: .leading, spacing: 8) {
                if let a = model.allowance {
                    Label("\(a.remaining) of \(a.limit) free online coachings left today · resets at \(a.resetText)", systemImage: "cloud")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    if a.remaining <= a.warnAt, a.remaining > 0, !model.onlineLimitHit {
                        sunken(HStack(spacing: 10) {
                            Text("You have a few free online coaching sessions left. Enable offline coaching for unlimited use on this Mac.")
                                .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button("Enable offline coaching") { model.openOfflineSetup() }.buttonStyle(SecondaryButtonStyle())
                        })
                    }
                }
                if model.onlineLimitHit || model.allowance?.remaining == 0 { limitActions }
                else if model.onlineFailed {
                    sunken(HStack(spacing: 10) {
                        Text("Online coaching is busy/unavailable right now. Your text is safe.").font(.system(size: 12))
                        Spacer(minLength: 4)
                        Button("Set up offline coaching") { model.openOfflineSetup() }.buttonStyle(SecondaryButtonStyle())
                    })
                }
            }
        }
    }

    private var limitActions: some View {
        sunken(VStack(alignment: .leading, spacing: 8) {
            Text("You've used today's free online coaching. Your text is still here.").font(.system(size: 12.5, weight: .semibold))
            HStack(spacing: 8) {
                Button("Enable unlimited offline coaching") { model.openOfflineSetup() }.buttonStyle(PrimaryButtonStyle())
                if model.ollamaDetected {
                    Button("Connect an existing local model") { model.useMyOllama() }.buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Use my Ollama…") { model.openSettings(.engine) }.buttonStyle(SecondaryButtonStyle())
                        .help("Settings → Coaching → Advanced")
                }
                Button("Wait for allowance reset") { model.waitForReset() }.buttonStyle(SecondaryButtonStyle())
            }
            Text("Free online coaching resets at \(model.allowance?.resetText ?? "midnight UTC").").font(.system(size: 11.5)).foregroundStyle(.secondary)
        })
    }
}

/// Download, verify and start the offline runtime, then pull the model. Shown in the coach window and Settings.
struct OfflineSetupCard: View {
    @ObservedObject var model: CoachModel
    @ObservedObject var runtime = OfflineRuntime.shared
    var closable = true

    var body: some View {
        sunken(VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Offline coaching", systemImage: "lock.laptopcomputer").font(.system(size: 14, weight: .semibold))
                Spacer()
                if closable, !runtime.isBusy { Button { model.showOfflineSetup = false; runtime.dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Close") }
            }
            content
        })
    }

    @ViewBuilder private var content: some View {
        switch runtime.phase {
        case .idle:
            Text("Unlimited coaching that never leaves your Mac. HeyHumanly downloads a private copy of Ollama and a writing model, then works with Wi-Fi off.")
                .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Check this Mac") { runtime.prepare() }.buttonStyle(PrimaryButtonStyle())
        case .confirm(let plan):
            planRows(plan)
            HStack(spacing: 8) {
                Button("Download \(gb(plan.runtimeBytes + plan.modelBytes)) and set up") { model.startOfflineSetup(plan) }.buttonStyle(PrimaryButtonStyle())
                Button("Not now") { model.showOfflineSetup = false; runtime.dismiss() }.buttonStyle(SecondaryButtonStyle())
            }
        case .noSpace(let plan):
            planRows(plan)
            Text("Not enough free disk space. Offline coaching needs \(gb(plan.needBytes)) free and this Mac has \(gb(plan.freeBytes)). Free up \(gb(plan.needBytes - plan.freeBytes)), then check again.")
                .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Color.removed).fixedSize(horizontal: false, vertical: true)
            Button("Check again") { runtime.retry() }.buttonStyle(SecondaryButtonStyle())
        case .downloading, .paused:
            ProgressView(value: runtime.fraction)
            HStack {
                Text(runtime.phase == .paused ? "Paused · \(runtime.detail)" : runtime.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if runtime.phase == .paused { Button("Resume") { runtime.resume() }.buttonStyle(SecondaryButtonStyle()) }
                else { Button("Pause") { runtime.pause() }.buttonStyle(SecondaryButtonStyle()) }
                Button("Cancel") { runtime.cancel() }.buttonStyle(SecondaryButtonStyle())
            }
        case .verifying, .extracting, .starting, .testing:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(runtime.detail).font(.system(size: 12)).foregroundStyle(.secondary) }
        case .pulling:
            ProgressView(value: runtime.fraction)
            HStack {
                Text(runtime.detail).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { runtime.cancel() }.buttonStyle(SecondaryButtonStyle())
            }
        case .done:
            Label("Offline coaching is on. Your writing stays on this Mac.", systemImage: "checkmark.seal.fill")
                .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color.added)
        case .failed(let message):
            Text(message).font(.system(size: 12.5)).foregroundStyle(Color.removed).fixedSize(horizontal: false, vertical: true)
            Button("Retry") { runtime.retry() }.buttonStyle(PrimaryButtonStyle())
        }
    }

    private func planRows(_ plan: OfflineRuntime.Plan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if plan.runtimeBytes > 0 { row("Offline runtime (Ollama 0.40.17)", gb(plan.runtimeBytes)) }
            row("Writing model \(plan.model) (picked for \(plan.ramGB) GB of RAM)", "~" + gb(plan.modelBytes))
            row("Free disk space needed (includes 1 GB spare)", gb(plan.needBytes))
            row("Free on this Mac", gb(plan.freeBytes))
        }
    }
    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).font(.system(size: 12)); Spacer(); Text(v).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary) }
    }
}

/// The coach window's first-run / engine area: consent, offline setup, allowance.
struct EngineArea: View {
    @ObservedObject var model: CoachModel
    var body: some View {
        if model.showOfflineSetup { OfflineSetupCard(model: model) }
        else if model.showConsent || model.engine == nil || (model.isOnline && !model.settings.onlineConsent) { OnlineConsentCard(model: model) }
        OnlineStatusStack(model: model)
    }
}

/// Settings → Coaching: pick the engine, revoke online consent, Advanced endpoints.
struct EngineSettingsCard: View {
    @ObservedObject var model: CoachModel
    @ObservedObject var runtime = OfflineRuntime.shared
    @State private var onlineEndpoint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Coaching", systemImage: "sparkles").font(.system(size: 14, weight: .semibold))
                Spacer()
                StatusDot(color: model.engineColor)
                Text(model.engineSummary).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                option(.appleOnDevice, detail: model.appleAvailability == "available" ? "Apple Intelligence on this Mac. Never leaves your Mac." : AppleModel.unavailableReason,
                       enabled: model.appleAvailability == "available")
                Divider().overlay(Color.hairline)
                option(.offlineManaged, detail: offlineReady ? "Private Ollama run by HeyHumanly (\(model.settings.managedModel)). Never leaves your Mac." : "Download once, then unlimited and works with Wi-Fi off.",
                       enabled: true)
                Divider().overlay(Color.hairline)
                option(.ollama, detail: model.ollamaDetected ? "Use my Ollama (found \(model.writingModels.count) model\(model.writingModels.count == 1 ? "" : "s")). Never leaves your Mac." : "Ollama isn't running on \(URLComponents(string: model.settings.endpoint)?.port.map(String.init) ?? "11434").",
                       enabled: model.ollamaDetected)
                Divider().overlay(Color.hairline)
                option(.online, detail: "\(model.allowance.map { "\($0.limit)" } ?? "10") free coachings a day. Sends the text you choose to HeyHumanly and Cloudflare Workers AI; not stored or logged.",
                       enabled: true)
            }
            .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.hairline))
            if !offlineReady || runtime.phase != .idle { OfflineSetupCard(model: model, closable: false) }
            if model.settings.onlineConsent {
                HStack {
                    Text("You allowed online coaching.").font(.system(size: 12)).foregroundStyle(.secondary)
                    Button("Turn off online coaching") { model.revokeOnlineConsent() }.buttonStyle(.link).font(.system(size: 12))
                }
            }
            DisclosureGroup("Advanced") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Online endpoint").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    TextField(AppSettings.defaultOnlineEndpoint, text: $onlineEndpoint)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12, design: .monospaced))
                        .onSubmit(saveEndpoint).accessibilityLabel("Online endpoint")
                    Text("Press Return to save. Leave empty for the default. Ollama endpoint and model are in Local AI below. Install ID: \(OnlineCoach.installID.prefix(8))… (random, sent only with online requests).")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .padding(.top, 6)
            }
            .font(.system(size: 12))
        }
        .onAppear { onlineEndpoint = model.settings.onlineEndpoint }
        .card()
    }

    /// Set only when setup finished (runtime + model + test), so an interrupted setup offers to continue instead.
    private var offlineReady: Bool { OfflineRuntime.isInstalled && model.settings.managedModelRaw != nil }

    private func saveEndpoint() {
        var v = onlineEndpoint.trimmingCharacters(in: .whitespaces)
        if v.isEmpty { v = AppSettings.defaultOnlineEndpoint }
        // Plain http only for a stand-in on this Mac; anything remote must be https.
        guard let url = URL(string: v), url.host != nil,
              url.scheme == "https" || (url.scheme == "http" && CompanionService.isLocal(v)) else {
            onlineEndpoint = model.settings.onlineEndpoint; return
        }
        onlineEndpoint = v
        guard v != model.settings.onlineEndpoint else { return }
        model.settings.onlineEndpoint = v; model.settings.save(); model.allowance = nil; model.refreshAllowance()
    }

    private func option(_ e: CoachEngine, detail: String, enabled: Bool) -> some View {
        Button {
            if e == .online && !model.settings.onlineConsent { model.showConsent = true }
            else if e == .offlineManaged && !offlineReady { model.runtime.prepare() }
            else if e == .ollama { model.useMyOllama() }
            else { model.setEngine(e) }
        } label: {
            HStack(alignment: .top) {
                Image(systemName: model.engine == e ? "largecircle.fill.circle" : "circle").foregroundStyle(model.engine == e ? Color.brand : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.label).font(.system(size: 13, weight: .medium))
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!enabled && model.engine != e).opacity(enabled || model.engine == e ? 1 : 0.55)
        .accessibilityLabel("Use \(e.label)")
    }
}
