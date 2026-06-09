import Foundation

#if canImport(MLXLLM) && canImport(MLXLMCommon)
import MLX
import MLXLLM
import MLXLMCommon
#endif

/// On-device standalone LLM inference for the Salehman brain — runs a quantized
/// model directly on Apple Silicon via Apple's [MLX-Swift](https://github.com/ml-explore/mlx-swift-examples)
/// framework, with **no Ollama process** and **no Apple Intelligence required**.
/// This is the genuine "Salehman alone" engine.
///
/// ## Setup (one Xcode step, then never again)
/// 1. Open the project in Xcode.
/// 2. File → **Add Package Dependencies…**
/// 3. Paste: `https://github.com/ml-explore/mlx-swift-examples`
/// 4. Add the **MLXLLM** and **MLXLMCommon** library products to the
///    "Salehman AI" target.
/// 5. Build once. Then in Settings → Salehman engine, tap **Download Model**.
///
/// Until the package is added, this actor compiles to a thin stub that always
/// reports `.unavailable` — the rest of the `.salehman` routing (Ollama, then
/// the cloud/Ollama engines) keep working unchanged.
///
/// ## What it does once enabled
/// * Downloads a small open-weight model (default: Llama 3.2 1B Instruct 4-bit,
///   ~800 MB) into `~/Library/Application Support/Salehman/models/`.
/// * Loads it into memory once (memory-mapped from disk; cold-start ~1–2 s).
/// * Generates text on the Neural Engine + GPU — no network, no Ollama, no
///   a small local model — at ~50–80 tokens/sec on M-series Macs.
///
/// ## Why an `actor` and not a `class`
/// MLX inference state (the loaded `ModelContainer`, KV cache, in-flight
/// generation) must be serialized. An `actor` gives that for free under Swift 6
/// strict concurrency, matching `ChatSession`/`FreeAutoCooldown`/`MemoryManager`.
@available(macOS 14.0, *)
actor MLXSalehmanEngine {

    // MARK: - Public state

    static let shared = MLXSalehmanEngine()

    /// Lifecycle state of the standalone engine. Observers (Settings UI,
    /// `BrainStatus`) should treat `.ready` as "we can answer right now."
    enum State: Sendable, Equatable {
        case unavailable(reason: String)
        case downloading(progress: Double)
        case loading
        case ready
    }

    /// Default model — Llama 3.2 1B Instruct, 4-bit quantization (~800 MB on
    /// disk). Smart enough for chat, small enough to download in a few minutes
    /// on most connections. Swap this constant for a Qwen / Phi / Mistral
    /// preset later if a smarter standalone is wanted.
    nonisolated static let defaultModelID = "mlx-community/Llama-3.2-1B-Instruct-4bit"

    /// True iff the engine can answer right now.
    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// Current lifecycle state. Settings observes this to render the status row
    /// (unavailable / downloading-with-%/ loading / ready).
    private(set) var state: State

    // MARK: - Private state (only meaningful when the MLX package is linked)

    #if canImport(MLXLLM) && canImport(MLXLMCommon)
    private var modelContainer: ModelContainer?
    #endif

    init() {
        // The initial reason depends on whether the package is even available.
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        self.state = .unavailable(reason: "Model not downloaded yet — tap Download Model in Settings.")
        #else
        self.state = .unavailable(reason: "MLX-Swift package not added to the Xcode project. See setup steps in MLXSalehmanEngine.swift's header comment.")
        #endif
    }

    // MARK: - Lifecycle

    /// Download the default model (if not on disk) and load it into memory.
    /// Reports progress live via `state`; observers refresh as they poll/react.
    func downloadAndLoad() async {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        // Stay in the .downloading phase until weights are fully on disk.
        state = .downloading(progress: 0)

        // Two ways to source the model, in priority order:
        //   1. A user-picked LOCAL folder containing fine-tuned weights
        //      (safetensors + tokenizer + config.json) — the "your weights"
        //      path that makes Salehman fully your own model. No download.
        //   2. The default HuggingFace MLX model ID (`defaultModelID`).
        // The local-folder branch validates the directory exists first so we
        // surface a clear "folder went missing" state instead of an opaque
        // loader error.
        let customPath = AppSettings.customMLXModelPathCurrent
        let config: ModelConfiguration
        if !customPath.isEmpty {
            let url = URL(fileURLWithPath: customPath, isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue else {
                state = .unavailable(reason: "Your custom MLX model folder doesn't exist: \(customPath). Pick a new folder in Settings, or clear the field to use the default model.")
                return
            }
            config = ModelConfiguration(directory: url)
        } else {
            config = ModelConfiguration(id: Self.defaultModelID)
        }

        do {
            // `loadContainer` downloads weights (or no-ops if cached / loads
            // from local directory) and returns a `ModelContainer` we can
            // `perform` against. The progress closure hops back to this actor
            // to update `state`.
            let container = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { progress in
                Task { await self.setProgress(progress.fractionCompleted) }
            }
            state = .loading
            self.modelContainer = container
            state = .ready
        } catch {
            state = .unavailable(reason: "Couldn't load the model: \(error.localizedDescription)")
        }
        #else
        // Without the MLX package, downloadAndLoad is a no-op that surfaces a
        // clear setup error instead of silently failing.
        state = .unavailable(reason: "Add `mlx-swift-examples` package via Xcode → File → Add Package Dependencies, then try again.")
        #endif
    }

    /// Internal hop for the download progress callback to update state on the
    /// actor without crossing isolation manually.
    private func setProgress(_ fraction: Double) {
        if case .downloading = state {
            state = .downloading(progress: max(0, min(1, fraction)))
        }
    }

    /// Release the loaded model (e.g. on memory pressure). After this the next
    /// `generate` call returns `nil` and the UI should prompt to re-load.
    func unload() {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        modelContainer = nil
        state = .unavailable(reason: "Model unloaded. Tap Download Model to re-load.")
        #endif
    }

    // MARK: - Generation

    /// One-shot generation. Returns `nil` if the engine isn't ready or
    /// generation failed — callers fall through to the next backend in
    /// `LocalLLM`'s `.salehman` chain.
    func generate(prompt: String, maxTokens: Int = 512) async -> String? {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        guard isReady, let container = modelContainer else { return nil }

        // The chat template is applied by the processor when given role-tagged
        // input. We embed the Salehman persona as the system role so the
        // identity + language-mirror rules apply to every generation.
        let userInput = UserInput(messages: [
            ["role": "system", "content": SalehmanPersona.activeSystemPrompt],
            ["role": "user", "content": prompt],
        ])

        return try? await container.perform { context -> String? in
            let lmInput = try await context.processor.prepare(input: userInput)
            let params = GenerateParameters(maxTokens: maxTokens, temperature: 0.7)

            var output = ""
            let stream = try MLXLMCommon.generate(input: lmInput, parameters: params, context: context)
            for await event in stream {
                if case .chunk(let text) = event { output += text }
            }
            return output.isEmpty ? nil : output
        }
        #else
        return nil
        #endif
    }

    /// Streaming generation — calls `onUpdate` with the *cumulative* text after
    /// each new chunk. Returns the final text, or `nil` on failure.
    func generateStream(prompt: String,
                        maxTokens: Int = 512,
                        onUpdate: @escaping @Sendable (String) -> Void) async -> String? {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        guard isReady, let container = modelContainer else { return nil }

        let userInput = UserInput(messages: [
            ["role": "system", "content": SalehmanPersona.activeSystemPrompt],
            ["role": "user", "content": prompt],
        ])

        return try? await container.perform { context -> String? in
            let lmInput = try await context.processor.prepare(input: userInput)
            let params = GenerateParameters(maxTokens: maxTokens, temperature: 0.7)

            var cumulative = ""
            let stream = try MLXLMCommon.generate(input: lmInput, parameters: params, context: context)
            for await event in stream {
                if case .chunk(let text) = event {
                    cumulative += text
                    onUpdate(cumulative)
                }
            }
            return cumulative.isEmpty ? nil : cumulative
        }
        #else
        return nil
        #endif
    }
}

// MARK: - Synchronous availability probe for non-async callers

@available(macOS 14.0, *)
extension MLXSalehmanEngine {

    /// True iff the MLX package is linked at all — i.e. the setup step has
    /// been done. Read by Settings to choose between "Add package" hint and
    /// "Download Model" button.
    nonisolated static var isPackageLinked: Bool {
        #if canImport(MLXLLM) && canImport(MLXLMCommon)
        return true
        #else
        return false
        #endif
    }
}
