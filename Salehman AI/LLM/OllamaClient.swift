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

    /// Priority list for picking the active code model: lightest first,
    /// heaviest last. The app uses whichever of these is **actually pulled
    /// on disk**, falling back gracefully. `7b` is the documented sweet-spot
    /// default (and MUST equal `preferredCodeModels[0]` — `codeModel`); `14b`
    /// and `32b` are accepted upgrades for users who already have them or whose
    /// download of `7b` failed (e.g. low disk space). Adding a new variant here
    /// makes it eligible without any other code changes.
    /// (2026-06-06: reverted to 7b-first; commit 8152d68 had put 14b first, which
    /// broke the `codeModel == [0]` invariant locked by `OllamaPriorityResolverTests.swift`
    /// — struct `OllamaPreferredModelsTests`.)
    nonisolated static let preferredCodeModels: [String] = [
        codeModel,           // qwen2.5-coder:7b — sweet-spot default (~4.7 GB), snappy on 16 GB.
        "qwen2.5-coder:14b", // accepted upgrade (~9 GB live) if already pulled.
        heavyCodeModel,      // qwen2.5-coder:32b — heavy (~19 GB), opt-in only.
    ]

    nonisolated private static let base = "http://localhost:11434"

    // Short reachability/model-list cache. Ollama is local, but the call is hot
    // (vision() checks it twice per request); 30s caching is fine and
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

    /// Start `ollama serve` in the background if the server isn't already up.
    /// Safe to call on every launch — exits immediately if Ollama is already
    /// running. The spawned process is detached (no pipes, no waitUntilExit)
    /// so it outlives the app and keeps the server warm between sessions.
    nonisolated static func ensureServing() async {
        guard await !isUp() else { return }
        let candidates = ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama", "/usr/bin/ollama"]
        guard let binary = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binary)
        p.arguments = ["serve"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()   // fire-and-forget; Ollama manages its own lifecycle
    }

    /// Default context window. 2048 tokens is plenty for chat-style turns and
    /// keeps Ollama's KV cache small.
    nonisolated static let defaultNumCtx: Int = 2048

    /// Per-call generation knobs. Defaults are tuned for the 7B sweet-spot
    /// model on a laptop.
    struct Generation: Sendable {
        var keepAlive: String   = "30s"
        var numCtx: Int         = OllamaClient.defaultNumCtx
        var numPredict: Int?    = nil          // cap reply length (unset = model decides)
        nonisolated static let `default`    = Generation()

        /// Knobs tuned to the model being called. The user's OWN Salehman model
        /// (the 14B fine-tune) is ~9 GB — evicting it after 30 s means every
        /// exchange after a pause re-pays a multi-second load, so it stays warm
        /// 5 min and gets the 4096 context its Modelfile is built for. Other
        /// (smaller) models keep the RAM-lean 30 s / 2048 defaults.
        /// Matches the configured name OR any "salehman*" variant — the model
        /// ships as `salehman14b` with a `salehman` alias, and a caller passing
        /// the raw name must not silently get the small-model knobs (the alias
        /// trap the parallel session flagged in COORDINATION).
        nonisolated static func tuned(for model: String) -> Generation {
            let custom = AppSettings.customModelNameCurrent
            let base = model.components(separatedBy: ":").first ?? model
            return (model == custom || base.lowercased().hasPrefix("salehman"))
                ? Generation(keepAlive: "5m", numCtx: 4096)
                : .default
        }
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
        if let cap = gen.numPredict { options["num_predict"] = cap }
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

    // MARK: - Tool-calling (/api/chat)

    /// A tool call the model requested. `arguments` is stringified per key to
    /// stay `Sendable` (our only tool, run_terminal_command, takes a `command`
    /// string — lossless here).
    struct ToolCall: Sendable {
        let name: String
        let arguments: [String: String]
    }

    /// One `/api/chat` turn WITH tools. Returns the assistant message's text plus
    /// any tool calls it requested (empty array if it answered directly). `nil`
    /// on a transport/non-200 error. Takes the FULL request body pre-serialized
    /// as `Data` (Sendable) — the caller builds the `[[String: Any]]` messages/
    /// tools dicts locally and serializes them, which keeps the non-`Sendable`
    /// dictionaries from crossing the isolation boundary. qwen2.5-coder supports
    /// tool-calling.
    nonisolated static func chatTurn(bodyData: Data,
                                     timeout: TimeInterval = 300) async -> (text: String, toolCalls: [ToolCall])? {
        guard let url = URL(string: "\(base)/api/chat") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        req.timeoutInterval = timeout

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parseChatResponse(json)
    }

    /// Pure parser for an Ollama `/api/chat` response dict. Extracted from
    /// `chatTurn` so the gnarly part — handling Ollama's two `arguments`
    /// shapes (object on recent versions, JSON string on older) — is unit-
    /// testable without an HTTP mock.
    nonisolated static func parseChatResponse(_ json: [String: Any]) -> (text: String, toolCalls: [ToolCall])? {
        guard let msg = json["message"] as? [String: Any] else { return nil }
        let text = (msg["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var calls: [ToolCall] = []
        if let tcs = msg["tool_calls"] as? [[String: Any]] {
            for tc in tcs {
                guard let fn = tc["function"] as? [String: Any],
                      let name = fn["name"] as? String else { continue }
                var args: [String: String] = [:]
                if let dict = fn["arguments"] as? [String: Any] {
                    for (k, v) in dict { args[k] = "\(v)" }
                } else if let str = fn["arguments"] as? String,
                          let d = str.data(using: .utf8),
                          let parsed = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    for (k, v) in parsed { args[k] = "\(v)" }
                }
                calls.append(ToolCall(name: name, arguments: args))
            }
        }
        return (text, calls)
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

    /// Returns the first `preferredCodeModels` entry that is actually pulled
    /// on disk, or `nil` if the user has none of them. Drives the chat /
    /// chatStream / code paths so the app keeps working when the user
    /// doesn't have the sweet-spot 7B variant but DOES have the 14B or 32B
    /// fallback. The probe is cheap — `hasModel` consults the 30s-cached
    /// model list from `Reachability`, so a typical lookup is in-memory.
    nonisolated static func activeCodeModel() async -> String? {
        for name in preferredCodeModels {
            if await hasModel(name) { return name }
        }
        return nil
    }

    /// The model the general CHAT path should use right now. For `.salehman`, PREFER
    /// the user's own pinned model (`customModelName` — e.g. the fine-tuned 32B once
    /// it's served in Ollama as "salehman"); but if that isn't pulled yet, fall back
    /// to the best available local coder so Salehman is **never mute**. (It used to
    /// return nil here — "run my model, nothing else" — which left Salehman silent
    /// whenever the custom model wasn't pulled, e.g. before the 32B is served.)
    nonisolated static func activeChatModel() async -> String? {
        if AppSettings.brainPreferenceCurrent == .salehman {
            let name = AppSettings.customModelNameCurrent
            if !name.isEmpty, await hasModel(name) { return name }   // the user's own model wins when present
        }
        return await activeCodeModel()                                // floor: best local coder (qwen2.5-coder…)
    }

    /// True iff the user's custom `.salehman` model is pulled on this machine.
    nonisolated static func hasCustomModel() async -> Bool {
        let name = AppSettings.customModelNameCurrent
        guard !name.isEmpty else { return false }
        return await hasModel(name)
    }

    // MARK: - General chat fallback

    /// General-purpose chat completion via qwen-coder (used as the fallback brain
    /// when no other brain is set). Returns nil if Ollama or any preferred
    /// coder model isn't available, so callers can degrade gracefully.
    /// Pass `gen` to override the per-model tuned knobs (e.g. a reply-length cap),
    /// or just `maxTokens` to cap reply length while keeping the tuned knobs —
    /// callers with a token budget (agent notes are 110, full replies 700) MUST
    /// cap, or a 14B at ~15 tok/s turns a "terse note" into a minute-long ramble.
    static func chat(prompt: String, system: String? = nil,
                     gen: Generation? = nil, maxTokens: Int? = nil) async -> String? {
        guard await isUp(), let model = await activeChatModel() else { return nil }
        var g = gen ?? .tuned(for: model)
        if let cap = maxTokens { g.numPredict = cap }
        return await generate(model: model, prompt: prompt, system: system, gen: g)
    }

    /// Pre-load the active chat model into RAM (no prompt → Ollama just loads the
    /// weights and honors `keep_alive`). Fire-and-forget from the UI the moment the
    /// user shows intent to type: a ~9 GB 14B takes seconds to load, and warming it
    /// while they compose the message hides that load entirely. Once per launch.
    @MainActor static func warmupChatModel() {
        guard !didWarmup else { return }
        didWarmup = true
        Task.detached(priority: .utility) {
            guard await isUp(), let model = await activeChatModel() else { return }
            guard let url = URL(string: "\(base)/api/generate") else { return }
            let body: [String: Any] = ["model": model, "stream": false,
                                       "keep_alive": Generation.tuned(for: model).keepAlive]
            guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = payload
            req.timeoutInterval = 120
            _ = try? await URLSession.shared.data(for: req)
        }
    }
    @MainActor private static var didWarmup = false

    // MARK: - Last-generation stats (speed visibility for the local model)

    /// (model, tokens/sec) of the most recent completed local generation, with a
    /// lock so the stream task can write while the UI reads. Display-only.
    nonisolated(unsafe) private static var _lastStats: (model: String, tps: Double)?
    nonisolated private static let statsLock = NSLock()
    nonisolated static func recordStats(model: String, tokensPerSec: Double) {
        statsLock.lock(); _lastStats = (model, tokensPerSec); statsLock.unlock()
    }
    nonisolated static var lastStats: (model: String, tps: Double)? {
        statsLock.lock(); defer { statsLock.unlock() }; return _lastStats
    }

    /// Streaming chat via /api/generate with `stream=true`. Calls `onUpdate`
    /// with the cumulative text after each token chunk. Returns the final
    /// text, or nil if the server/model isn't reachable.
    static func chatStream(prompt: String, system: String? = nil,
                           onUpdate: @escaping (String) -> Void) async -> String? {
        guard await isUp(), let model = await activeChatModel() else { return nil }
        guard let url = URL(string: "\(base)/api/generate") else { return nil }
        // Same per-model tuning as the non-streaming path: the user's own Salehman
        // model stays warm 5 min with its 4096 context; small models stay RAM-lean.
        let gen = Generation.tuned(for: model)
        var options: [String: Any] = ["num_ctx": gen.numCtx]
        if let cap = gen.numPredict { options["num_predict"] = cap }
        var body: [String: Any] = ["model": model, "prompt": prompt, "stream": true,
                                   "keep_alive": gen.keepAlive, "options": options]
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
                if (json["done"] as? Bool) == true {
                    // Final chunk carries generation stats — capture tokens/sec so the
                    // UI can show how fast the local model actually ran.
                    if let count = json["eval_count"] as? Int,
                       let ns = json["eval_duration"] as? Int, ns > 0 {
                        recordStats(model: model, tokensPerSec: Double(count) / (Double(ns) / 1e9))
                    }
                    break
                }
            }
        } catch {
            // Network/stream errors — surface what we accumulated so the UI can decide.
            print("[OllamaClient] chatStream error: \(error)")
        }
        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
