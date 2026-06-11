#!/usr/bin/env bash
# grok_status.sh — live dashboard of every Grok bridge (running or finished).
# Reads the heartbeats at ~/grok_sessions/*.status.json that the bridge writes.
#
#   tools/grok_status.sh          # one-shot snapshot
#   tools/grok_status.sh --watch  # refresh every 2s (Ctrl-C to quit)
set -uo pipefail
DIR="$HOME/grok_sessions"

render() {
  python3 - "$DIR" <<'PY'
import json, os, sys
from pathlib import Path
d = Path(sys.argv[1])
rows = []
for f in sorted(d.glob("*.status.json")):
    try:
        s = json.loads(f.read_text())
    except Exception:
        continue
    pid = s.get("pid")
    alive = False
    if pid:
        try:
            os.kill(int(pid), 0); alive = True
        except Exception:
            alive = False
    state = s.get("state", "?")
    if state == "running" and not alive:
        state = "dead"          # heartbeat says running but the process is gone
    rows.append((
        s.get("label", "?"), state, s.get("commands", 0), s.get("max_commands") or "∞",
        s.get("elapsed", "?"), str(pid or "-"),
        (s.get("last_command") or s.get("task") or "")[:48],
    ))
if not rows:
    print("  (no Grok sessions in ~/grok_sessions/ yet)")
    sys.exit(0)
hdr = f"{'AGENT':<10}{'STATE':<13}{'CMDS':<9}{'ELAPSED':<9}{'PID':<8}LAST / CURRENT"
print(hdr); print("-" * max(len(hdr), 64))
icon = {"running": "▶", "done": "✓", "error": "✗",
        "interrupted": "⏸", "aborted": "⛔", "dead": "☠"}
for label, state, cmds, mx, el, pid, last in rows:
    st = f"{icon.get(state, '·')} {state}"
    print(f"{label:<10}{st:<13}{f'{cmds}/{mx}':<9}{el:<9}{pid:<8}{last}")
PY
}

if [ "${1:-}" = "--watch" ] || [ "${1:-}" = "-w" ]; then
  while true; do
    clear
    echo "🌉 Grok bridges — $(date '+%H:%M:%S')   (Ctrl-C to exit)"
    echo
    render
    sleep 2
  done
else
  render
fi
