#!/usr/bin/env bash
# run_parallel_safari.sh — launch N Grok agents IN PARALLEL using your signed-in
# Safari (passes Cloudflare, no per-window login). Each agent opens + drives its
# OWN Safari window (--safari-window, targeted by window id), with deep-thinking
# (--think) and continuous looping (--loop) on.
#
# Why Safari (not agent-browser): your real Safari is already logged into grok.com,
# so it sails past Cloudflare — the thing that blocks automated Chrome.
#
# Usage:
#   tools/run_parallel_safari.sh "task 1" "task 2" "task 3" ...
#   (one quoted task per agent; ~3-5 is sane on one machine / one grok account)
#
# Env knobs:
#   REPO=/path      working dir for all agents     (default: this repo)
#   MAX_CMDS=60     per-agent command cap (loop safety; KEEP THIS SET)
#   STAGGER=4       seconds between launches (lets each Safari window open cleanly)
#
# 👉 KEEP THEM OFF YOUR SCREEN: before running, make a new macOS Space
#    (Mission Control → + , or Ctrl-Up then +) and SWITCH TO IT, then run this
#    there. The 5 Safari windows open on that Space, run full-speed, and you flip
#    back to Desktop 1. (Minimizing/hiding would throttle them — a separate Space
#    keeps them at full speed.)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BRIDGE="$SCRIPT_DIR/grok_terminal_bridge.py"
REPO="${REPO:-$( cd "$SCRIPT_DIR/.." && pwd )}"
MAX_CMDS="${MAX_CMDS:-60}"
STAGGER="${STAGGER:-4}"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 \"task 1\" \"task 2\" ...   (one quoted task per parallel agent)" >&2
  exit 1
fi
[ -f "$BRIDGE" ] || { echo "bridge not found: $BRIDGE" >&2; exit 1; }

# Safari one-time setup reminder
if ! defaults read com.apple.Safari AllowJavaScriptFromAppleEvents >/dev/null 2>&1; then
  echo "⚠  If agents can't drive Safari: Safari → Settings → Advanced → 'Show features"
  echo "   for web developers', then Develop → 'Allow JavaScript from Apple Events'."
fi

mkdir -p "$HOME/grok_sessions"
echo "🦋 launching $# parallel SAFARI agents (own window each · Think on · loop on)"
echo "   repo=$REPO   max-commands/agent=$MAX_CMDS   stagger=${STAGGER}s"
echo "   tip: run this from a separate macOS Space so the windows stay off your way."
echo

i=0
for task in "$@"; do
  i=$((i + 1))
  name="safari-$i"
  out="$HOME/grok_sessions/${name}.out"
  printf '  • %-9s ⟶  %s\n' "$name" "${task:0:60}"
  nohup python3 "$BRIDGE" \
    --auto --yolo \
    --safari-window --think --loop \
    --session-name "$name" --label "$name" --coordinate \
    --max-commands "$MAX_CMDS" \
    --cwd "$REPO" \
    "$task" > "$out" 2>&1 < /dev/null &
  disown 2>/dev/null || true
  sleep "$STAGGER"   # let each Safari window open + register its id before the next
done

cat <<EOF

✅ $# Safari agents launched.
   live dashboard : $SCRIPT_DIR/grok_status.sh --watch
   one agent log  : tail -f ~/grok_sessions/safari-1.out
   structured feed: ~/grok_sessions/safari-*.jsonl   (for Salehman ingestion)
   stop all       : pkill -f grok_terminal_bridge.py

⚠  Each agent loops (keeps working after [[DONE]]) until it hits --max-commands
   ($MAX_CMDS) or you pkill it. They claim lanes in COORDINATION.md and won't commit.
⚠  One grok.com account driving N chats at once can rate-limit — start with 2-3.
EOF
