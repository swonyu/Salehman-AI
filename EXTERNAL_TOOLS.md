# 🧰 EXTERNAL_TOOLS.md — AI tools & repos in the Salehman AI workflow

Catalog of the external AI repos/tools the owner wanted "added into the AI
workflow" (2026-06-08), what each does, and how it relates to **Salehman AI**.

> These are also seeded into the in-app **Knowledge vault** (see
> `Knowledge/ExternalToolsKnowledge.swift`) so the assistant can answer about them
> via `search_documents`. Keep the two in sync.

---

## 1. Code → context (feed a whole repo to an LLM)

| Tool | Link | What it does | In Salehman AI |
|---|---|---|---|
| **Repomix** | github.com/yamadashy/repomix | Packs an entire repo into ONE dense, AI-friendly text file (tree + file contents). | **Built in** as the `pack_repository` tool + `tools/bundle_source.sh` → `SOURCE_BUNDLE.md`. |
| **Gitingest** | github.com/cyclotruc/gitingest | Turns a public GitHub **URL** into a streamlined text digest. | Compose: `git clone --depth 1 <url> /tmp/repo` (via `run_terminal_command`) then `pack_repository /tmp/repo`. |

The in-app equivalent: ask Salehman to **"pack this repo"** — `pack_repository`
walks a folder (skipping `node_modules`/`.build`/`.git`/etc.), emits a capped
digest, and saves the full pack to a temp file. Implemented in
`Tools/RepoPacker.swift`.

## 2. Local inference & architecture

| Tool | Link | What it does | In Salehman AI |
|---|---|---|---|
| **llama.cpp** | github.com/ggml-org/llama.cpp | Pure C/C++ engine for fast LOCAL LLMs (GGUF, CPU/Metal). | The engine under **Ollama**, which powers Salehman's local brain (qwen2.5-coder, dolphin-mistral). The training kit converts fine-tunes to GGUF via llama.cpp. |
| **nanoGPT** | github.com/karpathy/nanoGPT | Minimal, readable GPT training codebase. | Educational counterpart to `salehman-training/` (MLX on Mac, QLoRA on CUDA). |
| **Ludwig** | github.com/ludwig-ai/ludwig | Declarative low-code framework for custom models. | Option for task-specific fine-tunes without a hand-written training loop. |

## 3. Agent & workflow orchestration

| Tool | Link | What it does | In Salehman AI |
|---|---|---|---|
| **Langflow** | github.com/langflow-ai/langflow | Visual drag-and-drop platform (on LangChain) for agent flows. | A standalone Python studio; conceptually overlaps Salehman's `Agents/AgentPipeline`. Heavy — not embedded in the native app. |
| **RepoAgent** | github.com/OpenBMB/RepoAgent | LLM agent that watches git changes and writes docs. | Mirrors Salehman's self-improve loop + the `DEVELOPMENT_LOG.md` discipline. |
| **claude-autocontinue** | github.com/timothy22000/claude-autocontinue | Browser extension that auto-clicks "Continue". | **Built in** as the **Auto-continue** feature (Settings → Intelligence): auto-sends "continue" when a reply looks unfinished. |

## 4. Curated indexes & hosted prototyping

| Tool | Link | What it does |
|---|---|---|
| **Awesome Generative AI** | github.com/steven2358/awesome-generative-ai | Comprehensive directory of GenAI frameworks/tools/models. |
| **Awesome AI & Data Repos** | (community master list) | GitHub resources by NLP / CV / MLOps / Data Science. |
| **GitHub Models / AI** | github.com/features/ai | Prototype & test major LLMs with your dev credentials; Copilot. |

## 5. Agentic coding IDEs (standalone)

| Tool | Link | What it does | In Salehman AI |
|---|---|---|---|
| **Google Antigravity** | antigravity.google | Google's agent-first coding IDE (Gemini 3): autonomous agents across editor/terminal/browser, "Agent Manager" + verifiable "Artifacts". Free public preview, Mac/Win/Linux. | **Standalone** — not embeddable. Use it for the full-repo review the local `qwen2.5-coder` can't do (its Gemini runs on a separate preview quota, not Salehman's rate-limited API key). _Details as of early 2026 — verify current._ |

---

## How they map to features already in this app
- **Repomix/Gitingest → `pack_repository`** (`Tools/RepoPacker.swift`) + `bundle_source.sh`.
- **claude-autocontinue → Auto-continue** (`AppSettings.autoContinue`, `AgentPipeline.looksIncomplete`, the Chat send loop).
- **llama.cpp → Ollama local brain** + `salehman-training/` GGUF export.
- **Langflow/RepoAgent → `Agents/AgentPipeline`** (multi-agent orchestration) + self-improve loop.

_Last updated: 2026-06-08 (added Google Antigravity)._
