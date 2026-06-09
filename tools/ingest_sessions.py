#!/usr/bin/env python3
"""
tools/ingest_sessions.py
------------------------
Feeds the owner's Claude Code session history into Salehman AI's on-device
Knowledge Base and Memory store.

Step 1 — Knowledge Base: reads every Claude JSONL session, extracts substantive
assistant responses (ignoring tool calls / short acks), groups them by topic,
and appends topic-organised documents to knowledge.json.

Step 2 — Memory: writes curated durable facts about the owner (name, location,
project, preferences, tech stack) straight into memory.json.

Run WHILE THE APP IS CLOSED (the stores are persisted JSON; running while the
app is open risks a simultaneous write conflict).

Usage:
    python3 tools/ingest_sessions.py [--dry-run]
"""

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DRY_RUN = "--dry-run" in sys.argv

APP_DATA = Path.home() / "Library" / "Application Support" / "SalehmanAI"
SESSIONS_DIR = Path.home() / ".claude" / "projects" / "-Users-saleh-Desktop-Salehman-AI"
KNOWLEDGE_FILE = APP_DATA / "knowledge.json"
MEMORY_FILE = APP_DATA / "memory.json"

NOW_ISO = datetime.now(timezone.utc).isoformat()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text())
    except Exception:
        return default

def save_json(path: Path, data: Any) -> None:
    if DRY_RUN:
        print(f"[dry-run] would write {path}")
        return
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2))
    print(f"Saved {path}")

