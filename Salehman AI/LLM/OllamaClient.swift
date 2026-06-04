import Foundation

/// Talks to the local Ollama server (http://localhost:11434). Free, local, private.
///   • Vision  → qwen2.5vl  (true image understanding)
///   • Coding  → qwen2.5-coder:7b (Q4_K_M, ~4.7 GB resident) — the sweet-spot
///     default. The 32B variant (~19 GB resident) can still be picked
///     explicitly via `heavyCodeModel`, but no code path defaults to it.
///
/// Why 7B-by-default: on an 8/16 GB Mac the 32B model alone can exhaust
/// available RAM, especially with macOS + Xcode + Safari already resident. 7B
/// is small enough to stay loaded comfortably while still answering well for
/// chat/code-edit workloads.
enum OllamaClient {
    // `nonisolated` so the policy/cleanup paths (which run off the main actor)
    // can read these without a hop. They're immutable string constants.
    nonisolated static let visionModel     = "qwen2.5vl"
    nonisolated static let codeModel       = "qwen2.5-coder:7b"       // ← sweet-spot default
    nonisolated static let heavyCodeModel  = "qwen2.5-coder:32b"      // opt-in only
    nonisolated private static let base = "http://localhost:11434"

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

    /// Default context window. 2048 tokens is plenty for chat-style turns and
    /// keeps Ollama's KV cache small. `Generation.full` (below) widens it for
    /// tasks that genuinely need long context.
    nonisolated static let defaultNumCtx: Int = 2048

    /// Per-call generation knobs. Defaults are tuned for the 7B sweet-spot
    /// model on a laptop; bump `numCtx` for genuinely long context.
    struct Generation: Sendable {
        var keepAlive: String   = "30s"
        var numCtx: Int         = OllamaClient.defaultNumCtx
        var numGPU: Int?        = nil          // nil = let Ollama decide
        nonisolated static let `default`    = Generation()
        nonisolated static let tight        = Generation(keepAlive: "10s", numCtx: 1024)
        nonisolated static let full         = Generation(keepAlive: "30s", numCtx: 8192)
    }

    /// Core call to /api/generate (non-streaming).
    nonisolated private static func generate(model: String, prompt: String,
                                             system: String? = nil, images: [Data] = [],
                                             timeout: TimeInterval = 300,
                                             gen: Generation = .default) async -> String? {
        guard let url = URL(string: "\(base)/api/generate") else { return nil }
        // `keep_alive` controls how long Ollama keeps the model resident in RAM
        // after the request completes (default in the server is 5 minutes —
        // 30 s on a laptop is the single biggest idle-RAM win). `num_ctx` caps
        // the KV cache size: a smaller context window literally allocates less
        // GPU/CPU RAM per request, so 2048 (default) is dramatically lighter
        // than the server default of 4096.
        var options: [String: Any] = ["num_ctx": gen.numCtx]
        if let n = gen.numGPU { options["num_gpu"] = n }
        var body: [String: Any] = ["model": model, "prompt": prompt, "stream": false,
                                   "keep_alive": gen.keepAlive, "options": options]
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

    // MARK: - Eviction

    /// Immediately evict the loaded model from RAM. Ollama recognizes
    /// `keep_alive: 0` with an empty prompt as "drop right now" — useful when
    /// the OS reports memory pressure or the user backgrounds the app.
    /// Idempotent and silent: failure is fine (we'll just keep the model
    /// loaded a little longer).
    nonisolated static func unloadAll() async {
        for name in [codeModel, heavyCodeModel, visionModel] {
            await unload(model: name)
        }
    }

    /// Evict a specific model. Falls through silently if Ollama isn't reachable.
    nonisolated static func unload(model: String) async {
        guard await isUp(), let url = URL(string: "\(base)/api/generate") else { return }
        let body: [String: Any] = ["model": model, "prompt": "", "keep_alive": 0, "stream": false]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        req.timeoutInterval = 5
        _ = try? await URLSession.shared.data(for: req)
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
        var body: [String: Any] = ["model": codeModel, "prompt": prompt, "stream": true,
                                   "keep_alive": "30s"]   // evict from RAM ~30s after idle
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
