#!/bin/bash
# tools/start_grok_session.sh
# Create a semantic grok/* branch before a bridge session.
#
# Usage: bash tools/start_grok_session.sh "fix json leak in BridgeAdapter"
#        bash tools/start_grok_session.sh   # falls back to unnamed
set -euo pipefail

TASK_NAME="${1:-unnamed}"
SLUG=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)
BRANCH="grok/${SLUG}-$(date +%Y%m%d-%H%M)"

git checkout -b "$BRANCH"
echo "=== GROK SESSION STARTED ==="
echo "Branch : $BRANCH"
echo "Task   : $TASK_NAME"
echo ""
echo "When done:"
echo "  Merge good:    git checkout main && git merge $BRANCH"
echo "  Discard all:   git checkout main && git branch -D $BRANCH"
echo "  Cleanup later: bash tools/cleanup_grok_branches.sh"
