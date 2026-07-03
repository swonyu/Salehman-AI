#!/bin/bash
# Yahoo-independent IRRX net-of-cost ablation runner.
# Compiles the runner against the app's REAL StockSageNetCostSim + StockSageDeflatedSharpe
# (no copies — the math is byte-for-byte what ships), then runs on a supplied panel JSON.
# Usage: ./build_and_run.sh path/to/panel.json
# See README.md for the panel.json shape and how to fetch a panel (CoinGecko / Alpha Vantage).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
SRC="$REPO/Salehman AI/StockSage"
OUT="${TMPDIR:-/tmp}/altdata_runner"
swiftc -O "$DIR/main.swift" "$SRC/StockSageNetCostSim.swift" "$SRC/StockSageDeflatedSharpe.swift" -o "$OUT"
"$OUT" "${1:-$DIR/panel.json}"
