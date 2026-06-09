#!/usr/bin/env bash
# scripts/advance_tracks.sh
# Safe checkpoint script: build → test → optional commit → optional push.
# Called by `make advance` / `make advance-push` / `make advance-dry`.
#
# Flags:
#   --dry-run   show what would happen without building, committing, or pushing
#   --push      after a successful commit, push to origin/main
#   --commit    commit even without --push (default when neither flag given and changes exist)

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
info() { echo -e "${CYAN}→${RESET} $*"; }
warn() { echo -e "${YELLOW}!${RESET} $*"; }
fail() { echo -e "${RED}✗${RESET} $*"; exit 1; }

# ── Args ──────────────────────────────────────────────────────────────────────
DRY_RUN=false; DO_PUSH=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --push)    DO_PUSH=true ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

echo ""
info "Salehman AI — advance_tracks"
$DRY_RUN && warn "DRY RUN — no build, commit, or push will happen"
echo ""

# ── Check for changes ─────────────────────────────────────────────────────────
CHANGED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CHANGED" -eq 0 ]]; then
  ok "Working tree is clean — nothing to advance"
  exit 0
fi

info "Uncommitted changes: $CHANGED file(s)"
git status --short

if $DRY_RUN; then
  echo ""
  warn "Dry run complete — would build, test, then commit + push (if --push)."
  exit 0
fi

# ── Build ─────────────────────────────────────────────────────────────────────
echo ""
info "Building…"
BUILD_OUT=$(xcodebuild \
  -scheme "Salehman AI" \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1)

if echo "$BUILD_OUT" | grep -q "BUILD SUCCEEDED"; then
  ok "Build succeeded"
else
  echo "$BUILD_OUT" | grep -E "error:|BUILD FAILED" | tail -20
  fail "Build failed — aborting advance"
fi

# ── Test ──────────────────────────────────────────────────────────────────────
echo ""
info "Running tests…"
TEST_OUT=$(xcodebuild test \
  -scheme "Salehman AI" \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:"Salehman AITests" 2>&1)

if echo "$TEST_OUT" | grep -q "BUILD SUCCEEDED\|Test Suite.*passed"; then
  PASSED=$(echo "$TEST_OUT" | grep -E "Executed [0-9]+ test" | tail -1)
  ok "Tests passed${PASSED:+ — $PASSED}"
else
  echo "$TEST_OUT" | grep -E "error:|FAILED|BUILD FAILED" | tail -20
  fail "Tests failed — aborting advance"
fi

# ── Commit ────────────────────────────────────────────────────────────────────
echo ""
info "Committing…"
git add -A

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Build a short summary of what changed for the commit message
SUMMARY=$(git diff --cached --name-only | head -8 | tr '\n' ' ')

git commit -m "$(cat <<EOF
chore: advance checkpoint ($TIMESTAMP)

Files: $SUMMARY
Branch: $BRANCH

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
ok "Committed"

# ── Push ──────────────────────────────────────────────────────────────────────
if $DO_PUSH; then
  echo ""
  info "Pushing to origin/$BRANCH…"
  git push origin "$BRANCH"
  ok "Pushed"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
ok "Advance complete (build green, tests green, changes committed${DO_PUSH:+, pushed})"

# macOS notification
osascript -e 'display notification "Build green · Tests green · Committed" with title "Salehman AI — Advance ✓"' 2>/dev/null || true
