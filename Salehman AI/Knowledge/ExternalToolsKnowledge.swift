import Foundation

/// One-time seed of "external AI tools" knowledge into the owner's Knowledge vault,
/// so the in-app assistant can answer about them via the `search_documents` tool.
///
/// Uses the real `KnowledgeStore.addDocument` API (correct chunking + on-device
/// embeddings — nothing leaves the Mac), guarded by a UserDefaults flag so it runs
/// exactly once. Fully reversible: the owner can delete any of these in the
/// Knowledge tab. Seeded off the main actor at launch so embedding never hitches UI.
///
/// Source: the repos/tools the owner asked to "add into the AI workflow" (2026-06-08).
/// Keep this in sync with `EXTERNAL_TOOLS.md`.
enum ExternalToolsKnowledge {
    nonisolated static let seededKey = "seededExternalToolsKnowledgeV1"

    /// (name, kind, icon, text) for each seed document.
    nonisolated static let docs: [(name: String, kind: String, icon: String, text: String)] = [
        ("Repomix", "AI tool", "shippingbox", """
        Repomix — github.com/yamadashy/repomix
        Category: code → context (the headline use case).
        Packs an entire code repository into ONE dense, AI-friendly text file (a file
        tree plus every file's contents) so you can feed a whole codebase to an LLM in
        a single prompt. Great for code review, onboarding an AI to a project, or
        Q&A over a repo. In Salehman AI this is mirrored by the built-in
        `pack_repository` tool and by `tools/bundle_source.sh` (which produces
        SOURCE_BUNDLE.md). Use pack_repository to do the same on any local folder.
        """),
        ("Gitingest", "AI tool", "arrow.down.doc", """
        Gitingest — gitingest.com / github.com/cyclotruc/gitingest
        Category: code → context (remote).
        Pulls a PUBLIC GitHub repo straight from its URL and turns it into a streamlined
        text digest ready to paste into an LLM. Like Repomix but URL-driven. In Salehman
        AI, achieve the same by cloning first (run_terminal_command: `git clone --depth 1
        <url> /tmp/repo`) and then calling `pack_repository` on `/tmp/repo`.
        """),
        ("Langflow", "AI framework", "point.3.connected.trianglepath.dotted", """
        Langflow — github.com/langflow-ai/langflow
        Category: agent & workflow orchestration.
        A visual, drag-and-drop low-code platform (built on LangChain) for wiring data
        sources, memory, prompts, and tools into runnable AI agents/flows. It's a large
        Python web app — used as a standalone studio for prototyping agent graphs rather
        than embedded in a native macOS app. Conceptually overlaps with Salehman's own
        AgentPipeline (the multi-agent orchestration already in this app).
        """),
        ("llama.cpp", "local inference", "cpu", """
        llama.cpp — github.com/ggml-org/llama.cpp
        Category: local inference & architecture.
        Pure C/C++ engine for fast LOCAL execution of open-source LLMs (LLaMA, Qwen,
        Mistral, …) with GGUF quantized weights — no Python, runs on CPU/Metal. It's the
        engine under Ollama, which Salehman AI already uses for its local brain
        (qwen2.5-coder, dolphin-mistral). The training kit converts fine-tunes to GGUF
        via llama.cpp for `ollama create`.
        """),
        ("nanoGPT", "training", "brain", """
        nanoGPT — github.com/karpathy/nanoGPT
        Category: local training / architecture.
        Andrej Karpathy's minimal, clean, readable codebase for TRAINING and fine-tuning
        GPT-style models from scratch. Best for learning how transformers train and for
        small custom models. Educational counterpart to Salehman's `salehman-training/`
        kit (which fine-tunes via MLX on Mac and QLoRA on CUDA pods).
        """),
        ("Ludwig", "AI framework", "slider.horizontal.3", """
        Ludwig — github.com/ludwig-ai/ludwig
        Category: low-code model building.
        A declarative, low-code framework for building custom deep-learning / language
        models from a config file instead of boilerplate training code. Good for quickly
        training task-specific models (classification, extraction, fine-tunes) without
        hand-writing the training loop.
        """),
        ("RepoAgent", "AI agent", "doc.text.magnifyingglass", """
        RepoAgent — github.com/OpenBMB/RepoAgent
        Category: agent & workflow / docs automation.
        An LLM agent that hooks into your git workflow, watches structural code changes,
        and autonomously writes/updates documentation. Conceptually similar to Salehman's
        own self-improve loop and the standing DEVELOPMENT_LOG.md discipline — automating
        docs from code changes.
        """),
        ("Awesome Generative AI", "curated index", "list.star", """
        Awesome Generative AI — github.com/steven2358/awesome-generative-ai
        Category: curated collection index.
        A comprehensive, regularly-updated directory of generative-AI frameworks, tools,
        observability systems, models, and services across the ecosystem. Use it as a
        starting map when looking for a tool in a given category. (See also "Awesome AI &
        Data Repos" for a master list organized by NLP / CV / MLOps / Data Science.)
        """),
        ("GitHub Models & AI", "platform", "sparkles", """
        GitHub Models / GitHub AI — github.com/features/ai
        Category: hosted prototyping + dev AI.
        GitHub's AI surface: GitHub Models lets you prototype and test major LLMs with
        your normal developer credentials (no separate hosting), plus Copilot. Useful to
        try a model before wiring it in. Salehman AI already supports many OpenAI-compatible
        and native providers directly (Groq, Cerebras, OpenRouter, DeepSeek, NVIDIA, …).
        """),
        ("claude-autocontinue", "automation", "forward.end.alt", """
        claude-autocontinue — github.com/timothy22000/claude-autocontinue
        Category: automation (for the AI itself).
        A browser extension that auto-clicks "Continue" so a long Claude generation keeps
        going without manual nudging. In Salehman AI this idea is built in as the
        Auto-continue feature: when a reply looks unfinished (hit the tool-call limit, an
        open code block, or "shall I continue?"), the chat automatically sends "continue"
        a few times. Toggle in Settings → Intelligence.
        """),
    ]

