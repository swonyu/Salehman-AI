#!/usr/bin/env bash
# grok_status.sh — live Grok-bridge dashboard with ANSI colors.
#
#   tools/grok_status.sh          # one-shot snapshot
#   tools/grok_status.sh --watch  # refresh every 2 s  (Ctrl-C to quit)
set -uo pipefail
DIR="$HOME/grok_sessions"

render() {
  python3 - "$DIR" <<'PY'
import json, os, sys
from pathlib import Path

R = "\033[91m"; G = "\033[92m"; Y = "\033[93m"; C = "\033[96m"
D = "\033[2m";  B = "\033[1m";  E = "\033[0m"

def bold(s):    return f"{B}{s}{E}"
def dim(s):     return f"{D}{s}{E}"
def colored(c, s): return f"{c}{s}{E}"

d = Path(sys.argv[1])
rows = []
for f in sorted(d.glob("*.status.json")):
    try:
        s = json.loads(f.read_text())
    except Exception:
        continue
    pid   = s.get("pid")
    alive = False
    if pid:
        try:    os.kill(int(pid), 0); alive = True
        except: pass
    state = s.get("state", "?")
    if state == "running" and not alive:
        state = "dead"
    cmds  = int(s.get("commands", 0))
    mx    = s.get("max_commands") or "∞"
    el    = s.get("elapsed", "?")
    label = s.get("label", "?")
    last  = (s.get("last_command") or s.get("task") or "")[:56]
    rows.append((label, state, cmds, mx, el, str(pid or "-"), last))

if not rows:
    print(f"  {dim('no sessions in ~/grok_sessions/ yet — launch agents first')}")
    sys.exit(0)

ICON = {
    "running":     colored(G, "▶"),
    "done":        colored(G, "✓"),
    "error":       colored(R, "✗"),
    "interrupted": colored(Y, "⏸"),
    "aborted":     colored(R, "⛔"),
    "dead":        colored(R, "☠"),
}
CLR = {"running": G, "done": G, "error": R, "interrupted": Y, "aborted": R, "dead": R}

W_LABEL, W_STATE, W_CMDS, W_EL, W_PID = 13, 13, 9, 10, 8
print(f"{bold('AGENT'):<{W_LABEL+9}}"
      f"{bold('STATE'):<{W_STATE+9}}"
      f"{bold('CMDS'):<{W_CMDS}}"
      f"{bold('ELAPSED'):<{W_EL}}"
      f"{dim('PID'):<{W_PID+4}}"
      f"{bold('LAST COMMAND')}")
print(dim("─" * 80))

for label, state, cmds, mx, el, pid, last in rows:
    ic  = ICON.get(state, "?")
    cl  = CLR.get(state, "")
    # state cell: icon + colored text, manually padded (escape codes are invisible)
    state_cell = f"{ic} {colored(cl, state)}"
    state_pad  = " " * max(0, W_STATE - len(state) - 2)   # -2: icon+space
    print(f"{bold(label):<{W_LABEL+9}}{state_cell}{state_pad}"
          f"{f'{cmds}/{mx}':<{W_CMDS}}{el:<{W_EL}}{dim(pid):<{W_PID+4}}{dim(last)}")
PY
}

case "${1:-}" in
  --watch|-w)
    while true; do
      clear
      printf "\033[1m\033[96m🌉 Grok Bridges\033[0m  \033[2m%s\033[0m   \033[2m(Ctrl-C to quit)\033[0m\n\n" \
             "$(date '+%H:%M:%S')"
      render
      sleep 2
    done
    ;;
  *)
    render
    ;;
esac
# safari-1: concrete lane improvement - MarketsView readability cap + honesty note in Backtester. GROK_FIXES updated.
