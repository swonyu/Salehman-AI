#!/usr/bin/env bash
# tools/apply_grok_diff.sh — validate + apply a unified diff Grok wrote.
#
# Usage (from a Grok CMD: block):
#   cat > /tmp/grok.diff << 'DIFF_EOF'
#   --- a/Salehman AI/LLM/LocalLLM.swift
#   +++ b/Salehman AI/LLM/LocalLLM.swift
#   @@ -42,6 +42,7 @@
#    context...
#   +    new line
#    context...
#   DIFF_EOF
#   CMD: bash tools/apply_grok_diff.sh
#
# Three-pass strategy:
#   1. Clean apply — exactly as-is.
#   2. --whitespace=fix — tolerates Windows CRLF and trailing spaces.
#   3. Give up — print where it fails (--reject) so Grok can correct the hunk.
set -uo pipefail

DIFF_FILE="${1:-/tmp/grok.diff}"

if [[ ! -f "$DIFF_FILE" ]]; then
    echo "ERROR: diff file not found: $DIFF_FILE" >&2
    exit 1
fi

echo "=== DIFF ($DIFF_FILE) ==="
cat "$DIFF_FILE"
echo ""

# ── Pass 1: clean apply ───────────────────────────────────────────────────
if git apply --check "$DIFF_FILE" 2>/dev/null; then
    echo "=== APPLYING (clean) ==="
    git apply --index "$DIFF_FILE"
    rm -f "$DIFF_FILE"
    echo "=== RESULT ==="
    git status --porcelain
    git diff --stat HEAD
    exit 0
fi

# ── Pass 2: whitespace=fix ────────────────────────────────────────────────
if git apply --check --whitespace=fix "$DIFF_FILE" 2>/dev/null; then
    echo "=== APPLYING (--whitespace=fix) ==="
    git apply --whitespace=fix --index "$DIFF_FILE"
    rm -f "$DIFF_FILE"
    echo "=== RESULT ==="
    git status --porcelain
    git diff --stat HEAD
    exit 0
fi

# ── Pass 3: give up — show exactly where it fails ─────────────────────────
echo "=== DIFF DOES NOT APPLY — DIAGNOSIS ===" >&2
echo "--- git apply --check ---" >&2
git apply --check "$DIFF_FILE" 2>&1 | head -40 >&2
echo "" >&2
echo "--- --reject to locate conflict hunks ---" >&2
git apply --reject "$DIFF_FILE" 2>&1 | head -50 >&2 || true
echo "" >&2
echo "--- .rej files (rejected hunks) ---" >&2
find . -name "*.rej" -not -path "./.git/*" 2>/dev/null | while IFS= read -r rej; do
    echo "REJECT: $rej" >&2
    cat "$rej"          >&2
done
rm -f "$DIFF_FILE"
exit 1
