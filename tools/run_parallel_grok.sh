#!/usr/bin/env bash
# run_parallel_grok.sh — launch N Grok Terminal Bridges IN PARALLEL on one repo.
#
# Each agent is ISOLATED where it must be and SHARED where it should be:
#   • own browser session  (--session-name grok-N → separate agent-browser Chrome)
#   • own grok.com chat     (each window logs in once)
#   • own command cap + logs (~/grok_sessions/grok-N.*)
#   • SHARED working dir + SHARED COORDINATION.md  → they claim lanes, stay out of
#     each other's files, and do NOT commit (the human reviews/commits at the end).
#
# This is the "COORDINATION.md model": coordination by protocol, not by isolation.
# (For full git isolation instead, use git worktrees — see the note at the bottom.)
#
# Usage:
#   tools/run_parallel_grok.sh "task for agent 1" "task for agent 2" [...]
#   (one quoted task per parallel agent; up to ~5 is sane on one machine)
#
# Env knobs:
#   REPO=/path      working dir for all agents     (default: this repo)
#   MAX_CMDS=60     per-agent command cap (safety) (0 = unlimited)
#   MODE=auto       bridge mode (auto = agent-browser; required for isolation)
#   STAGGER=2       seconds between launches (lets each browser open cleanly)
#
# Prereqs:
#   npm i -g agent-browser && agent-browser install
#   On first run, log into grok.com ONCE in each agent's browser window.
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BRIDGE="$SCRIPT_DIR/grok_terminal_bridge.py"
REPO="${REPO:-$( cd "$SCRIPT_DIR/.." && pwd )}"
MAX_CMDS="${MAX_CMDS:-60}"
MODE="${MODE:-auto}"
STAGGER="${STAGGER:-2}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 \"task 1\" \"task 2\" ...   (one quoted task per parallel agent)" >&2
  exit 1
fi
if [ ! -f "$BRIDGE" ]; then
  echo "bridge not found: $BRIDGE" >&2; exit 1
fi
if ! command -v agent-browser >/dev/null 2>&1; then
  echo "⚠  agent-browser not found — parallel mode needs it (each agent = its own browser)." >&2
  echo "   install:  npm i -g agent-browser && agent-browser install" >&2
  exit 1
fi

mkdir -p "$HOME/grok_sessions"
echo "🚀 launching $# parallel Grok agents"
echo "   repo=$REPO"
echo "   mode=$MODE   max-commands/agent=${MAX_CMDS}   coordinate=COORDINATION.md"
echo

i=0
for task in "$@"; do
  i=$((i + 1))
  name="grok-$i"
  out="$HOME/grok_sessions/${name}.out"
  printf '  • %-7s ⟶  %s\n' "$name" "${task:0:64}"
  # nohup + & detaches on macOS (setsid is Linux-only and not present here).
  nohup python3 "$BRIDGE" \
    --mode "$MODE" --yolo \
    --session-name "$name" --label "$name" \
    --coordinate \
    --max-commands "$MAX_CMDS" \
    --cwd "$REPO" \
    "$task" > "$out" 2>&1 < /dev/null &
  disown 2>/dev/null || true   # fully detach from this shell's job table
  sleep "$STAGGER"   # stagger so the browser windows don't race to open
done

cat <<EOF

✅ $# agents launched in the background.

   live dashboard : $SCRIPT_DIR/grok_status.sh
   one agent log  : tail -f ~/grok_sessions/grok-1.out
   structured feed: ~/grok_sessions/grok-*.jsonl   (Salehman ingests these)
   stop all       : pkill -f grok_terminal_bridge.py

⚠  First run: log into grok.com ONCE in each browser window that opens.
⚠  Agents will NOT commit — review the working tree and commit yourself when done:
     git -C "$REPO" status && git -C "$REPO" diff

# ── Full git isolation alternative (per-agent branch + commits) ───────────────
# If you'd rather each agent commit on its own branch, give each its own git
# worktree instead of a shared dir (then drop --coordinate):
#   git -C "$REPO" worktree add ../grok-wt-1 -b grok/agent-1
#   REPO=../grok-wt-1 tools/run_parallel_grok.sh "task 1"   # one per worktree
EOF
