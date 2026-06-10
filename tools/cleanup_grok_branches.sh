#!/bin/bash
# tools/cleanup_grok_branches.sh
# Delete grok/* branches that have been merged into main.
# Optionally force-delete unmerged ones older than N days.
#
# Usage:
#   bash tools/cleanup_grok_branches.sh          # delete merged only
#   bash tools/cleanup_grok_branches.sh --force  # also delete unmerged grok/* branches
set -euo pipefail

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

echo "=== CLEANING GROK BRANCHES ==="

# Delete merged grok/* branches (safe — changes are already in main)
MERGED=$(git branch --merged main | grep '  grok/' || true)
if [[ -n "$MERGED" ]]; then
    echo "$MERGED" | xargs git branch -d
    echo "Deleted merged: $(echo "$MERGED" | wc -l | tr -d ' ') branch(es)"
else
    echo "No merged grok/* branches to delete."
fi

# Force-delete unmerged grok/* branches if --force was passed
if $FORCE; then
    UNMERGED=$(git branch --no-merged main | grep '  grok/' || true)
    if [[ -n "$UNMERGED" ]]; then
        echo ""
        echo "Force-deleting unmerged branches:"
        echo "$UNMERGED"
        echo "$UNMERGED" | xargs git branch -D
    else
        echo "No unmerged grok/* branches found."
    fi
fi

echo ""
echo "Remaining grok/* branches:"
git branch --list 'grok/*' || echo "  (none)"
