#!/usr/bin/env bash
#
# bundle_source.sh — regenerate SOURCE_BUNDLE.md, the COMPLETE single-file source
# dump of Salehman AI, for handing the whole app to an external AI (Grok / etc.)
# or a person so they have full context in one paste.
#
# Run it before any external handoff:  bash tools/bundle_source.sh
# It locates the repo root relative to this script, so it works from anywhere.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
OUT="SOURCE_BUNDLE.md"

# All Swift sources + tests (sorted, NUL-safe for the space in "Salehman AI"),
# then the key markdown docs. Exclude the bundle itself to avoid recursion.
swift_files="$(find "Salehman AI" "Salehman AITests" -name '*.swift' -type f -print0 2>/dev/null | sort -z | tr '\0' '\n')"
md_files="$(ls -1 *.md 2>/dev/null | grep -v '^SOURCE_BUNDLE.md$' | sort || true)"

total_swift="$(printf '%s\n' "$swift_files" | grep -c . || true)"
loc="$(printf '%s\n' "$swift_files" | grep . | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}')"

{
  echo "# 📦 SOURCE_BUNDLE — Salehman AI (complete source)"
  echo
  echo "_Generated: $(date '+%Y-%m-%d %H:%M %Z') · Swift files: ${total_swift} · Swift LOC: ${loc}_"
  echo
  echo "> **For any AI or person reading this:** this file is the COMPLETE source of"
  echo "> the *Salehman AI* macOS app (SwiftUI, Swift 6), concatenated so you have"
  echo "> full context in one place. Start with the \`PROJECT_CONTEXT.md\` and"
  echo "> \`ARCHITECTURE.md\` sections (included at the end) for a guided tour, then"
  echo "> read the source. If you change anything, append a dated entry to"
  echo "> \`DEVELOPMENT_LOG.md\`. Regenerate this file with \`tools/bundle_source.sh\`."
  echo
  echo "---"
  echo

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    n="$(wc -l < "$f" | tr -d ' ')"
    echo "===== FILE: ${f} (${n} lines) ====="
    echo '```swift'
    cat "$f"
    echo '```'
    echo
  done <<< "$swift_files"

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    n="$(wc -l < "$f" | tr -d ' ')"
    echo "===== FILE: ${f} (${n} lines) ====="
    cat "$f"
    echo
  done <<< "$md_files"
} > "$OUT"

echo "Wrote ${OUT}: $(wc -l < "$OUT" | tr -d ' ') lines, $(du -h "$OUT" | cut -f1), ${total_swift} swift files (${loc} LOC) + markdown docs."
