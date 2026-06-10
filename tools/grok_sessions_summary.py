#!/usr/bin/env python3
# grok_sessions_summary.py — per-agent summary from ~/grok_sessions/*.jsonl (pure stdlib).
# Reads the structured event trail written by grok_terminal_bridge.py and prints,
# per agent: commands run, errors, last activity, and final state.
#
# (Started by Grok via the bridge; corrected by Claude — fixed the __main__ guard
#  and the glob pattern, and aligned the fields to the real event schema:
#  kind ∈ {start,command,declined,aborted,error,end}, label, ts, exit_code.)
import os, glob, json
from collections import defaultdict


def main():
    base = os.path.expanduser("~/grok_sessions")
    files = sorted(glob.glob(os.path.join(base, "*.jsonl")))
    if not files:
        print("No .jsonl session files found in ~/grok_sessions/")
        return

    agents = defaultdict(lambda: {"cmds": 0, "errs": 0, "last": None, "state": "running"})
    for fp in files:
        for line in open(fp, encoding="utf-8", errors="ignore"):
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            a = e.get("label") or e.get("session") or "unknown"
            rec = agents[a]
            kind = e.get("kind")
            if kind == "command":
                rec["cmds"] += 1
                if e.get("exit_code") not in (0, None):
                    rec["errs"] += 1          # non-zero exit = a failed command
            elif kind in ("error", "aborted"):
                rec["errs"] += 1
            if e.get("ts"):
                rec["last"] = e["ts"]          # events are append-order, so last wins
            if kind in ("end", "error", "aborted"):
                rec["state"] = e.get("state") or kind

    print("Grok Sessions — per-agent summary")
    print("=" * 64)
    print(f"{'AGENT':<14}{'CMDS':<7}{'ERRS':<7}{'STATE':<12}LAST ACTIVITY")
    print("-" * 64)
    for a in sorted(agents):
        d = agents[a]
        print(f"{a:<14}{d['cmds']:<7}{d['errs']:<7}{d['state']:<12}{d['last'] or 'N/A'}")


if __name__ == "__main__":
    main()
