#!/bin/zsh
# auto_checkpoint.sh — every-6h safety net (run by a launchd timer).
#
# Snapshots the WHOLE working tree (all sessions' WIP, tracked + untracked,
# .gitignore respected) to a dedicated `auto-backup` branch on the remote, then
# force-pushes ONLY that branch. It NEVER touches your current branch, your
# staging index, your working files, or `main` — it uses a throwaway index +
# `git commit-tree` plumbing. Goal: your work is always recoverable from the
# remote without polluting main with WIP/red commits.
#
# Disable: launchctl unload ~/Library/LaunchAgents/com.salehmanai.autocheckpoint.plist

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
REPO="/Users/saleh/Downloads/SalehmanAI_Complete_Everything_Today/Salehman AI"
BRANCH="auto-backup"

cd "$REPO" || exit 0

# Nothing to back up since last commit? Then do nothing.
[ -z "$(git status --porcelain)" ] && { echo "$(date '+%F %T') nothing to checkpoint"; exit 0; }

# Build the snapshot tree in a THROWAWAY index so the real index is untouched.
TMPIDX="$(mktemp -t salehman_ckpt_idx)"
export GIT_INDEX_FILE="$TMPIDX"
git read-tree HEAD
git add -A                      # stages all changes into the temp index (honors .gitignore)
TREE="$(git write-tree)"
unset GIT_INDEX_FILE
rm -f "$TMPIDX"

PARENT="$(git rev-parse HEAD)"
MSG="Auto-checkpoint $(date '+%Y-%m-%d %H:%M') — WIP snapshot (not main)"
COMMIT="$(git commit-tree "$TREE" -p "$PARENT" -m "$MSG")"

git update-ref "refs/heads/$BRANCH" "$COMMIT"
if git push -f origin "$BRANCH" >/dev/null 2>&1; then
    echo "$(date '+%F %T') checkpoint pushed: $COMMIT -> origin/$BRANCH"
else
    echo "$(date '+%F %T') checkpoint committed locally ($COMMIT) but push FAILED (SSH/auth from launchd?)"
fi
