#!/usr/bin/env python3
"""
tools/ingest_sessions.py
------------------------
Feeds the owner's Claude Code session history AND Grok terminal-bridge session
logs into Salehman AI's on-device Knowledge Base and Memory store.

Flags:
    --dry-run        Print what would change; write nothing.
    --incremental    Skip files already in ~/.salehman_ingest_manifest.json
    --grok-sessions  Also ingest ~/grok_sessions/*.log files.

Safe to run while the app is open: save_json uses atomic rename.
"""

# Apple's /usr/bin/python3 is 3.9 — defer PEP 604/585 annotations (launchd runs this with it)
from __future__ import annotations

import json
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DRY_RUN       = "--dry-run"       in sys.argv
INCREMENTAL   = "--incremental"   in sys.argv
GROK_SESSIONS = "--grok-sessions" in sys.argv

APP_DATA       = Path.home() / "Library" / "Application Support" / "SalehmanAI"
SESSIONS_DIR   = Path.home() / ".claude" / "projects" / "-Users-saleh-Desktop-Salehman-AI"
GROK_DIR       = Path.home() / "grok_sessions"
KNOWLEDGE_FILE = APP_DATA / "knowledge.json"
MEMORY_FILE    = APP_DATA / "memory.json"
MANIFEST_FILE  = Path.home() / ".salehman_ingest_manifest.json"

# Seconds since Swift reference date (2001-01-01 UTC).
# Swift JSONDecoder default expects Date as Double — NOT ISO string.
_SWIFT_REF = datetime(2001, 1, 1, tzinfo=timezone.utc)
NOW_SECS   = (datetime.now(timezone.utc) - _SWIFT_REF).total_seconds()

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
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)
    print(f"Saved {path}")