def extract_text_blocks(session_path: Path) -> list[str]:
    """Return every substantive assistant text block from a JSONL session file."""
    blocks: list[str] = []
    try:
        with session_path.open(encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                if obj.get("type") != "assistant":
                    continue
                message = obj.get("message", {})
                for block in message.get("content", []):
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") != "text":
                        continue
                    text = block.get("text", "").strip()
                    # Skip very short responses and known non-content strings
                    if len(text) < 80:
                        continue
                    skip_prefixes = (
                        "You've hit your session limit",
                        "No response requested",
                        "[",
                    )
                    if any(text.startswith(p) for p in skip_prefixes):
                        continue
                    blocks.append(text)
    except Exception as e:
        print(f"  warning: could not read {session_path.name}: {e}")
    return blocks

def classify_topic(text: str) -> str:
    """Simple heuristic topic classifier for grouping knowledge chunks."""
    lower = text.lower()
    if any(k in lower for k in ["swift 6", "sendable", "nonisolated", "actor", "mainthreadchecker", "concurrency", "@sendable", "isolated deinit"]):
        return "Swift 6 Concurrency"
    if any(k in lower for k in ["agentpipeline", "orchestrator", "agentspec", "agentregistry", "missionprogress", "agentdefinition"]):
        return "Agent Pipeline Architecture"
    if any(k in lower for k in ["salehmanengine", "salehmanleader", "salehmانpersona", "cloudchain", "trycloud", "deepseek", "nvidia", "groq", "cerebras", "mistral", "openrouter"]):
        return "Brain / LLM Engine"
    if any(k in lower for k in ["codeview", "codesyntax", "filetree", "filenode", "codetextview", "syntaxhighlight", "find-in-file", "file viewer"]):
        return "Code Tab"
    if any(k in lower for k in ["knowledgestore", "knowledgedoc", "knowledgehit", "knowledge tab", "knowledge base", "rag", "embedding", "mmr"]):
        return "Knowledge Tab"
    if any(k in lower for k in ["contentview", "chatviewmodel", "chatmessage", "settingsview", "brainpreference", "appstate", "appsettings"]):
        return "Chat UI / Settings"
    if any(k in lower for k in ["jsonfilestore", "memorystore", "scratchpadstore", "persistence", "codable"]):
        return "Persistence Layer"
    if any(k in lower for k in ["toolpolicy", "commandapproval", "shelltool", "shell.run", "run_terminal_command"]):
        return "Tool Policy / Shell"
    if any(k in lower for k in ["livetranscriber", "speechin", "mediarecorder", "microphone", "transcri"]):
        return "Media / Transcription"
    if any(k in lower for k in ["grok_terminal_bridge", "grok.com", "grok web", "cloudflare"]):
        return "Grok Terminal Bridge"
    if any(k in lower for k in ["development_log", "source_bundle", "claude.md", "project_context"]):
        return "Project Documentation"
    return "General"

# ---------------------------------------------------------------------------
# Step 1 — Knowledge Base
# ---------------------------------------------------------------------------

def build_knowledge_docs(session_files: list[Path]) -> list[dict]:
    """Extract + classify assistant blocks from all sessions into topic groups."""
    topic_chunks: dict[str, list[str]] = {}
    total_blocks = 0

    for sf in session_files:
        blocks = extract_text_blocks(sf)
        total_blocks += len(blocks)
        for block in blocks:
            topic = classify_topic(block)
            topic_chunks.setdefault(topic, []).append(block)

    print(f"Extracted {total_blocks} blocks from {len(session_files)} sessions → {len(topic_chunks)} topics")

    # Build one KnowledgeDoc per topic
    docs: list[dict] = []
    chunks: list[dict] = []

    for topic, texts in sorted(topic_chunks.items()):
        doc_id = str(uuid.uuid4())
        # Deduplicate very similar blocks (exact-prefix dedup)
        seen: set[str] = set()
        unique: list[str] = []
        for t in texts:
            key = t[:120]
            if key not in seen:
                seen.add(key)
                unique.append(t)

        print(f"  {topic}: {len(unique)} unique blocks")
        docs.append({
            "id": doc_id,
            "name": f"Claude Sessions — {topic}",
            "kind": "session history",
            "icon": "bubble.left.and.bubble.right.fill",
            "chunkCount": len(unique),
            "addedAt": NOW_ISO,
        })
        for i, text in enumerate(unique):
            chunks.append({
                "docID": doc_id,
                "docName": f"Claude Sessions — {topic}",
                "ordinal": i,
                "text": text,
                # vector omitted (null) — keyword fallback applies until app re-indexes
            })

    return docs, chunks

def ingest_knowledge(session_files: list[Path]) -> None:
    print("\n── Step 1: Knowledge Base ──")
    existing = load_json(KNOWLEDGE_FILE, {"docs": [], "chunks": []})
    existing_docs: list[dict] = existing.get("docs", [])
    existing_chunks: list[dict] = existing.get("chunks", [])

    # Remove any previously-ingested Claude-session docs so we don't duplicate
    prev_ids = {d["id"] for d in existing_docs if "Claude Sessions" in d.get("name", "")}
    existing_docs = [d for d in existing_docs if d["id"] not in prev_ids]
    existing_chunks = [c for c in existing_chunks if c.get("docID") not in prev_ids]
    if prev_ids:
        print(f"  Removed {len(prev_ids)} previously-ingested session doc(s) (refresh)")

    new_docs, new_chunks = build_knowledge_docs(session_files)
    merged = {
        "docs": existing_docs + new_docs,
        "chunks": existing_chunks + new_chunks,
    }
    print(f"  Total after merge: {len(merged['docs'])} docs, {len(merged['chunks'])} chunks")
    save_json(KNOWLEDGE_FILE, merged)

# ---------------------------------------------------------------------------
# Step 2 — Memory
# ---------------------------------------------------------------------------

CURATED_FACTS = [
    # Identity
    "User's name is Saleh. Located in Riyadh, Saudi Arabia.",
    "Saleh is the sole owner and user of this Mac and the Salehman AI app.",
    "Saleh communicates in both English and Arabic. Reply in the same language as his message.",

    # Project
    "The main project is 'Salehman AI' — a native macOS SwiftUI AI assistant app Saleh built himself.",
    "Salehman AI is written in Swift 6 with -default-isolation=MainActor, targeting macOS 26.5.",
    "The app is stored at ~/Desktop/Salehman AI and is a git repo pushed to github.com/swonyu/Salehman-AI.",
    "Salehman AI has multiple cloud-first AI brains: Salehman (primary), Free·Auto, FreeCoding, Cloud Coding, ensemble, plus individual pinned brains.",
    "The Salehman brain is cloud-first: NVIDIA DeepSeek V4 free → free frontier/120B tiers → paid backstop → local MLX/Ollama floor.",
    "The app uses SalehmanPersona as the system prompt for all brain calls so the identity is always 'Salehman AI'.",
    "Two Claude Code sessions worked this repo in parallel: Chat B (brain/UI) and Chat A (agents/markets).",

    # Tech stack
    "Saleh uses Xcode on macOS for development. Build command: xcodebuild -scheme 'Salehman AI' -destination 'platform=macOS'.",
    "The app uses Swift 6 language mode with nonisolated, @Sendable, isolated deinit, and @unchecked Sendable patterns.",
    "The app's agent pipeline: Orchestrator → AgentPipeline.run → LocalLLM.generate/chat → SalehmanEngine cloud chain.",
    "The Code tab has a collapsible FileTree, syntax-highlighted CodeTextView, find-in-file, diff-to-jump, file icons, and right-click context menus.",
    "The Knowledge tab uses NLEmbedding + MMR search over on-device text documents (KnowledgeStore).",

    # Preferences
    "Saleh prefers free cloud APIs: NVIDIA NIM (free DeepSeek V4), Groq, Cerebras, OpenRouter :free models.",
    "Saleh prefers direct, concise answers without preamble, filler, or moralizing.",
    "Saleh has Unrestricted Mode and wants maximum helpfulness with no refusals on lawful personal requests.",
    "Development log entries are appended (never removed) to DEVELOPMENT_LOG.md after every code change.",
    "SOURCE_BUNDLE.md must be regenerated via 'bash tools/bundle_source.sh' after any code change.",

    # Security
    "API keys live ONLY in the macOS Keychain (LLM/KeychainStore.swift) — never in source, UserDefaults, or logs.",
    "Saleh's DeepSeek API key was exposed in chat on 2026-06-07 and must be rotated at platform.deepseek.com/api_keys.",
]

def ingest_memory() -> None:
    print("\n── Step 2: Memory ──")
    existing: list[dict] = load_json(MEMORY_FILE, [])
    existing_texts = {item.get("text", "").strip() for item in existing}

    new_items: list[dict] = []
    for fact in CURATED_FACTS:
        f = fact.strip()
        if f and f not in existing_texts:
            new_items.append({"text": f, "vector": None})
            print(f"  + {f[:80]}…" if len(f) > 80 else f"  + {f}")

    if not new_items:
        print("  All facts already present — nothing to add.")
        return

    merged = existing + new_items
    print(f"  Added {len(new_items)} new facts ({len(merged)} total)")
    save_json(MEMORY_FILE, merged)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    print("Salehman AI — Claude session ingestion")
    print(f"Data dir : {APP_DATA}")
    print(f"Sessions : {SESSIONS_DIR}")
    if DRY_RUN:
        print("Mode     : DRY RUN (no files written)\n")
    else:
        print()

    if not APP_DATA.exists():
        print(f"ERROR: App data directory not found: {APP_DATA}")
        print("Launch Salehman AI at least once to create the directory, then re-run.")
        sys.exit(1)

    session_files = sorted(SESSIONS_DIR.glob("*.jsonl"))
    if not session_files:
        print(f"No .jsonl files found in {SESSIONS_DIR}")
        sys.exit(1)

    print(f"Found {len(session_files)} session files\n")

    ingest_knowledge(session_files)
    ingest_memory()

    print("\nDone.")
    if not DRY_RUN:
        print("Restart Salehman AI (or it will pick up the new data on next launch).")

if __name__ == "__main__":
    main()
