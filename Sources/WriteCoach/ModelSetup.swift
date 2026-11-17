import SwiftUI
import AppKit

/// Guided local-model setup: install Ollama (download page), then pull the model with a progress bar from inside the app.
extension CoachModel {
    static let ollamaDownloadURL = URL(string: "https://ollama.com/download/mac")!

    /// Approximate download size shown before the user starts a pull.
    static func approxSize(of model: String) -> String {
        switch model {
        case "qwen2.5:3b": return "about 1.9 GB"
        case "qwen2.5:7b": return "about 4.7 GB"
        default: return "a few GB"
        }
    }

    var ollamaAppInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/Ollama.app")
            || FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Applications/Ollama.app")
    }

    func openOllamaDownload() { NSWorkspace.shared.open(Self.ollamaDownloadURL) }

    func launchOllama() {
        for path in ["/Applications/Ollama.app", NSHomeDirectory() + "/Applications/Ollama.app"] where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path)); break
        }
        // Ollama needs a few seconds to start listening.
        Task { for _ in 0..<8 { try? await Task.sleep(nanoseconds: 1_500_000_000); refreshStatus(); if ollamaRunning { break } } }
    }

    func cancelPull() { pullTask?.cancel(); pullTask = nil; pullFraction = nil; pullDetail = "" }

    /// Streams POST /api/pull. Progress lines look like {"status":"pulling abc","total":N,"completed":M}.
    func pullModel() {
        guard pullFraction == nil, var comps = URLComponents(string: settings.endpoint) else { return }
        comps.path = "/api/pull"; comps.query = nil
        guard let url = comps.url else { return }
        let name = settings.model
        pullError = nil; pullFraction = 0; pullDetail = "Starting…"
        pullTask = Task { [weak self] in
            var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 3600
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": name, "stream": true])
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                struct Line: Decodable { let status: String?; let total: Int64?; let completed: Int64?; let error: String? }
                for try await line in bytes.lines {
                    guard let d = line.data(using: .utf8), let l = try? JSONDecoder().decode(Line.self, from: d) else { continue }
                    if let e = l.error { throw NSError(domain: "pull", code: 1, userInfo: [NSLocalizedDescriptionKey: e]) }
                    await MainActor.run {
                        if let t = l.total, t > 0, let c = l.completed {
                            self?.pullFraction = min(1, Double(c) / Double(t))
                            self?.pullDetail = String(format: "%.1f of %.1f GB", Double(c) / 1e9, Double(t) / 1e9)
                        } else if let s = l.status { self?.pullDetail = s.capitalized }
                    }
                }
                await MainActor.run { self?.pullFraction = nil; self?.pullDetail = ""; self?.refreshStatus() }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    self.pullFraction = nil; self.pullDetail = ""
                    if Task.isCancelled || (error as? URLError)?.code == .cancelled { return }
                    let msg = (error as NSError).localizedDescription
                    self.pullError = "Download stopped: \(msg). Check your connection and free disk space, then try again. Partial downloads resume."
                }
            }
        }
    }
}

/// Setup panel shown in the tour and on Home while Ollama or the model is missing.
struct ModelSetupCard: View {
    @ObservedObject var model: CoachModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.ollamaRunning {
                row(title: "Step 1 · Local AI engine (Ollama)",
                    detail: model.ollamaAppInstalled
                        ? "Ollama is installed but not running."
                        : "HeyHumanly uses Ollama, a free app that runs the model on your Mac. Install it, open it once, then come back here.")
                HStack {
                    if model.ollamaAppInstalled {
                        Button("Start Ollama") { model.launchOllama() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button("Get Ollama") { model.openOllamaDownload() }.buttonStyle(PrimaryButtonStyle())
                        Button("I've installed it") { model.launchOllama() }.buttonStyle(SecondaryButtonStyle())
                    }
                }
            } else if !model.modelInstalled {
                row(title: "Step 2 · Download the writing model",
                    detail: "\(model.settings.model) is \(CoachModel.approxSize(of: model.settings.model)) and needs about that much free disk space and \(model.settings.model.contains("7b") ? "8 GB+" : "4 GB+") of RAM. It downloads once, then works offline. It comes from Ollama's public model library.")
                if let f = model.pullFraction {
                    ProgressView(value: f)
                    HStack {
                        Text(model.pullDetail).font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") { model.cancelPull() }.buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    Button("Download \(model.settings.model)") { model.pullModel() }.buttonStyle(PrimaryButtonStyle())
                }
                if let e = model.pullError {
                    Text(e).font(.system(size: 12)).foregroundStyle(Color.removed).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13.5, weight: .semibold))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
