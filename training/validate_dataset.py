#!/usr/bin/env python3
"""
Salehman dataset validator.

Run BEFORE fine-tuning to catch the bugs that silently waste a training run:
JSON shape errors, role typos, empty content, off-format rows, and dataset sizes
that will overfit hard. Use:

    python validate_dataset.py dataset.jsonl
    python validate_dataset.py personas/*.jsonl

Exit code 0 if clean (warnings only), 1 if any hard errors.
"""

from __future__ import annotations
import json
import sys
from collections import Counter
from pathlib import Path

VALID_ROLES = {"system", "user", "assistant"}
MIN_USEFUL_EXAMPLES = 50    # below this, LoRA mostly overfits the few you have
GOOD_DATASET_SIZE   = 300   # rough "this will actually shape behavior" threshold


def validate_file(path: Path) -> tuple[int, int, dict]:
    """Return (errors, warnings, stats) for one JSONL file."""
    errors: list[str] = []
    warnings: list[str] = []
    role_counts: Counter[str] = Counter()
    languages = {"latin": 0, "arabic": 0, "mixed": 0}
    rows = 0
    empty_assistant = 0
    very_short_assistant = 0
    very_long_assistant = 0

    with path.open("r", encoding="utf-8") as f:
        for lineno, raw in enumerate(f, start=1):
            stripped = raw.strip()
            if not stripped:
                continue  # blank line — JSONL allows this, skip silently

            # 1. JSON parses
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as e:
                errors.append(f"{path}:{lineno}: invalid JSON ({e.msg})")
                continue

            # 2. Has the chat-format shape
            if not isinstance(row, dict) or "messages" not in row:
                errors.append(f"{path}:{lineno}: missing top-level \"messages\" key")
                continue
            msgs = row["messages"]
            if not isinstance(msgs, list) or not msgs:
                errors.append(f"{path}:{lineno}: \"messages\" must be a non-empty list")
                continue

            # 3. Each message has the right keys + a recognised role
            has_assistant = False
            for j, m in enumerate(msgs):
                if not isinstance(m, dict):
                    errors.append(f"{path}:{lineno}: messages[{j}] is not an object")
                    continue
                role = m.get("role")
                content = m.get("content")
                if role not in VALID_ROLES:
                    # Common typo: "asistant" / "assitant" — silently ignored by some loaders.
                    errors.append(f"{path}:{lineno}: messages[{j}] has role={role!r} (allowed: {sorted(VALID_ROLES)})")
                    continue
                if content is None or not isinstance(content, str):
                    errors.append(f"{path}:{lineno}: messages[{j}] missing/non-string content")
                    continue
                role_counts[role] += 1
                if role == "assistant":
                    has_assistant = True
                    n = len(content.strip())
                    if n == 0:
                        empty_assistant += 1
                        errors.append(f"{path}:{lineno}: empty assistant content (teaches the model silence)")
                    elif n < 8:
                        very_short_assistant += 1
                    elif n > 4000:
                        very_long_assistant += 1

                # Crude language tag (helps spot accidentally monolingual datasets)
                if any(0x0600 <= ord(c) <= 0x06FF for c in (content or "")):
                    has_arabic = True
                else:
                    has_arabic = False
                has_latin = any("A" <= c <= "z" for c in (content or ""))
                if has_arabic and has_latin:
                    languages["mixed"] += 1
                elif has_arabic:
                    languages["arabic"] += 1
                elif has_latin:
                    languages["latin"] += 1

            if not has_assistant:
                errors.append(f"{path}:{lineno}: no assistant turn in this row (the model has nothing to learn)")
            rows += 1

    # Dataset-level warnings
    if rows < MIN_USEFUL_EXAMPLES:
        warnings.append(
            f"{path}: only {rows} examples — LoRA on this will mostly memorise and overfit. "
            f"Aim for ≥{MIN_USEFUL_EXAMPLES} (≥{GOOD_DATASET_SIZE} is where it starts shaping behaviour)."
        )
    if very_short_assistant:
        warnings.append(f"{path}: {very_short_assistant} assistant replies are <8 chars — likely too terse to learn from")
    if very_long_assistant:
        warnings.append(f"{path}: {very_long_assistant} assistant replies are >4000 chars — they may be truncated by max_seq_length")
    if rows and languages["arabic"] == 0 and languages["mixed"] == 0:
        warnings.append(f"{path}: zero Arabic-containing rows — Salehman won't keep its language-mirror rule for Arabic users")

    stats = {
        "rows": rows, "roles": dict(role_counts),
        "languages": languages,
        "empty_assistant": empty_assistant,
        "very_short_assistant": very_short_assistant,
        "very_long_assistant": very_long_assistant,
    }

    for e in errors:   print(f"❌ {e}")
    for w in warnings: print(f"⚠️  {w}")
    return len(errors), len(warnings), stats


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: validate_dataset.py FILE [FILE...]", file=sys.stderr)
        return 2
    total_err = 0
    total_warn = 0
    total_rows = 0
    for arg in argv:
        path = Path(arg)
        if not path.exists():
            print(f"❌ {path}: no such file")
            total_err += 1
            continue
        e, w, stats = validate_file(path)
        total_err += e
        total_warn += w
        total_rows += stats["rows"]
        print(f"   {path}: {stats['rows']} rows · roles={stats['roles']} · languages={stats['languages']}")
        print()
    print(f"=== TOTAL: {total_rows} rows · {total_err} errors · {total_warn} warnings ===")
    return 1 if total_err else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
