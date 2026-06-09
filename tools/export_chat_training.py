#!/usr/bin/env python3
"""
tools/export_chat_training.py
------------------------------
Exports the in-app chat history (chat_history.json) as a fine-tuning JSONL
dataset in ChatML format, for Unsloth / mlx_lm.lora / axolotl.

Mirrors Persistence/TrainingExporter.swift exactly — same user/assistant
pairing rule, same length/sentinel filters, same system prompt — so this CLI
and the in-app "Export Training Data (JSONL)" menu item produce identical
output. Useful for re-running the export from a script (e.g. before a
fine-tune) without opening the app.

Usage:
    python3 tools/export_chat_training.py [--out path/to/output.jsonl]
"""

import json
import sys
from pathlib import Path

CHAT_HISTORY = Path.home() / "Library" / "Application Support" / "SalehmanAI" / "chat_history.json"
OUT_FILE = Path(__file__).parent / "salehman_training.jsonl"

for i, a in enumerate(sys.argv):
    if a == "--out" and i + 1 < len(sys.argv):
        OUT_FILE = Path(sys.argv[i + 1])

# Keep in sync with `cloudSystemPromptBase` in LLM/LocalLLM.swift.
SYSTEM_PROMPT = (
    "You are Salehman AI — a fast, precise, deeply capable assistant. "
    "You reason carefully, write excellent code, and always lead with the answer.\n"
    "\n"
    "LANGUAGE (critical): reply in the EXACT language the user wrote in. "
    "English message → English only. Arabic message → Arabic only. "
    "Never switch languages on your own.\n"
    "\n"
    "HOW TO RESPOND:\n"
    "• Lead with the answer. No preamble (\"Great!\", \"Sure!\", \"Of course!\"), "
    "no trailing sign-offs (\"Let me know if...\").\n"
    "• Match length to complexity: a factual question gets one sentence; a hard "
    "problem gets a thorough solution.\n"
    "• Markdown only when it genuinely helps: fenced code for code, bullet lists "
    "for 3+ parallel items. No headers for replies under 5 lines.\n"
    "• When you write code: complete, correct, production-ready. No TODOs, no "
    "placeholders, no simplified examples. Handle edge cases.\n"
    "• When you don't know: say so directly. Never fabricate.\n"
    "\n"
    "MEMORY: When you learn something durable about the user — their name, a "
    "preference, how they like to work, their project context — use the "
    "remember_fact tool to store it. This is how you get better for them over time.\n"
    "\n"
    "TOOLS: In this mode you have no terminal or web access. If a task needs "
    "running a command, suggest the exact command as text."
)


def main() -> None:
    if not CHAT_HISTORY.exists():
        print(f"No chat history found at {CHAT_HISTORY}")
        sys.exit(1)

    messages = json.loads(CHAT_HISTORY.read_text())

    lines: list[str] = []
    skipped = 0
    i = 0
    while i < len(messages) - 1:
        a, b = messages[i], messages[i + 1]
        if not a.get("isUser") or b.get("isUser"):
            i += 1
            continue
        user_text = a.get("text", "").strip()
        assistant_text = b.get("text", "").strip()
        if (len(user_text) < 10 or len(assistant_text) < 10
                or assistant_text.startswith("[")
                or "request failed" in assistant_text):
            skipped += 1
            i += 2
            continue
        example = {
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_text},
                {"role": "assistant", "content": assistant_text},
            ]
        }
        lines.append(json.dumps(example, ensure_ascii=False))
        i += 2

    jsonl = "\n".join(lines)
    OUT_FILE.write_text(jsonl + ("\n" if jsonl else ""), encoding="utf-8")

    print(f"Examples : {len(lines)}")
    print(f"Skipped  : {skipped}")
    print(f"Bytes    : {len(jsonl.encode('utf-8'))}")
    print(f"Written  : {OUT_FILE}")


if __name__ == "__main__":
    main()
