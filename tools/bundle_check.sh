#!/bin/bash
set -euo pipefail

# bundle_check.sh — safari-4 lane [B:4441dcf848]
# Verify SOURCE_BUNDLE.md is newer than every .swift under Salehman AI/
# Exit 1 + list all stale .swift files if any is newer than the bundle doc.

SOURCE_BUNDLE="SOURCE_BUNDLE.md"
SWIFT_ROOT="Salehman AI"

if [ ! -f "$SOURCE_BUNDLE" ]; then
  echo "ERROR: $SOURCE_BUNDLE not found in $(pwd)"
  exit 1
fi

stale_files=()
while IFS= read -r -d "" swift_file; do
  if [ "$swift_file" -nt "$SOURCE_BUNDLE" ]; then
    stale_files+=("$swift_file")
  fi
done < <(find "$SWIFT_ROOT" -name "*.swift" -type f -print0 2>/dev/null || true)

if [ "${#stale_files[@]}" -gt 0 ]; then
  echo "ERROR: SOURCE_BUNDLE.md is NOT newer than the following .swift file(s):"
  printf '  %s\n' "${stale_files[@]}"
  exit 1
else
  echo "PASS: SOURCE_BUNDLE.md is newer than all .swift files under $SWIFT_ROOT/"
  exit 0
fi
