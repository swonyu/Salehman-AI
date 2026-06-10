#!/usr/bin/env bash
# fleet_supervisor.sh — keep N Grok agents alive FOREVER (self-healing).
#
# Each agent loops with NO command cap (--loop --max-commands 0). The supervisor
# checks every CHECK seconds and respawns any slot whose agent has died, handing
# it that slot's meaningful task. Runs until you kill it.
#
#   nohup bash tools/fleet_supervisor.sh > ~/grok_sessions/supervisor.log 2>&1 &
#   tools/grok_status.sh --watch          # watch the fleet
#   pkill -f fleet_supervisor.sh; pkill -f grok_terminal_bridge.py   # STOP everything
#
# Env: N=7 (agents), CHECK=60 (respawn poll secs), THINK=0 (1 = reasoning, burns quota).
set -uo pipefail
REPO="${REPO:-/Users/saleh/Desktop/Salehman AI}"
BRIDGE="$REPO/tools/grok_terminal_bridge.py"
N="${N:-7}"
CHECK="${CHECK:-60}"
THINK_FLAG=""; [ "${THINK:-0}" = "1" ] && THINK_FLAG="--think"
mkdir -p "$HOME/grok_sessions"

# One meaningful, BROAD lane per slot (broad so a forever-loop never runs dry and
# starts inventing junk). --loop re-prompts each agent for the next item in its lane.
TASKS=(
  "Bug-hunt tools/grok_terminal_bridge.py: read it, run it with --help, trace the Safari-drive/parse/loop/rate-limit logic, and APPEND each real bug/race/edge-case you find to tools/BUGS_bridge_py.md (one clear entry each, with file:line + why). Keep finding new ones. Do NOT fix code. Do NOT git commit."
  "Bug-hunt the shell tools (tools/run_parallel_safari.sh, grok_status.sh, fleet_supervisor.sh, grok_sessions_summary.py): run each with --help/safe args, APPEND quoting/edge-case/portability/exit-code bugs to tools/BUGS_bridge_sh.md. Keep finding new ones. Do NOT fix. Do NOT git commit."
  "Keep improving ARCHITECTURE.md: accurate data-flow for Effort, SelfCritique, brain-routing, the vLLM/Salehman integration, the Grok bridge. Read code to stay correct. Only ARCHITECTURE.md. Do NOT git commit."
  "Keep improving PROJECT_CONTEXT.md: Grok bridge tooling, Effort, vLLM serving, the 8B fine-tune, the knowledge vault. Match the real code. Only PROJECT_CONTEXT.md. Do NOT git commit."
  "Keep improving tools/README.md: document every script in tools/ (purpose, usage, every flag, examples). Read each script to stay accurate. Only tools/README.md. Do NOT git commit."
  "Keep improving salehman-training/README.md: the full fine-tune pipeline (mac vs runpod, 00-05 steps, dataset, persona, serving) + troubleshooting. Only that file. Do NOT git commit."
  "Improve the Python in 'Salehman AI/grok_parser.py' and tools/*.py: docstrings, type hints, --help text, small safety fixes. Verify with python3 -m py_compile. ONE file per turn, your choice. Do NOT git commit."
)

spawn() {
  local slot="$1" task="$2" ref
  ref=$(osascript <<'OSA' 2>/dev/null
tell application "Safari"
  if (count of windows) is 0 then make new document with properties {URL:"https://grok.com"}
  set t to make new tab at end of tabs of front window with properties {URL:"https://grok.com"}
  return "tab " & (index of t as string) & " of window id " & (id of front window as string)
end tell
OSA
)
  [ -z "$ref" ] && { echo "$(date '+%H:%M:%S') slot $slot: couldn't open tab"; return 1; }
  sleep 6   # let the tab load grok.com before driving it
  nohup python3 -u "$BRIDGE" --auto --yolo --loop $THINK_FLAG \
    --safari-target "$ref" --session-name "fleet-$slot" --label "fleet-$slot" --coordinate \
    --max-commands 0 --cwd "$REPO" "$task" \
    > "$HOME/grok_sessions/fleet-$slot.out" 2>&1 &
  disown 2>/dev/null || true
  echo "$(date '+%H:%M:%S') spawned fleet-$slot on $ref"
}

echo "=== fleet supervisor up $(date) · N=$N · think=${THINK:-0} · check=${CHECK}s ==="
while true; do
  for slot in $(seq 1 "$N"); do
    if ! pgrep -f "label fleet-$slot " >/dev/null 2>&1; then
      echo "$(date '+%H:%M:%S') fleet-$slot down → respawning"
      spawn "$slot" "${TASKS[$(((slot-1) % ${#TASKS[@]}))]}"
      sleep 6   # stagger so tabs register cleanly
    fi
  done
  sleep "$CHECK"
done
