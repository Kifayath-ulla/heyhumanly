import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Where coaching runs. Picked automatically on first launch, changeable in Settings.
enum CoachEngine: String, Codable, CaseIterable, Identifiable {
    case appleOnDevice, online, offlineManaged, ollama
    var id: String { rawValue }
    var label: String {
        switch self {
        case .online: return "Online (Cloudflare)"
        case .appleOnDevice: return "On this Mac (Apple)"
        case .offlineManaged: return "On this Mac (offline)"
        case .ollama: return "On this Mac (Ollama)"
        }
    }
    var isLocal: Bool { self != .online }
}

extension AppSettings {
    static let defaultOnlineEndpoint = "https://heyhumanly.com/api/v1/coach"
    /// nil until chosen (first launch with nothing local available shows the consent card).
    var engine: CoachEngine? { get { engineRaw.flatMap(CoachEngine.init(rawValue:)) } set { engineRaw = newValue?.rawValue } }
    var onlineEndpoint: String {
        get { onlineEndpointRaw.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultOnlineEndpoint }
        set { onlineEndpointRaw = newValue == Self.defaultOnlineEndpoint ? nil : newValue }
    }
    var onlineConsent: Bool { get { onlineConsentRaw ?? false } set { onlineConsentRaw = newValue } }
    var managedModel: String { get { managedModelRaw ?? OfflineRuntime.recommendedModel } set { managedModelRaw = newValue } }
}

// MARK: - Online allowance

struct Allowance: Equatable {
    var limit: Int, remaining: Int, warnAt: Int, resetsAt: Date?
    var resetText: String { resetsAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? "midnight UTC" }
}

enum OnlineError: LocalizedError, Equatable {
    case allowanceUsed, busy, failed, tooLong(Int), network, badRequest
    var errorDescription: String? {
        switch self {
        case .allowanceUsed: return "You've used today's free online coaching. Your text is safe."
        case .busy: return "Online coaching is busy right now. Your text is safe. Try again later, or enable offline coaching."
        case .failed: return "Online coaching is unavailable right now. Your text is safe, and this one didn't count."
        case .tooLong(let n): return "That's longer than online coaching accepts (\(n) characters). Select a shorter part, or use offline coaching."
        case .network: return "Can't reach HeyHumanly's server. Check your connection. Your text is safe, and this one didn't count."
        case .badRequest: return "Online coaching couldn't read that request. Your text is safe."
        }
    }
}

/// Client for POST /api/v1/coach and GET /api/v1/allowance. Sends only text, goal and the install ID.
enum OnlineCoach {
    struct Result { var rewrite: String; var casual: Bool; var allowance: Allowance }

    /// A random UUID created once per install. It isn't tied to the user or the Mac.
    static var installID: String {
        let key = "heyhumanly.installID"
        if let id = UserDefaults.standard.string(forKey: key), UUID(uuidString: id) != nil { return id.lowercased() }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static func goal(_ s: WritingStyle) -> String { s.onlineGoal }

    private static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
    private struct Body: Decodable {
        let rewrite: String?; let casual: Bool?; let limit: Int?; let remaining: Int?; let warnAt: Int?; let resetsAt: String?
        let error: String?; let maxChars: Int?; let available: Bool?
        var allowance: Allowance? {
            guard let remaining else { return nil }
            return Allowance(limit: limit ?? 10, remaining: remaining, warnAt: warnAt ?? 3, resetsAt: OnlineCoach.parseDate(resetsAt))
        }
    }

    static func coach(text: String, goal: String, endpoint: String) async throws -> Result {
        guard let url = URL(string: endpoint) else { throw OnlineError.badRequest }
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text, "goal": goal, "install": installID])
        let data: Data, response: URLResponse
        do { (data, response) = try await send(request) } catch { throw OnlineError.network }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = try? JSONDecoder().decode(Body.self, from: data)
        switch status {
        case 200:
            guard let body, let rewrite = body.rewrite, !rewrite.isEmpty, let a = body.allowance else { throw OnlineError.failed }
            return Result(rewrite: rewrite, casual: body.casual ?? Register.isCasual(text), allowance: a)
        case 429: throw OnlineAllowanceError(allowance: body?.allowance)
        case 413: throw OnlineError.tooLong(body?.maxChars ?? 4000)
        case 400, 415: throw OnlineError.badRequest
        case 503: throw OnlineFailure(error: .busy, allowance: body?.allowance)
        default: throw OnlineFailure(error: .failed, allowance: body?.allowance)
        }
    }

    /// After the app sits idle, the shared session can hand the POST a pooled connection the server already
    /// closed, and it fails with "network connection lost". Each coaching gets its own ephemeral session, so it
    /// always opens a fresh connection. The POST is never retried, so it can never be counted twice.
    private static func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }

    static func allowance(endpoint: String) async -> Allowance? {
        guard var comps = URLComponents(string: endpoint) else { return nil }
        comps.path = comps.path.replacingOccurrences(of: "/coach", with: "/allowance")
        comps.queryItems = [URLQueryItem(name: "install", value: installID)]
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url); request.timeoutInterval = 8
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let body = try? JSONDecoder().decode(Body.self, from: data), body.error == nil else { return nil }
        return body.allowance
    }
}