    /// Tools added AFTER the original V1 batch. Each is seeded exactly once under its
    /// OWN flag (`seededExtraTool_<name>`), so it never re-seeds the V1 ten and never
    /// resurrects a doc the owner deleted. Add future tools here, not to `docs`.
    nonisolated static let additionalDocs: [(name: String, kind: String, icon: String, text: String)] = [
        ("Google Antigravity", "AI tool", "sparkles", """
        Google Antigravity — antigravity.google (launched Nov 2025, alongside Gemini 3)
        Category: agentic coding IDE / agent orchestration.
        Google's "agent-first" development platform: a VS Code-style editor where you
        direct autonomous AI agents that work across the editor, terminal, and browser,
        coordinated from an "Agent Manager" surface. Agents produce verifiable
        "Artifacts" (plans, task lists, screenshots, browser recordings) and check their
        own work. Powered by Gemini 3 Pro (plus other models), free during public
        preview, on macOS/Windows/Linux. Useful as a STANDALONE tool to review or build
        a whole codebase with a large-context cloud model — the kind of full-repo review
        Salehman's local qwen2.5-coder can't do (4096-token window). Its Gemini access
        runs on a separate preview quota, not the AI Studio API key Salehman uses, so it
        sidesteps that key's rate limits. (Details as of early 2026 — verify current.)
        """),
    ]

    /// Seed once, off the main actor. Sets each flag BEFORE spawning so a double call
    /// can't double-seed. Cheap no-op on every launch after the first.
    nonisolated static func seedIfNeeded() {
        // Never seed under unit tests: the test host launches the app, which would
        // otherwise fire this and mutate the shared KnowledgeStore CONCURRENTLY with
        // KnowledgeRAGTests (a flaky race) — and pollute the real vault from tests.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        // Original V1 batch — seeded once under the single V1 flag.
        if !UserDefaults.standard.bool(forKey: seededKey) {
            UserDefaults.standard.set(true, forKey: seededKey)
            let toSeed = docs
            Task.detached(priority: .utility) {
                for d in toSeed {
                    KnowledgeStore.shared.addDocument(name: d.name, kind: d.kind, icon: d.icon, fullText: d.text)
                }
            }
        }

        // Later additions — each guarded by its own flag so existing users get only
        // the NEW docs (no duplicates of the V1 ten, no resurrecting deletions).
        for d in additionalDocs {
            let flag = "seededExtraTool_" + d.name
            guard !UserDefaults.standard.bool(forKey: flag) else { continue }
            UserDefaults.standard.set(true, forKey: flag)
            let doc = d
            Task.detached(priority: .utility) {
                KnowledgeStore.shared.addDocument(name: doc.name, kind: doc.kind, icon: doc.icon, fullText: doc.text)
            }
        }
    }
}
