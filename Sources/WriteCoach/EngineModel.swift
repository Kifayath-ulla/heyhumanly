import AppKit
import SwiftUI

/// Which engine coaches, and the online allowance / offline runtime state around it.
extension CoachModel {
    var engine: CoachEngine? { settings.engine }

    /// Ollama-style endpoint for the local engines. Online mode never goes through these paths.
    var activeEndpoint: String {
        switch settings.engine {
        case .appleOnDevice: return AppleModel.endpoint
        case .offlineManaged: return OfflineRuntime.generateURL
        case .online: return ""
        case .ollama, nil: return settings.endpoint
        }
    }
    var activeModel: String {
        switch settings.engine {
        case .appleOnDevice: return AppleModel.modelName
        case .offlineManaged: return settings.managedModel
        case .online: return "online"
        case .ollama, nil: return settings.model
        }
    }

    /// True only when text is checked on this Mac. Background checks (Watcher, inline) require it.
    var engineIsLocal: Bool {
        switch settings.engine {
        case .appleOnDevice, .offlineManaged: return true
        case .ollama: return CompanionService.isLocal(settings.endpoint)
        case .online, nil: return false
        }
    }
    var isOnline: Bool { settings.engine == .online }

    var engineLabel: String { settings.engine?.label ?? "Not set up yet" }

    var engineReady: Bool {
        switch settings.engine {
        case .appleOnDevice: return appleAvailability == "available"
        case .online: return settings.onlineConsent
        case .offlineManaged: return runtime.serverRunning
        case .ollama: return ollamaRunning && modelInstalled
        case nil: return false
        }
    }

    var engineSummary: String {
        switch settings.engine {
        case .appleOnDevice: return appleAvailability == "available" ? "On this Mac (Apple)" : "Apple model unavailable"
        case .online:
            guard settings.onlineConsent else { return "Online (Cloudflare) · needs your OK" }
            return allowance.map { "Online (Cloudflare) · \($0.remaining) of \($0.limit) left" } ?? "Online (Cloudflare)"
        case .offlineManaged: return runtime.serverRunning ? "On this Mac (offline) · \(settings.managedModel)" : "Offline coaching is starting…"
        case .ollama: return "On this Mac (Ollama) · " + ollama.summary(model: settings.model)
        case nil: return "Choose how to coach"
        }
    }
    var engineColor: Color {
        if engineReady { return isOnline && (allowance?.remaining ?? 1) == 0 ? .orange : .added }
        return settings.engine == .ollama ? ollama.color(model: settings.model) : .orange
    }

    /// Ollama models that can write (embedding models can't).
    var writingModels: [String] { installedModels.filter { !$0.localizedCaseInsensitiveContains("embed") } }
    var ollamaDetected: Bool { ollamaRunning && !writingModels.isEmpty }

    /// First launch: Apple's model if it's ready, else the user's Ollama with a writing model, else nothing
    /// (the coach window asks before anything goes online). Upgrades keep the Ollama path they had.
    func autoPickEngine() async {
        guard settings.engine == nil else { return }
        if settings.onboarded == true { setEngine(.ollama); return }
        if AppleModel.isAvailable { setEngine(.appleOnDevice); return }
        if case .running(let models) = await OllamaStatus.check(endpoint: settings.endpoint),
           let pick = models.contains(settings.model) ? settings.model : models.first(where: { !$0.localizedCaseInsensitiveContains("embed") }) {
            settings.model = pick; settingsModel = pick
            setEngine(.ollama)
        }
    }

    func setEngine(_ e: CoachEngine) {
        settings.engine = e; settings.save()
        showConsent = false; onlineLimitHit = false; onlineFailed = false
        if e != .offlineManaged { runtime.stopServer() }
        switch e {
        case .offlineManaged: Task { await runtime.startServer() }
        case .online: refreshAllowance()
        default: break
        }
        refreshStatus()
    }

    func useMyOllama() {
        if !installedModels.contains(settings.model), let first = writingModels.first { settings.model = first; settingsModel = first }
        setEngine(.ollama)
        statusMessage = "Connected to your Ollama (\(settings.model)). Your writing stays on this Mac."
    }

    func consentToOnline() {
        settings.onlineConsent = true
        setEngine(.online)
    }

    func revokeOnlineConsent() {
        settings.onlineConsent = false
        if settings.engine == .online { settings.engine = nil }
        settings.save(); allowance = nil
        refreshStatus()
    }

    /// Shows the consent card or a clear reason instead of coaching when the engine can't run yet.
    func readyToCoach() -> Bool {
        switch settings.engine {
        case nil: showConsent = true; return false
        case .online where !settings.onlineConsent: showConsent = true; return false
        case .appleOnDevice where !AppleModel.isAvailable:
            errorMessage = CoachError.appleUnavailable(AppleModel.unavailableReason).localizedDescription; return false
        default: return true
        }
    }

    func refreshAllowance() {
        guard settings.engine == .online, settings.onlineConsent else { return }
        let endpoint = settings.onlineEndpoint
        Task { if let a = await OnlineCoach.allowance(endpoint: endpoint) { allowance = a } }
    }

    /// One explicit online coaching. Only text, goal and the install ID are sent.
    func coachOnline(text: String, goal: RephraseGoal) async throws -> OnlineCoach.Result {
        onlineLimitHit = false; onlineFailed = false
        do {
            let r = try await OnlineCoach.coach(text: text, goal: goal, endpoint: settings.onlineEndpoint)
            allowance = r.allowance
            return r
        } catch let e as OnlineAllowanceError {
            onlineLimitHit = true
            if let a = e.allowance { allowance = a } else { allowance?.remaining = 0 }
            throw e
        } catch let e as OnlineFailure {
            onlineFailed = true
            if let a = e.allowance { allowance = a }
            throw e
        } catch let e as OnlineError {
            if [.network, .busy, .failed].contains(e) { onlineFailed = true }
            throw e
        }
    }

    func waitForReset() {
        onlineLimitHit = false
        statusMessage = "Your text is saved here. Free online coaching resets at \(allowance?.resetText ?? "midnight UTC")."
    }

    func openOfflineSetup() {
        showConsent = false
        showOfflineSetup = true
        runtime.prepare()
    }

    func startOfflineSetup(_ plan: OfflineRuntime.Plan) {
        runtime.start(plan: plan) { [weak self] modelName in
            guard let self else { return }
            self.settings.managedModel = modelName
            self.setEngine(.offlineManaged)
            self.onlineLimitHit = false; self.onlineFailed = false; self.errorMessage = nil
            self.statusMessage = "Offline coaching is on. Your writing stays on this Mac."
        }
    }

    /// Teach Me in online mode: the lesson comes from the local rule book, not another online call.
    func localLesson(itemID: UUID, rewrite: String) {
        let tip = InlineSession.lessonTip(for: changeSet.changes)
        let updated = CoachResult(rewrite: rewrite, explanation: tip, exercise: "")
        if currentItem?.id == itemID { result = updated }
        if let index = history.firstIndex(where: { $0.id == itemID }) {
            let item = HistoryItem(copying: history[index], result: updated)
            history[index] = item
            if currentItem?.id == itemID { currentItem = item }
            HistoryItem.saveAll(history)
        }
    }

    /// Engine started on launch (offline runtime) and terminated on quit.
    func startEngineOnLaunch() {
        if settings.engine == .offlineManaged { Task { await runtime.startServer(); refreshStatus() } }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { OfflineRuntime.shared.stopServer() }
        }
    }
}
