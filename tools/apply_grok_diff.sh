#!/bin/bash
# tools/apply_grok_diff.sh
# Apply a unified diff that Grok wrote to /tmp/grok.diff.
#
# Usage in Grok's run block:
#   cat > /tmp/grok.diff << 'DIFF_EOF'
#   --- a/Salehman AI/LLM/LocalLLM.swift
#   +++ b/Salehman AI/LLM/LocalLLM.swift
#   @@ -42,6 +42,7 @@
#    ...context...
#   +    new line here
#    ...context...
#   DIFF_EOF
#   bash tools/apply_grok_diff.sh
#
# The script validates the diff first (--check), then applies it staged (--index).
# Exits non-zero and prints why if the diff does not apply cleanly.
set -euo pipefail

DIFF_FILE="${1:-/tmp/grok.diff}"

if [ ! -f "$DIFF_FILE" ]; then
    echo "ERROR: diff file not found: $DIFF_FILE" >&2
    exit 1
fi

echo "=== DIFF CONTENT ==="
cat "$DIFF_FILE"
echo ""
echo "=== CHECKING DIFF ==="
git apply --check "$DIFF_FILE"

echo "=== APPLYING DIFF ==="
git apply --index "$DIFF_FILE"
rm -f "$DIFF_FILE"

echo "=== RESULT ==="
git status --porcelain
git diff --stat HEAD
