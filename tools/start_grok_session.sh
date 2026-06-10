#!/bin/bash
# tools/start_grok_session.sh
# Create a dedicated git branch before a Grok bridge session so every change
# made by Grok is easy to review and revert independently.
#
# Usage: bash tools/start_grok_session.sh
#        Then run the bridge as normal.
set -euo pipefail

BRANCH="grok-session-$(date +%s)"
git checkout -b "$BRANCH"
echo "=== GROK SESSION STARTED ON BRANCH: $BRANCH ==="
echo "    Review changes: git diff main"
echo "    Merge if good:  git checkout main && git merge $BRANCH"
echo "    Discard all:    git checkout main && git branch -D $BRANCH"
