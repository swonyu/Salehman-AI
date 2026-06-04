import Foundation

/// Talks to the local Ollama server (http://localhost:11434). Free, local, private.
///   • Vision  → qwen2.5vl  (true image understanding)
///   • Coding  → qwen2.5-coder:32b  (strong local code model)
enum OllamaClient {
    static let visionModel = "qwen2.5vl"
    static let codeModel   = "qwen2.5-coder:32b"
    private static let base = "http://localhost:11434"

    // Short reachability/model-list cache. Ollama is local, but the call is hot
    // (vision() and code() check it twice per request); 30s caching is fine and
    // avoids redundant probes when the user sends many messages in a row.
    private actor Reachability {
        static let shared = Reachability()
        private var upUntil: Date = .distantPast
        private var upValue: Bool = false
        private var modelsUntil: Date = .distantPast
        private var modelNames: Set<String> = []
        private let ttl: TimeInterval = 30

        func isUp() async -> Bool {
            if Date() < upUntil { return upValue }
            guard let url = URL(string: "\(base)/api/version") else {
                upValue = false; upUntil = Date().addingTimeInterval(ttl); return false
            }
            var req = URLRequest(url: url); req.timeoutInterval = 2
            let ok: Bool
            if let (_, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200 {
                ok = true
            } else { ok = false }
            upValue = ok; upUntil = Date().addingTimeInterval(ttl)
            return ok
        }

        func hasModel(_ name: String) async -> Bool {
            if Date() >= modelsUntil {
                guard let url = URL(string: "\(base)/api/tags"),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["models"] as? [[String: Any]] else {
                    modelNames = []; modelsUntil = Date().addingTimeInterval(ttl); return false
                }
                let names = models.compactMap { $0["model"] as? String }
                    + models.compactMap { $0["name"] as? String }
                modelNames = Set(names)
                modelsUntil = Date().addingTimeInterval(ttl)
            }
            return modelNames.contains { $0 == name || $0.hasPrefix(name + ":") || $0 == name + ":latest" }
        }

        func invalidate() {
            upUntil = .distantPast; modelsUntil = .distantPast
        }
    }

    /// Is the Ollama server reachable? (Cached for 30s.)
    static func isUp() async -> Bool { await Reachability.shared.isUp() }

    /// Is a given model available locally? (Cached for 30s.)
    static func hasModel(_ name: String) async -> Bool { await Reachability.shared.hasModel(name) }

    /// Core call to /api/generate (non-streaming).
    private static func generate(model: String, prompt: String,
                                 system: String? = nil, images: [Data] = [],
                                 timeout: TimeInterval = 300) async -> String? {
        guard let url = URL(string: "\(base)/api/generate") else { return nil }
        var body: [String: Any] = ["model": model, "prompt": prompt, "stream": false]
        if let system { body["system"] = system }
        if !images.isEmpty { body["images"] = images.map { $0.base64EncodedString() } }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = timeout

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["response"] as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Ask the vision model about an image. Returns nil if unavailable.
    static func vision(imageData: Data, question: String) async -> String? {
        guard await isUp(), await hasModel(visionModel) else { return nil }
        let prompt = question.isEmpty
            ? "Describe this image in detail, including any visible text verbatim."
            : """
              Look at this image and answer the user's question accurately. \
              Include any relevant visible text verbatim.

              Question: \(question)
              """
        return await generate(model: visionModel, prompt: prompt, images: [imageData])
    }

    /// Generate/fix code with the dedicated coding model. Returns nil if unavailable.
    static func code(task: String) async -> String? {
        guard await isUp(), await hasModel(codeModel) else { return nil }
        let system = """
        You are an expert software engineer. Produce correct, complete, idiomatic, \
        modern code. Handle errors and edge cases. Add brief usage notes. Never \
        leave TODO placeholders. Use fenced code blocks with the language tag.
        """
        return await generate(model: codeModel, prompt: task, system: system)
    }

    // MARK: - General chat fallback

    /// General-purpose chat completion via qwen-coder (used as the fallback brain
    /// when Apple Intelligence is off). Returns nil if Ollama or the model isn't
    /// available, so callers can degrade gracefully.
    static func chat(prompt: String, system: String? = nil) async -> String? {
        guard await isUp(), await hasModel(codeModel) else { return nil }
        return await generate(model: codeModel, prompt: prompt, system: system)
    }

    /// Streaming chat via /api/generate with `stream=true`. Calls `onUpdate`
    /// with the cumulative text after each token chunk. Returns the final
    /// text, or nil if the server/model isn't reachable.
    static func chatStream(prompt: String, system: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        guard await isUp(), await hasModel(codeModel) else { return nil }
        guard let url = URL(string: "\(base)/api/generate") else { return nil }
        var body: [String: Any] = ["model": codeModel, "prompt": prompt, "stream": true]
        if let system { body["system"] = system }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = 600

        guard let (bytes, resp) = try? await URLSession.shared.bytes(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        var accumulated = ""
        do {
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if let chunk = json["response"] as? String, !chunk.isEmpty {
                    accumulated += chunk
                    onUpdate(accumulated)
                }
                if (json["done"] as? Bool) == true { break }
            }
        } catch {
            // Network/stream errors fall through with whatever we have so far.
        }
        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
