import AppKit
import CryptoKit
import Foundation

/// The in-app offline runtime: a pinned Ollama build downloaded into Application Support,
/// served on a private loopback port, with its own model folder.
@MainActor
final class OfflineRuntime: NSObject, ObservableObject {
    static let shared = OfflineRuntime()

    nonisolated static let runtimeURL = URL(string: "https://github.com/ollama/ollama/releases/download/v0.40.17/ollama-darwin.tgz")!
    nonisolated static let runtimeSHA256 = "4b9db20d077c5a1e52fb4a6f2e6791f76ae945fd07c9b1a5647c82e927826653"
    nonisolated static let runtimeBytes: Int64 = 178_900_000
    nonisolated static let port = 11435
    nonisolated static let baseURL = "http://127.0.0.1:\(port)"
    nonisolated static let generateURL = baseURL + "/api/generate"
    nonisolated static let bigRAM = ProcessInfo.processInfo.physicalMemory >= 12 * 1_073_741_824
    nonisolated static var recommendedModel: String { bigRAM ? "qwen2.5:7b" : "qwen2.5:3b" }
    nonisolated static func modelBytes(_ name: String) -> Int64 { name.contains("7b") ? 4_700_000_000 : 1_900_000_000 }

    nonisolated static var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HeyHumanly", isDirectory: true)
    }
    nonisolated static var runtimeDir: URL { supportDir.appendingPathComponent("Runtime", isDirectory: true) }
    nonisolated static var modelsDir: URL { supportDir.appendingPathComponent("Models", isDirectory: true) }
    nonisolated static var archiveURL: URL { supportDir.appendingPathComponent("ollama-darwin.tgz") }
    nonisolated static var binaryURL: URL { runtimeDir.appendingPathComponent("ollama") }
    nonisolated static var isInstalled: Bool { FileManager.default.isExecutableFile(atPath: binaryURL.path) }

    struct Plan: Equatable { var model: String; var runtimeBytes: Int64; var modelBytes: Int64; var freeBytes: Int64; var needBytes: Int64; var ramGB: Int
        var enoughDisk: Bool { freeBytes >= needBytes } }

    enum Phase: Equatable {
        case idle, confirm(Plan), noSpace(Plan), downloading, paused, verifying, extracting, starting, pulling, testing, done, failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var fraction: Double = 0
    @Published var detail = ""
    @Published var serverRunning = false

    private var session: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var resumeData: Data?
    private var work: Task<Void, Never>?
    private var server: Process?
    private var onDone: ((String) -> Void)?

    var isBusy: Bool { switch phase { case .downloading, .paused, .verifying, .extracting, .starting, .pulling, .testing: return true; default: return false } }

    // MARK: Plan

    /// Free space for important data; HH_DEBUG_FREE_BYTES (env) or heyhumanly.debugFreeBytes (defaults) overrides it for testing.
    static func freeBytes() -> Int64 {
        if let s = ProcessInfo.processInfo.environment["HH_DEBUG_FREE_BYTES"], let v = Int64(s) { return v }
        if let v = UserDefaults.standard.object(forKey: "heyhumanly.debugFreeBytes") as? Int64 { return v }
        let values = try? FileManager.default.homeDirectoryForCurrentUser.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    func makePlan() -> Plan {
        let model = Self.recommendedModel
        let runtime = Self.isInstalled ? 0 : Self.runtimeBytes
        let modelSize = Self.modelBytes(model)
        return Plan(model: model, runtimeBytes: runtime, modelBytes: modelSize, freeBytes: Self.freeBytes(),
                    needBytes: runtime + modelSize + 1_000_000_000, ramGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824))
    }

    /// Step 1: check disk and RAM, then ask before downloading anything.
    func prepare() {
        guard !isBusy else { return }
        let plan = makePlan()
        phase = plan.enoughDisk ? .confirm(plan) : .noSpace(plan)
    }

    func dismiss() { if !isBusy { phase = .idle } }

    // MARK: Install

    /// Step 2: download (resumable), verify, extract, serve, pull the model, test, then call `completion` with the model name.
    func start(plan: Plan, completion: @escaping (String) -> Void) {
        onDone = completion
        fraction = 0; detail = ""
        if Self.isInstalled { work = Task { await self.serveAndPull(model: plan.model) }; return }
        beginDownload()
    }

    private func beginDownload() {
        phase = .downloading; detail = "Starting download…"
        if session == nil { session = URLSession(configuration: .default, delegate: self, delegateQueue: .main) }
        let task = resumeData.map { session!.downloadTask(withResumeData: $0) } ?? session!.downloadTask(with: Self.runtimeURL)
        resumeData = nil
        downloadTask = task
        task.resume()
    }

    func pause() {
        guard phase == .downloading, let task = downloadTask else { return }
        phase = .paused
        task.cancel(byProducingResumeData: { data in Task { @MainActor in self.resumeData = data } })
    }

    func resume() { guard phase == .paused else { return }; beginDownload() }

    func cancel() {
        downloadTask?.cancel(); downloadTask = nil; resumeData = nil
        work?.cancel(); work = nil
        fraction = 0; detail = ""
        phase = .failed("Cancelled. Nothing was changed. You can retry any time.")
    }

    func retry() { phase = .idle; prepare() }

    private func fail(_ message: String) { downloadTask = nil; work = nil; phase = .failed(message) }

    fileprivate func downloaded(to file: URL) {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: Self.supportDir, withIntermediateDirectories: true)
            try? fm.removeItem(at: Self.archiveURL)
            try fm.moveItem(at: file, to: Self.archiveURL)
        } catch { fail("Couldn't save the download: \(error.localizedDescription)"); return }
        downloadTask = nil
        work = Task { await self.verifyAndInstall() }
    }

    private func verifyAndInstall() async {
        phase = .verifying; detail = "Checking the download…"
        let archive = Self.archiveURL
        let hash = await Task.detached { Self.sha256(of: archive) }.value
        guard hash == Self.runtimeSHA256 else {
            try? FileManager.default.removeItem(at: archive)
            fail("The download didn't match the expected checksum, so it was deleted. Retry, or check your connection.")
            return
        }
        phase = .extracting; detail = "Unpacking…"
        let ok = await Task.detached { Self.extract(archive) }.value
        try? FileManager.default.removeItem(at: archive)
        guard ok, Self.isInstalled else { fail("Couldn't unpack the offline runtime. Retry, or check free disk space."); return }
        await serveAndPull(model: makePlan().model)
    }

    nonisolated static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try? handle.read(upToCount: 4 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func extract(_ archive: URL) -> Bool {
        let fm = FileManager.default
        try? fm.removeItem(at: runtimeDir)
        guard (try? fm.createDirectory(at: runtimeDir, withIntermediateDirectories: true)) != nil else { return false }
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", archive.path, "-C", runtimeDir.path]
        guard (try? tar.run()) != nil else { return false }
        tar.waitUntilExit()
        return tar.terminationStatus == 0
    }

    private func serveAndPull(model: String) async {
        phase = .starting; detail = "Starting the offline runtime…"
        guard await startServer() else { fail("The offline runtime didn't start. Retry, or restart HeyHumanly."); return }
        phase = .pulling; fraction = 0; detail = "Downloading \(model)…"
        do {
            try await CoachService.pull(model: model, endpoint: Self.generateURL) { [weak self] f, status in
                guard let self, self.phase == .pulling else { return }
                self.fraction = f
                let size = Double(Self.modelBytes(model)) / 1e9
                self.detail = f > 0 ? String(format: "%@ · %.1f of ~%.1f GB", model, f * size, size) : status.capitalized
            }
        } catch {
            if Task.isCancelled { return }
            fail("Couldn't download \(model): \(error.localizedDescription). Retry to continue where it stopped."); return
        }
        if Task.isCancelled { return }
        phase = .testing; detail = "Checking the connection…"
        do {
            let answer = try await CompanionService.generate(prompt: "Fix the grammar and reply with only the sentence: she go to school.", endpoint: Self.generateURL, model: model, limit: 24)
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CoachError.invalidResponse }
        } catch {
            if Task.isCancelled { return }
            fail("The model downloaded but didn't answer a test: \(error.localizedDescription). Retry."); return
        }
        phase = .done; detail = ""
        onDone?(model); onDone = nil
    }

    // MARK: Server

    /// Launches `ollama serve` on 127.0.0.1:11435 (no OLLAMA_ORIGINS) unless it already answers.
    @discardableResult
    func startServer() async -> Bool {
        if await Self.ping() { serverRunning = true; return true }
        guard Self.isInstalled else { serverRunning = false; return false }
        if server?.isRunning != true {
            try? FileManager.default.createDirectory(at: Self.modelsDir, withIntermediateDirectories: true)
            let p = Process()
            p.executableURL = Self.binaryURL
            p.arguments = ["serve"]
            var env = ProcessInfo.processInfo.environment
            env.removeValue(forKey: "OLLAMA_ORIGINS")
            env["OLLAMA_HOST"] = "127.0.0.1:\(Self.port)"
            env["OLLAMA_MODELS"] = Self.modelsDir.path
            p.environment = env
            p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { serverRunning = false; return false }
            server = p
        }
        for _ in 0..<40 {
            if await Self.ping() { serverRunning = true; return true }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        serverRunning = false
        return false
    }

    func stopServer() {
        if let p = server, p.isRunning { p.terminate(); p.waitUntilExit() }
        server = nil; serverRunning = false
    }

    nonisolated static func ping() async -> Bool {
        var request = URLRequest(url: URL(string: baseURL + "/api/tags")!); request.timeoutInterval = 1.5
        return ((try? await URLSession.shared.data(for: request))?.1 as? HTTPURLResponse)?.statusCode == 200
    }

    nonisolated static func installedModels() async -> [String] {
        var request = URLRequest(url: URL(string: baseURL + "/api/tags")!); request.timeoutInterval = 2
        struct Tags: Decodable { struct M: Decodable { let name: String }; let models: [M] }
        guard let (data, _) = try? await URLSession.shared.data(for: request), let t = try? JSONDecoder().decode(Tags.self, from: data) else { return [] }
        return t.models.map(\.name)
    }
}

extension OfflineRuntime: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten written: Int64, totalBytesExpectedToWrite expected: Int64) {
        MainActor.assumeIsolated {
            guard downloadTask == self.downloadTask else { return }
            let total = expected > 0 ? expected : Self.runtimeBytes
            fraction = min(1, Double(written) / Double(total))
            detail = String(format: "Offline runtime · %.0f of %.0f MB", Double(written) / 1e6, Double(total) / 1e6)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The file is deleted when this returns, so move it first.
        let keep = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tgz")
        let moved = (try? FileManager.default.moveItem(at: location, to: keep)) != nil
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        MainActor.assumeIsolated {
            guard downloadTask == self.downloadTask else { return }
            guard moved, status == 200 else { fail("The download failed (HTTP \(status)). Retry."); return }
            downloaded(to: keep)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let data = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        MainActor.assumeIsolated {
            guard task == self.downloadTask else { return }
            if (error as? URLError)?.code == .cancelled { return }
            resumeData = data
            fail("The download stopped: \(error.localizedDescription). Retry to continue where it left off.")
        }
    }
}
