#!/usr/bin/env python3
"""
tools/finetune_export.py
------------------------
Exports Claude session history as xAI fine-tuning JSONL.

Each output line is one training example:
  {"messages": [{"role":"system","content":"..."}, {"role":"user","content":"..."}, {"role":"assistant","content":"..."}]}

Filters applied:
  - Skip pairs where either side is < MIN_CHARS
  - Skip assistant turns dominated by tool results / code blocks (>80% non-prose)
  - Skip user turns that are purely "continue" / "ok" / "yes" / single words
  - Deduplicate by first 120 chars of assistant reply

Usage:
    python3 tools/finetune_export.py [--dry-run]
    python3 tools/finetune_export.py --out path/to/output.jsonl
"""

import json
import re
import sys
from pathlib import Path

# ── Config ───────────────────────────────────────────────────────────────────

SESSIONS_DIR = Path.home() / ".claude" / "projects" / "-Users-saleh-Desktop-Salehman-AI"
OUT_FILE     = Path(__file__).parent / "finetune_export.jsonl"

MIN_USER_CHARS      = 20   # ignore trivial user turns
MIN_ASSISTANT_CHARS = 120  # ignore very short assistant replies
MAX_ASSISTANT_CHARS = 6000 # cap very long replies (truncate, not skip)

DRY_RUN  = "--dry-run" in sys.argv
for i, a in enumerate(sys.argv):
    if a == "--out" and i + 1 < len(sys.argv):
        OUT_FILE = Path(sys.argv[i + 1])

SYSTEM_PROMPT = (
    "You are Salehman AI — a native macOS AI assistant built by Saleh. "
    "You are direct, concise, and technically precise. "
    "You never add filler, preamble, or moralizing. "
    "When asked about code, Swift, or this app, you answer from deep knowledge of the project. "
    "Reply in the same language as the user's message."
)

# Single-word / filler user turns to skip
FILLER_PATTERNS = re.compile(
    r"^(ok|okay|yes|no|sure|thanks|thank you|continue|go on|proceed|"
    r"great|nice|cool|got it|understood|alright|fine|done|yep|nope|"
    r"please|do it|do that|just do it|perfect|sounds good)\.?$",
    re.IGNORECASE,
)

# ── Helpers ───────────────────────────────────────────────────────────────────

def extract_text(content_blocks) -> str:
    """Pull plain text from a content array, joining text blocks."""
    if isinstance(content_blocks, str):
        return content_blocks.strip()
    parts = []
    for block in content_blocks or []:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(block.get("text", "").strip())
    return "\n\n".join(p for p in parts if p)


def is_tool_heavy(text: str) -> bool:
    """Return True if the reply is mostly code/tool output rather than prose."""
    code_chars = sum(len(m.group()) for m in re.finditer(r"```[\s\S]*?```", text))
    return len(text) > 0 and code_chars / len(text) > 0.80


def clean_assistant(text: str) -> str:
    """Truncate very long replies and strip leading/trailing whitespace."""
    text = text.strip()
    if len(text) > MAX_ASSISTANT_CHARS:
        text = text[:MAX_ASSISTANT_CHARS].rstrip() + "\n\n[…]"
    return text


def is_real_user_turn(content_blocks) -> bool:
    """True if this user-type record is an actual human message (not a tool result)."""
    if not isinstance(content_blocks, list):
        return bool(content_blocks)
    return any(isinstance(b, dict) and b.get("type") == "text" for b in content_blocks)


def parse_session(path: Path) -> list[tuple[str, str]]:
    """Return (user_text, assistant_text) pairs from one session file.

    Session format quirks handled:
    - tool_result records have type='user' — skip them (only update pending_user
      when the user record has actual text blocks, not tool_result blocks).
    - thinking blocks have type='assistant' but no text — skip them.
    - Multiple consecutive assistant records for one turn (thinking + text split
      into separate records) — take the text one as the response.
    """
    turns: list[tuple[str, str]] = []
    pending_user: str | None = None

    try:
        with path.open(encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw:
                    continue
                try:
                    obj = json.loads(raw)
                except Exception:
                    continue

                role    = obj.get("type", "")
                msg     = obj.get("message", {})
                content = msg.get("content", [])

                if role in ("human", "user"):
                    if not is_real_user_turn(content):
                        continue  # tool_result or empty — don't overwrite pending_user
                    text = extract_text(content)
                    # Strip system-injected XML-like context blocks
                    text = re.sub(r"<[^>]{1,80}>[\s\S]{0,300}</[^>]{1,80}>", "", text).strip()
                    if text:
                        pending_user = text

                elif role == "assistant" and pending_user is not None:
                    text = extract_text(content)
                    if text:
                        turns.append((pending_user, text))
                        pending_user = None  # consumed — wait for next real user turn

    except Exception as e:
        print(f"  warning: could not read {path.name}: {e}")

    return turns


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    session_files = sorted(SESSIONS_DIR.glob("*.jsonl"))
    if not session_files:
        print(f"No session files found in {SESSIONS_DIR}")
        sys.exit(1)

    print(f"Reading {len(session_files)} session files…")

    all_pairs: list[tuple[str, str]] = []
    for sf in session_files:
        all_pairs.extend(parse_session(sf))

    print(f"Raw pairs extracted : {len(all_pairs)}")

    # ── Filter ────────────────────────────────────────────────────────────────
    seen_assistant: set[str] = set()
    examples: list[dict] = []

    for user, assistant in all_pairs:
        # Skip filler user turns
        if FILLER_PATTERNS.match(user.strip()):
            continue
        if len(user) < MIN_USER_CHARS:
            continue

        # Skip short / tool-heavy assistant replies
        if len(assistant) < MIN_ASSISTANT_CHARS:
            continue
        if is_tool_heavy(assistant):
            continue

        # Deduplicate
        key = assistant[:120]
        if key in seen_assistant:
            continue
        seen_assistant.add(key)

        assistant = clean_assistant(assistant)

        examples.append({
            "messages": [
                {"role": "system",    "content": SYSTEM_PROMPT},
                {"role": "user",      "content": user},
                {"role": "assistant", "content": assistant},
            ]
        })

    print(f"After filtering     : {len(examples)} training examples")

    if DRY_RUN:
        print("[dry-run] No file written.")
        if examples:
            print("\nFirst example preview:")
            ex = examples[0]
            print(f"  user      : {ex['messages'][1]['content'][:120]}")
            print(f"  assistant : {ex['messages'][2]['content'][:120]}")
        return

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with OUT_FILE.open("w", encoding="utf-8") as fh:
        for ex in examples:
            fh.write(json.dumps(ex, ensure_ascii=False) + "\n")

    size_kb = OUT_FILE.stat().st_size // 1024
    print(f"Written to          : {OUT_FILE}  ({size_kb} KB, {len(examples)} lines)")
    print("\nNext step: upload this file to console.x.ai → Fine-tuning → New job")


if __name__ == "__main__":
    main()
