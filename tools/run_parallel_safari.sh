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

# ── Auto-detect a SAFE agent limit from this Mac's RAM ────────────────────────
# Each grok.com tab is a heavy SPA (~1-1.5 GB resident). Reserve ~10 GB for macOS
# + your apps, then ~2 GB per agent, clamped to [1, 8]. Override with MAX_AGENTS=N.
RAM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
AUTO_LIMIT=$(( (RAM_GB - 10) / 2 ))
[ "$AUTO_LIMIT" -lt 1 ] && AUTO_LIMIT=1
[ "$AUTO_LIMIT" -gt 8 ] && AUTO_LIMIT=8
LIMIT="${MAX_AGENTS:-$AUTO_LIMIT}"

REQUESTED=$#
N=$REQUESTED
if [ "$N" -gt "$LIMIT" ]; then
  echo "🧠 device: ${RAM_GB} GB RAM → safe limit ${LIMIT} agents (you asked for ${REQUESTED})."
  echo "   Capping to ${LIMIT} to protect your RAM. (override: MAX_AGENTS=N)"
  N=$LIMIT
fi

echo "🦋 launching $N parallel SAFARI agents (own tab each · Think on · loop on)"
echo "   repo=$REPO   max-commands/agent=$MAX_CMDS   device=${RAM_GB}GB → limit ${LIMIT}"
echo "   tip: run this from a separate macOS Space so the tabs stay off your way."
echo

# ── Pre-create N grok.com tabs in ONE fresh window, SEQUENTIALLY (race-free). ──
# Each agent then drives an assigned tab by index — no two agents can converge on
# the same tab (the bug when each agent opened its own). Returns "WID:idx1 idx2 …".
echo "→ creating $N grok.com tabs (race-free) …"
MAP=$(osascript <<OSA
tell application "Safari"
  activate
  set newDoc to make new document with properties {URL:"https://grok.com"}
  set wid to id of front window
  set idxs to (index of current tab of front window as string)
  repeat with j from 2 to $N
    set t to make new tab at end of tabs of window id wid with properties {URL:"https://grok.com"}
    set idxs to idxs & " " & (index of t as string)
  end repeat
  return (wid as string) & ":" & idxs
end tell
OSA
)
WID="${MAP%%:*}"
IDXS="${MAP#*:}"
if [ -z "$WID" ] || [ "$WID" = "$MAP" ]; then
  echo "✗ couldn't pre-create Safari tabs (is 'Allow JavaScript from Apple Events' on?). MAP=$MAP" >&2
  exit 1
fi
echo "   window id $WID · tabs: $IDXS"
read -r -a TABIDX <<< "$IDXS"
echo "→ waiting 6s for the tabs to load grok.com …"; sleep 6

i=0
for task in "$@"; do
  [ "$i" -ge "$N" ] && break   # respect the auto-detected RAM limit
  name="safari-$((i + 1))"
  out="$HOME/grok_sessions/${name}.out"
  target="tab ${TABIDX[$i]} of window id $WID"
  printf '  • %-9s [%s] ⟶  %s\n' "$name" "$target" "${task:0:48}"
  nohup python3 "$BRIDGE" \
    --auto --yolo \
    --safari-target "$target" --think --loop \
    --session-name "$name" --label "$name" --coordinate \
    --max-commands "$MAX_CMDS" \
    --cwd "$REPO" \
    "$task" > "$out" 2>&1 < /dev/null &
  disown 2>/dev/null || true
  i=$((i + 1))
  sleep "$STAGGER"
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