/// 429: the per-install daily allowance is used up.
struct OnlineAllowanceError: LocalizedError { var allowance: Allowance?; var errorDescription: String? { OnlineError.allowanceUsed.errorDescription } }
/// 5xx: nothing was counted; the server may still report the allowance.
struct OnlineFailure: LocalizedError { var error: OnlineError; var allowance: Allowance?; var errorDescription: String? { error.errorDescription } }

// MARK: - Apple on-device model

/// Apple Foundation Models (macOS 26+, Apple Intelligence on). Uses the same prompts as the Ollama path.
enum AppleModel {
    static let endpoint = "apple://on-device"
    static let modelName = "apple-on-device"
    /// The on-device context is about 4,096 tokens shared by prompt and answer, so long text is refused up front.
    static let maxInputChars = 4000

    /// "available", or why not (deviceNotEligible, appleIntelligenceNotEnabled, modelNotReady, unsupportedOS, notInThisBuild).
    static var availabilityDescription: String {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "available"
            case .unavailable(.deviceNotEligible): return "deviceNotEligible"
            case .unavailable(.appleIntelligenceNotEnabled): return "appleIntelligenceNotEnabled"
            case .unavailable(.modelNotReady): return "modelNotReady"
            case .unavailable(let other): return "unavailable(\(other))"
            }
        }
        return "unsupportedOS"
        #else
        return "notInThisBuild"
        #endif
    }
    static var isAvailable: Bool { availabilityDescription == "available" }
    static var unavailableReason: String {
        switch availabilityDescription {
        case "available": return ""
        case "appleIntelligenceNotEnabled": return "Turn on Apple Intelligence in System Settings to use it."
        case "modelNotReady": return "Apple's model is still downloading. Try again later."
        case "deviceNotEligible": return "This Mac doesn't support Apple Intelligence."
        case "unsupportedOS": return "Needs macOS 26 or later."
        default: return "Not available on this Mac."
        }
    }

    static func respond(prompt: String, maxTokens: Int?, temperature: Double?) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            guard isAvailable else { throw CoachError.appleUnavailable(unavailableReason) }
            let session = LanguageModelSession()
            let options = GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens.map { min($0, 1500) })
            do { return try await session.respond(to: prompt, options: options).content }
            catch let e as LanguageModelSession.GenerationError {
                if case .exceededContextWindowSize = e { throw CoachError.tooLongForApple }
                throw CoachError.server(500, e.localizedDescription)
            }
        }
        #endif
        throw CoachError.appleUnavailable(unavailableReason)
    }
}

/// Routes Ollama-shaped requests: http(s) goes to the server; apple://on-device runs the same prompt on Apple's model
/// and answers in Ollama's {"response": ...} shape so the callers stay the same.
enum LLM {
    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard request.url?.scheme == "apple", let url = request.url else { return try await URLSession.shared.data(for: request) }
        let body = (request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
        guard var prompt = body["prompt"] as? String, !prompt.isEmpty else {
            return (Data(#"{"response":""}"#.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let options = body["options"] as? [String: Any]
        if body["format"] != nil { prompt += "\nReply with only the JSON object, no code fences." }
        var text = try await AppleModel.respond(prompt: prompt, maxTokens: options?["num_predict"] as? Int, temperature: options?["temperature"] as? Double)
        if body["format"] != nil { text = extractJSON(text) }
        let out = try JSONSerialization.data(withJSONObject: ["response": text, "done": true])
        return (out, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    static func isApple(_ endpoint: String) -> Bool { endpoint.hasPrefix("apple:") }

    /// The first {...} block, for models that wrap JSON in prose or fences.
    static func extractJSON(_ s: String) -> String {
        guard let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}"), start < end else { return s }
        return String(s[start...end])
    }
}

enum Register {
    static func isCasual(_ text: String) -> Bool {
        let t = text.lowercased()
        let slang = #"(?<![\w.])(yo|gang|bro|bruh|dude|lol|lmao|haha+|gonna|wanna|gotta|ya|u|ur|idk|tbh|omg|nah|yeah|yep|hey|hmm|bet|fr|rn|btw|sup|what's up|whats up)(?!\w|\.\w)"#
        let hits = (try? NSRegularExpression(pattern: slang))?.numberOfMatches(in: t, range: NSRange(location: 0, length: (t as NSString).length)) ?? 0
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let startsLower = trimmed.first.map { $0.isLowercase } ?? false
        let emoji = text.unicodeScalars.contains { $0.properties.isEmojiPresentation }
        // One signal (a "hey", an emoji, a lowercase start) is enough for a short message; longer text needs two.
        let signals = hits + (startsLower ? 1 : 0) + (emoji ? 1 : 0)
        let wordCount = text.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.count
        return signals >= (wordCount <= 15 ? 1 : 2)
    }
}