def chunk_text(text: str, size: int = 800, overlap: int = 150) -> list[str]:
    clean = text.replace("\r", "\n").strip()
    if len(clean) <= size:
        return [clean] if clean else []
    out: list[str] = []
    chars = list(clean)
    start = 0
    while start < len(chars):
        end = min(start + size, len(chars))
        boundary_found = False
        if end < len(chars):
            b = end
            while b > start and not chars[b - 1].isspace():
                b -= 1
            if b > start + size // 2:
                end = b
                boundary_found = True
        out.append("".join(chars[start:end]).strip())
        if end >= len(chars):
            break
        eff_overlap = overlap if boundary_found else min(overlap, size // 2)
        start = max(end - eff_overlap, start + 1)
    return [c for c in out if c]

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

def load_manifest() -> set[str]:
    if not INCREMENTAL:
        return set()
    return set(load_json(MANIFEST_FILE, []))

def save_manifest(manifest: set[str]) -> None:
    if DRY_RUN:
        return
    MANIFEST_FILE.write_text(json.dumps(sorted(manifest), indent=2), encoding="utf-8")

# ---------------------------------------------------------------------------
# Step 1 — Claude session knowledge
# ---------------------------------------------------------------------------

def extract_text_blocks(session_path: Path) -> list[str]:
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
                for block in obj.get("message", {}).get("content", []):
                    if not isinstance(block, dict) or block.get("type") != "text":
                        continue
                    text = block.get("text", "").strip()
                    if len(text) < 80:
                        continue
                    if any(text.startswith(p) for p in ("You've hit your session limit", "No response requested", "[")):
                        continue
                    blocks.append(text)
    except Exception as e:
        print(f"  warning: could not read {session_path.name}: {e}")
    return blocks

def classify_topic(text: str) -> str:
    lower = text.lower()
    if any(k in lower for k in ["swift 6", "sendable", "nonisolated", "actor", "mainthreadchecker", "concurrency", "@sendable", "isolated deinit"]):
        return "Swift 6 Concurrency"
    if any(k in lower for k in ["agentpipeline", "orchestrator", "agentspec", "agentregistry", "missionprogress", "agentdefinition"]):
        return "Agent Pipeline Architecture"
    if any(k in lower for k in ["salehmanengine", "salehmanleader", "cloudchain", "trycloud", "deepseek", "nvidia", "groq", "cerebras", "mistral", "openrouter"]):
        return "Brain / LLM Engine"
    if any(k in lower for k in ["codeview", "codesyntax", "filetree", "filenode", "codetextview", "syntaxhighlight"]):
        return "Code Tab"
    if any(k in lower for k in ["knowledgestore", "knowledgedoc", "knowledgehit", "knowledge tab", "knowledge base", "rag", "embedding", "mmr"]):
        return "Knowledge Tab"
    if any(k in lower for k in ["contentview", "chatviewmodel", "chatmessage", "settingsview", "appstate", "appsettings"]):
        return "Chat UI / Settings"
    if any(k in lower for k in ["jsonfilestore", "memorystore", "scratchpadstore", "persistence", "codable"]):
        return "Persistence Layer"
    if any(k in lower for k in ["toolpolicy", "commandapproval", "shelltool", "shell.run", "run_terminal_command"]):
        return "Tool Policy / Shell"
    if any(k in lower for k in ["livetranscriber", "speechin", "mediarecorder", "microphone", "transcri"]):
        return "Media / Transcription"
    if any(k in lower for k in ["grok_terminal_bridge", "grok.com", "grok web"]):
        return "Grok Terminal Bridge"
    if any(k in lower for k in ["development_log", "source_bundle", "claude.md", "project_context"]):
        return "Project Documentation"
    return "General"

def build_knowledge_docs(session_files: list[Path]) -> tuple[list[dict], list[dict]]:
    topic_chunks: dict[str, list[str]] = {}
    total_blocks = 0
    for sf in session_files:
        blocks = extract_text_blocks(sf)
        total_blocks += len(blocks)
        for block in blocks:
            topic_chunks.setdefault(classify_topic(block), []).append(block)
    print(f"Extracted {total_blocks} blocks from {len(session_files)} sessions -> {len(topic_chunks)} topics")

    docs: list[dict] = []
    chunks: list[dict] = []
    for topic, texts in sorted(topic_chunks.items()):
        doc_id = str(uuid.uuid4())
        seen: set[str] = set()
        unique: list[str] = []
        for t in texts:
            key = t[:120]
            if key not in seen:
                seen.add(key)
                unique.append(t)
        print(f"  {topic}: {len(unique)} unique blocks")
        name = f"Claude Sessions -- {topic}"
        docs.append({"id": doc_id, "name": name, "kind": "session history",
                      "icon": "bubble.left.and.bubble.right.fill",
                      "chunkCount": len(unique), "addedAt": NOW_SECS})
        for i, text in enumerate(unique):
            chunks.append({"docID": doc_id, "docName": name, "ordinal": i, "text": text})
    return docs, chunks

def ingest_knowledge(session_files: list[Path], manifest: set[str]) -> set[str]:
    print("\n-- Step 1: Claude Session Knowledge --")
    existing        = load_json(KNOWLEDGE_FILE, {"docs": [], "chunks": []})
    existing_docs:   list[dict] = existing.get("docs", [])
    existing_chunks: list[dict] = existing.get("chunks", [])

    prev_ids = {d["id"] for d in existing_docs if "Claude Sessions" in d.get("name", "")}
    existing_docs   = [d for d in existing_docs   if d["id"]        not in prev_ids]
    existing_chunks = [c for c in existing_chunks if c.get("docID") not in prev_ids]
    if prev_ids:
        print(f"  Removed {len(prev_ids)} previously-ingested session doc(s) (refresh)")

    new_docs, new_chunks = build_knowledge_docs(session_files)
    merged = {"docs": existing_docs + new_docs, "chunks": existing_chunks + new_chunks}
    print(f"  Total after merge: {len(merged['docs'])} docs, {len(merged['chunks'])} chunks")
    save_json(KNOWLEDGE_FILE, merged)
    return manifest | {f.name for f in session_files}

# ---------------------------------------------------------------------------
# Step 1b -- Grok session knowledge
# ---------------------------------------------------------------------------

def parse_grok_log(log_path: Path) -> dict | None:
    try:
        content = log_path.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return None

    lines        = content.splitlines()
    task         = ""
    turns:       list[dict] = []
    current_turn = 0
    current_cmd  = ""
    output_buf:  list[str] = []
    collecting   = False
    done         = False

    def flush() -> None:
        nonlocal collecting, current_cmd, output_buf
        if collecting and current_cmd:
            out = "\n".join(output_buf).strip()
            turns.append({"turn": current_turn, "cmd": current_cmd, "output": out[:600]})
        collecting  = False
        current_cmd = ""
        output_buf  = []

    for line in lines:
        if not task and "task: '" in line:
            idx  = line.index("task: '") + len("task: '")
            raw  = line[idx:].rstrip("'")
            task = raw.replace("\\n", " ").replace("\\'", "'")[:300]

        if "-- turn" in line or ("turn" in line and line.count("--") >= 2):
            flush()
            m = re.search(r"turn (\d+)", line)
            if m:
                current_turn = int(m.group(1))
            continue

        if line.startswith("CMD: "):
            flush()
            current_cmd = line[5:]
            collecting  = True
            continue

        if "[[DONE]]" in line or "TASK_COMPLETED_SUCCESSFULLY" in line:
            done = True

        if collecting:
            t = line.strip()
            if not t:
                continue
            is_bridge = (t.startswith("[") or t.startswith("->") or t.startswith("--")
                         or t.startswith("!") or "sending output back" in t)
            if not is_bridge:
                output_buf.append(t)

    flush()
    if not task and not turns:
        return None
    return {"task": task, "turns": turns, "done": done}

def build_grok_docs(log_files: list[Path]) -> tuple[list[dict], list[dict]]:
    docs:   list[dict] = []
    chunks: list[dict] = []
    for log_path in log_files:
        parsed = parse_grok_log(log_path)
        if not parsed or not parsed["turns"]:
            continue
        doc_id     = str(uuid.uuid4())
        status     = "done" if parsed["done"] else "in-progress"
        task_short = (parsed["task"] or log_path.stem)[:80]
        name       = f"Grok Session ({status}) -- {task_short}"

        lines_out = [f"Task: {parsed['task']}", ""]
        for t in parsed["turns"]:
            lines_out.append(f"Turn {t['turn']}: {t['cmd']}")
            if t["output"]:
                lines_out.append(f"Output: {t['output']}")
            lines_out.append("")
        text = "\n".join(lines_out).strip()
        if not text:
            continue

        passages = chunk_text(text)
        docs.append({"id": doc_id, "name": name, "kind": "grok session",
                      "icon": "terminal", "chunkCount": len(passages),
                      "addedAt": NOW_SECS})
        for i, p in enumerate(passages):
            chunks.append({"docID": doc_id, "docName": name, "ordinal": i, "text": p})
        print(f"  {log_path.name}: {len(parsed['turns'])} turns -> {len(passages)} chunks  ({status})")
    return docs, chunks

def ingest_grok_sessions(manifest: set[str]) -> set[str]:
    print("\n-- Step 1b: Grok Session Knowledge --")
    if not GROK_DIR.exists():
        print(f"  {GROK_DIR} not found -- skipping.")
        return manifest

    all_logs = sorted(GROK_DIR.glob("*.log"))
    new_logs = [f for f in all_logs if f.name not in manifest]
    if not new_logs:
        print("  No new Grok session logs.")
        return manifest

    print(f"  {len(new_logs)} new log(s) of {len(all_logs)} total")
    existing        = load_json(KNOWLEDGE_FILE, {"docs": [], "chunks": []})
    existing_docs:   list[dict] = existing.get("docs", [])
    existing_chunks: list[dict] = existing.get("chunks", [])

    new_docs, new_chunks = build_grok_docs(new_logs)
    if not new_docs:
        print("  No usable content extracted.")
        return manifest

    merged = {"docs": existing_docs + new_docs, "chunks": existing_chunks + new_chunks}
    print(f"  Total after merge: {len(merged['docs'])} docs, {len(merged['chunks'])} chunks")
    save_json(KNOWLEDGE_FILE, merged)
    return manifest | {f.name for f in new_logs}

# ---------------------------------------------------------------------------
# Step 2 -- Memory
# ---------------------------------------------------------------------------

CURATED_FACTS = [
    "User's name is Saleh. Located in Riyadh, Saudi Arabia.",
    "Saleh is the sole owner and user of this Mac and the Salehman AI app.",
    "Saleh communicates in both English and Arabic. Reply in the same language as his message.",
    "The main project is 'Salehman AI' -- a native macOS SwiftUI AI assistant app Saleh built himself.",
    "Salehman AI is written in Swift 6 with -default-isolation=MainActor, targeting macOS 26.5.",
    "The app is stored at ~/Desktop/Salehman AI and is a git repo pushed to github.com/swonyu/Salehman-AI.",
    "Salehman AI has multiple cloud-first AI brains: Salehman (primary), Free-Auto, FreeCoding, Cloud Coding, ensemble, plus individual pinned brains.",
    "The Salehman brain is cloud-first: NVIDIA DeepSeek V4 free -> free frontier/120B tiers -> paid backstop -> local MLX/Ollama floor.",
    "The app uses SalehmanPersona as the system prompt for all brain calls so the identity is always 'Salehman AI'.",
    "Two Claude Code sessions worked this repo in parallel: Chat B (brain/UI) and Chat A (agents/markets).",
    "Saleh uses Xcode on macOS for development. Build command: xcodebuild -scheme 'Salehman AI' -destination 'platform=macOS'.",
    "The app uses Swift 6 language mode with nonisolated, @Sendable, isolated deinit, and @unchecked Sendable patterns.",
    "The app's agent pipeline: Orchestrator -> AgentPipeline.run -> LocalLLM.generate/chat -> SalehmanEngine cloud chain.",
    "The Code tab has a collapsible FileTree, syntax-highlighted CodeTextView, find-in-file, diff-to-jump, file icons, and right-click context menus.",
    "The Knowledge tab uses NLEmbedding + MMR search over on-device text documents (KnowledgeStore).",
    "Saleh prefers free cloud APIs: NVIDIA NIM (free DeepSeek V4), Groq, Cerebras, OpenRouter :free models.",
    "Saleh prefers direct, concise answers without preamble, filler, or moralizing.",
    "Saleh has Unrestricted Mode and wants maximum helpfulness with no refusals on lawful personal requests.",
    "Development log entries are appended (never removed) to DEVELOPMENT_LOG.md after every code change.",
    "SOURCE_BUNDLE.md must be regenerated via 'bash tools/bundle_source.sh' after any code change.",
    "API keys live ONLY in the macOS Keychain (LLM/KeychainStore.swift) -- never in source, UserDefaults, or logs.",
    "Saleh's DeepSeek API key was exposed in chat on 2026-06-07 and must be rotated at platform.deepseek.com/api_keys.",
]

def ingest_memory() -> None:
    print("\n-- Step 2: Memory --")
    existing: list[dict] = load_json(MEMORY_FILE, [])
    existing_texts = {item.get("text", "").strip() for item in existing}
    new_items: list[dict] = []
    for fact in CURATED_FACTS:
        f = fact.strip()
        if f and f not in existing_texts:
            new_items.append({"text": f, "vector": None})
            print(f"  + {f[:80]}..." if len(f) > 80 else f"  + {f}")
    if not new_items:
        print("  All facts already present -- nothing to add.")
        return
    merged = existing + new_items
    print(f"  Added {len(new_items)} new facts ({len(merged)} total)")
    save_json(MEMORY_FILE, merged)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    mode = "DRY RUN" if DRY_RUN else ("INCREMENTAL" if INCREMENTAL else "FULL")
    print(f"Salehman AI -- session ingestion  [{mode}]")
    print(f"Data dir : {APP_DATA}")
    print(f"Sessions : {SESSIONS_DIR}")
    if GROK_SESSIONS:
        print(f"Grok logs: {GROK_DIR}")
    print()

    if not APP_DATA.exists():
        print(f"ERROR: App data directory not found: {APP_DATA}")
        print("Launch Salehman AI at least once to create the directory, then re-run.")
        sys.exit(1)

    manifest = load_manifest()

    all_sessions = sorted(SESSIONS_DIR.glob("*.jsonl"))
    if not all_sessions:
        print(f"No .jsonl files found in {SESSIONS_DIR}")
    else:
        to_process = [f for f in all_sessions if f.name not in manifest] if INCREMENTAL else all_sessions
        if INCREMENTAL and len(to_process) < len(all_sessions):
            print(f"Incremental: {len(to_process)} new of {len(all_sessions)} total sessions")
        else:
            print(f"Found {len(to_process)} session file(s)")
        if to_process:
            manifest = ingest_knowledge(to_process, manifest)
        else:
            print("-- Step 1: Claude Session Knowledge -- (nothing new)")

    if GROK_SESSIONS:
        manifest = ingest_grok_sessions(manifest)

    ingest_memory()
    save_manifest(manifest)

    print("\nDone.")

if __name__ == "__main__":
    main()
# [2026-06-10] Incremental manifest + date fix verified and integrated.
