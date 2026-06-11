#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# One-command QA loop for the (screen-blind) AI session.
#
#   bash tools/qa.sh            # request fresh snapshots, launch app, print results
#   bash tools/qa.sh --adopt    # also adopt the new snapshots as the diff baseline
#
# It requests a capture (`qa/SNAPSHOT_REQUEST`), launches the Debug app to fulfill
# it in-process (no Screen-Recording permission needed), waits for the manifest to
# refresh, then prints `INDEX.md` + a compact pass/fail summary from `AUDIT.json`.
# The session then just `Read`s the PNGs named in the manifest.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QA="$ROOT/qa"; SNAPS="$QA/snapshots"
APP="${SALEHMAN_APP:-$HOME/Library/Developer/Xcode/DerivedData/Salehman_AI-fcpwwssdbbmiloenbxdxsxwhcoev/Build/Products/Debug/Salehman AI.app}"
[ -d "$APP" ] || { echo "❌ Debug app not found at: $APP"; echo "   Build it first, or set SALEHMAN_APP."; exit 1; }

mkdir -p "$QA"
before=$(stat -f %m "$SNAPS/INDEX.md" 2>/dev/null || echo 0)
[ "${1:-}" = "--adopt" ] && touch "$QA/ADOPT_BASELINES"
touch "$QA/SNAPSHOT_REQUEST"
echo "→ launching app to fulfill the snapshot request…"
open "$APP"

audit_before=$(stat -f %m "$SNAPS/AUDIT.json" 2>/dev/null || echo 0)
echo -n "→ waiting for fresh capture"
for _ in $(seq 1 45); do
  now=$(stat -f %m "$SNAPS/INDEX.md" 2>/dev/null || echo 0)
  [ "$now" != "$before" ] && { echo " ✓"; break; }
  echo -n "."; sleep 1
done
# INDEX.md lands before the audit finishes — wait for AUDIT.json to refresh too,
# otherwise the summary below prints the PREVIOUS run's verdicts (a real footgun:
# it kept reporting a stale 31% diff after the baseline was already adopted).
echo -n "→ waiting for the audit"
for _ in $(seq 1 30); do
  now=$(stat -f %m "$SNAPS/AUDIT.json" 2>/dev/null || echo 0)
  [ "$now" != "$audit_before" ] && { echo " ✓"; break; }
  echo -n "."; sleep 1
done

echo
echo "════════════════════════ INDEX.md ════════════════════════"
cat "$SNAPS/INDEX.md" 2>/dev/null || echo "(no manifest — capture may have failed)"

echo
echo "════════════════════════ AUDIT ═══════════════════════════"
python3 - "$SNAPS/AUDIT.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("(no AUDIT.json — the audit pass may not have run)"); sys.exit(0)
res = d.get("results", []); fails = d.get("failures", [])
for r in res:
    checks = r.get("checks", [])
    bad = [c for c in checks if not c.get("pass", True)]
    mark = "✅" if not bad else "❌"
    diff = r.get("diffPercent")
    diff_s = f" · Δ{diff:.2f}%" if isinstance(diff, (int, float)) else ""
    print(f"{mark} {r.get('snapshot','?'):16}{diff_s}")
    for c in bad:
        print(f"      ↳ {c.get('name')}: {c.get('detail','')}")
print()
print(f"FAILURES: {', '.join(fails) if fails else 'none — all surfaces pass'}")
PY

# Surface regression heat-maps (QAAudit writes <name>_diff.png for anything that
# moved >0.5% vs the adopted baseline) so the session knows exactly what changed.
diffs=$(ls "$SNAPS"/*_diff.png 2>/dev/null || true)
if [ -n "$diffs" ]; then
  echo
  echo "════════════════ REGRESSION HEAT-MAPS (vs baseline) ════════════════"
  for d in $diffs; do echo "  ⚠ $(basename "$d") — red = pixels that moved; Read it to see what changed"; done
else
  echo
  echo "(no *_diff.png — nothing moved past threshold, or no baseline adopted yet)"
fi

echo
echo "PNGs in $SNAPS/ — Read contact_sheet.png first, then drill into any flagged surface."
case " $* " in *" --open "*) open "$SNAPS/contact_sheet.png" 2>/dev/null || true ;; esac
