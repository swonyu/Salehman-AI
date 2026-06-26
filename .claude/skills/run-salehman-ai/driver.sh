#!/usr/bin/env bash
# Driver for the "Salehman AI" macOS SwiftUI app.
# Wraps the fiddly parts an agent hits when building / launching / tearing it down.
# All paths are relative to the repo root (the app's <unit>).
#
#   ./.claude/skills/run-salehman-ai/driver.sh <command>
#
#   typecheck   Headless type-check of the whole app target (NO Xcode app run).
#               Fast (~80s), the right gate for most code changes. Exits non-zero on error.
#   build       Real `xcodebuild` build of the app. Prints the built .app path on success.
#   path        Print the built .app bundle path (queried from xcodebuild settings).
#   run         Kill any running instance, then launch a FRESH copy of the built .app.
#               (Plain `open` re-activates an already-running instance — see Gotchas.)
#   stop        Force-quit every running instance of the app.
#   test        Build-and-run the Swift Testing suite via xcodebuild (needs Xcode).
#
# After `run`, take the screenshot yourself with the computer-use MCP
# (request_access ["Salehman AI"] → open_application → screenshot). The shell
# `screencapture` is blocked by macOS Screen Recording perms in this context.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # skill is 3 levels under repo root
cd "$ROOT"
SCHEME="Salehman AI"
LOG="/tmp/salehman_build.log"
# Match the running binary precisely (the MacOS/ exec path), not stray matches.
PROC_PAT="Salehman AI.app/Contents/MacOS"

app_path() {
  xcodebuild -scheme "$SCHEME" -configuration Debug -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR =/{d=$2} / FULL_PRODUCT_NAME =/{n=$2} END{ if(d&&n) print d"/"n }'
}

stop_app() {
  # SIGTERM first (clean), then SIGKILL. A copy launched by Xcode's debugger
  # (argv has -NSDocumentRevisionsDebugMode) is owned by Xcode and may survive
  # both — quit Xcode or use its Stop button for that one.
  pkill    -f "$PROC_PAT" 2>/dev/null || true
  sleep 1
  pkill -9 -f "$PROC_PAT" 2>/dev/null || true
  sleep 1
}

case "${1:-}" in
  typecheck)
    exec bash tools/typecheck.sh
    ;;
  build)
    echo "Building $SCHEME …"
    xcodebuild -scheme "$SCHEME" -destination 'platform=macOS' \
      -configuration Debug CODE_SIGNING_ALLOWED=NO build \
      2>&1 | tee "$LOG" | tail -3
    grep -q '\*\* BUILD SUCCEEDED \*\*' "$LOG" || { echo "BUILD FAILED — see $LOG"; exit 1; }
    echo "App: $(app_path)"
    ;;
  path)
    p="$(app_path)"; [ -n "$p" ] && echo "$p" || { echo "no build settings — run 'build' first"; exit 1; }
    ;;
  run)
    APP="$(app_path)"
    [ -d "$APP" ] || { echo "Not built yet ($APP). Run: $0 build"; exit 1; }
    stop_app
    echo "Launching fresh: $APP"
    open -n "$APP"
    sleep 6
    pgrep -fl "$PROC_PAT" | head || { echo "did not start"; exit 1; }
    echo "Running. Screenshot via the computer-use MCP (Screen Recording perm required)."
    ;;
  stop)
    stop_app
    pgrep -fl "$PROC_PAT" >/dev/null && echo "still running (Xcode-owned? quit Xcode)" || echo "all stopped"
    ;;
  test)
    echo "Building + running tests …"
    xcodebuild test -scheme "$SCHEME" -destination 'platform=macOS' \
      -configuration Debug CODE_SIGNING_ALLOWED=NO -only-testing:"Salehman AITests" \
      2>&1 | tee "$LOG" | tail -6
    ;;
  *)
    grep -E '^#   ' "${BASH_SOURCE[0]}" | sed 's/^#   //'
    exit 1
    ;;
esac
