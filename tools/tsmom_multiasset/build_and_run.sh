#!/bin/bash
# Build + run the TSMOM multi-asset ablation runner against the VERBATIM shipped engine sources.
# Usage: ./build_and_run.sh [panel.json]   (env: REVERSED=1 for the walk-backward diagnostic,
#                                            TRIALS_LEDGER=off to skip the registry append,
#                                            RUN_ID=... to override the deterministic run id)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
SRC="$REPO/Salehman AI/StockSage"
OUT="$DIR/runner"

swiftc -O "$DIR/main.swift" "$SRC/StockSageNetCostSim.swift" "$SRC/StockSageDeflatedSharpe.swift" -o "$OUT"
cd "$REPO"   # so the ledger resolves research/trials_ledger.jsonl
"$OUT" "${1:-$DIR/panel_tsmom_multiasset.json}"
