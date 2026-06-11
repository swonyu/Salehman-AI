#!/usr/bin/env python3
"""
Parse a log file using a Grok pattern — STREAMING (constant memory) with
unmatched-line reporting.

Usage:
    python3 grok_parser.py -i access.log -p "%{COMBINEDAPACHELOG}" -o parsed.json
    python3 grok_parser.py -i big.log    -p "%{SYSLOGLINE}"        -o out.jsonl --jsonl

Output:
    Default  : a JSON array, written incrementally (never holds the whole file
               in memory).
    --jsonl  : JSON Lines (one object per line) — best for huge logs and piping
               into jq / other tools.

Unmatched lines are written to "<output>.unmatched" (override with --unmatched)
and summarized at the end, so you can see what your pattern is missing.

Requires:
    pip install pygrok
"""

import argparse
import json
import sys
from pathlib import Path

# pygrok is a third-party dep. Your shell has several python3s (venv / Homebrew /
# system) and which one runs this script varies — so rather than rely on it being
# pre-installed, bootstrap it into THIS interpreter on first run.
try:
    from pygrok import Grok
except ModuleNotFoundError:
    import subprocess
    sys.stderr.write("pygrok not found — installing it into this interpreter...\n")
    for extra in (["--break-system-packages"], ["--user"], []):
        subprocess.run([sys.executable, "-m", "pip", "install", "--quiet", "pygrok", *extra],
                       check=False)
        try:
            from pygrok import Grok
            break
        except ModuleNotFoundError:
            continue
    else:
        sys.stderr.write("Failed to install pygrok. Run manually:\n"
                         f"  {sys.executable} -m pip install pygrok\n")
        sys.exit(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Parse logs with Grok patterns (streaming, with unmatched reporting).")
    parser.add_argument("-i", "--input", required=True, type=Path,
                        help="Path to the input log file")
    parser.add_argument("-p", "--pattern", required=True,
                        help="Grok pattern (e.g. \"%%{COMBINEDAPACHELOG}\")")
    parser.add_argument("-o", "--output", required=True, type=Path,
                        help="Path to write output (JSON array, or JSONL with --jsonl)")
    parser.add_argument("--jsonl", action="store_true",
                        help="Write JSON Lines (one object per line) instead of a JSON array")
    parser.add_argument("--unmatched", type=Path, default=None,
                        help="Where to write non-matching lines (default: <output>.unmatched)")
    parser.add_argument("--flush-every", type=int, default=1000,
                        help="Flush the output file to disk every N matched lines")
    return parser.parse_args()


def load_lines(path: Path):
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            yield line.rstrip("\n")


def main() -> int:
    args = parse_args()

    if not args.input.is_file():
        sys.stderr.write(f"Error: input file '{args.input}' not found.\n")
        return 1

    try:
        grok = Grok(args.pattern)
    except Exception as e:
        sys.stderr.write(f"Error compiling pattern: {e}\n")
        return 1

    unmatched_path = args.unmatched or args.output.with_name(args.output.name + ".unmatched")

    total = matched = unmatched = blank = 0
    samples: list[str] = []

    out_f = args.output.open("w", encoding="utf-8")
    un_f = None  # opened lazily, only if there's something unmatched to write
    try:
        if not args.jsonl:
            out_f.write("[\n")
        first = True

        for line in load_lines(args.input):
            total += 1
            if not line.strip():
                blank += 1
                continue

            try:
                parsed = grok.match(line)
            except Exception as e:
                sys.stderr.write(f"  parse error on line {total}: {e}\n")
                parsed = None

            if parsed:
                matched += 1
                record = json.dumps(parsed, ensure_ascii=False)
                if args.jsonl:
                    out_f.write(record + "\n")
                else:
                    # incremental JSON array: comma-separate, indent each object
                    out_f.write(("" if first else ",\n") + "  " + record)
                    first = False
                if matched % max(1, args.flush_every) == 0:
                    out_f.flush()
            else:
                unmatched += 1
                if un_f is None:
                    un_f = unmatched_path.open("w", encoding="utf-8")
                un_f.write(line + "\n")
                if len(samples) < 5:
                    samples.append(line)

        if not args.jsonl:
            out_f.write(("" if first else "\n") + "]\n")
    except Exception as e:
        sys.stderr.write(f"Error while writing output: {e}\n")
        return 1
    finally:
        out_f.close()
        if un_f is not None:
            un_f.close()

    # ── summary ──────────────────────────────────────────────────────────────
    considered = matched + unmatched
    rate = (matched / considered * 100) if considered else 0.0
    print(f"Parsed {matched}/{considered} non-blank lines "
          f"({rate:.1f}% matched) → {args.output}")
    if blank:
        print(f"  {blank} blank line(s) skipped")
    if unmatched:
        print(f"  {unmatched} unmatched → {unmatched_path}")
        print("  first unmatched sample(s):")
        for s in samples:
            shown = s if len(s) <= 120 else s[:117] + "..."
            print(f"    | {shown}")
        print("  Tip: loosen the pattern (e.g. end with %{GREEDYDATA:rest}) or "
              "test it in a Grok Debugger before re-running.")
    else:
        # no unmatched lines — remove a stale unmatched file from a previous run
        try:
            if unmatched_path.exists():
                unmatched_path.unlink()
        except OSError:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
