import Foundation
import AppKit

/// Lets the HeyHumanly Chrome extension talk to the local Ollama server.
/// Ollama refuses requests from browser extensions unless OLLAMA_ORIGINS allows them, so this sets that variable
/// for the current session, keeps it across restarts with a small login item, and restarts Ollama once.
enum BrowserAccess {
    static let origins = "chrome-extension://*,http://localhost,http://127.0.0.1"
    private static let label = "com.heyhumanly.ollama-origins"
    private static var plistURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist") }

    /// True when Ollama answers a request that carries a browser-extension Origin.
    static func isAllowed(endpoint: String) async -> Bool {
        guard var comps = URLComponents(string: endpoint) else { return false }
        comps.path = "/api/tags"
        guard let url = comps.url else { return false }
        var req = URLRequest(url: url); req.timeoutInterval = 4
        req.setValue("chrome-extension://heyhumanly-check", forHTTPHeaderField: "Origin")
        guard let (_, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    }

    @discardableResult
    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        do { try p.run(); p.waitUntilExit(); return p.terminationStatus } catch { return -1 }
    }

    /// Returns nil on success, or a short message the user can act on.
    static func enable() async -> String? {
        run("/bin/launchctl", ["setenv", "OLLAMA_ORIGINS", origins])
        // Keep it across restarts: a login item that sets the same variable.
        let plist: [String: Any] = ["Label": label, "RunAtLoad": true,
                                    "ProgramArguments": ["/bin/launchctl", "setenv", "OLLAMA_ORIGINS", origins]]
        do {
            try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch { return "Allowed for now, but couldn't make it permanent: \(error.localizedDescription)" }
        await restartOllama()
        return nil
    }

    static func disable() async {
        run("/bin/launchctl", ["unsetenv", "OLLAMA_ORIGINS"])
        try? FileManager.default.removeItem(at: plistURL)
        await restartOllama()
    }

    /// Quits Ollama (app first, then server) and starts it again with the setting passed explicitly.
    /// Order matters: if the server is stopped while the app is alive, the app respawns it with the old settings.
    private static func restartOllama() async {
        let appURL = URL(fileURLWithPath: "/Applications/Ollama.app")
        guard FileManager.default.fileExists(atPath: appURL.path) else { return }
        func appRunning() -> Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: "com.electron.ollama").isEmpty }
        func serverRunning() -> Bool { run("/usr/bin/pgrep", ["-f", "Resources/ollama serve"]) == 0 }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.electron.ollama") { app.terminate() }
        for _ in 0..<15 where appRunning() { try? await Task.sleep(nanoseconds: 400_000_000) }
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.electron.ollama") { app.forceTerminate() }
        run("/usr/bin/pkill", ["-f", "Resources/ollama serve"])
        for _ in 0..<15 where serverRunning() { try? await Task.sleep(nanoseconds: 400_000_000) }
        run("/usr/bin/open", ["--env", "OLLAMA_ORIGINS=\(origins)", "-g", "-a", "Ollama"])
        for _ in 0..<30 { // wait until the server answers again
            if await reachable() { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private static func reachable() async -> Bool {
        guard let url = URL(string: "http://localhost:11434/api/tags") else { return false }
        var req = URLRequest(url: url); req.timeoutInterval = 2
        return ((try? await URLSession.shared.data(for: req))?.1 as? HTTPURLResponse)?.statusCode == 200
    }
}
