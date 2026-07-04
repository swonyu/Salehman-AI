#!/usr/bin/env bash
# One command: fetch a split-adjusted EODHD equity panel → run the IRRX net-cost ablation.
# The powered equity run OPEN FRONTIER #1 has waited on — fetch-and-go the instant a token exists.
#
#   EODHD_API_TOKEN=xxxxx ./fetch_and_ablate.sh            # base run (no earnings exclusion)
#   EODHD_API_TOKEN=xxxxx ./fetch_and_ablate.sh --earnings # + the IRRX "X" earnings-window exclusion
#
# No token? `python3 fetch_eodhd_panel.py --self-test` validates the fetch path on the demo (AAPL.US).
set -euo pipefail
cd "$(dirname "$0")"
if [ -z "${EODHD_API_TOKEN:-}" ]; then
  echo "set EODHD_API_TOKEN first (get one at https://eodhd.com). Validate offline: python3 fetch_eodhd_panel.py --self-test" >&2
  exit 1
fi
PANEL="panel_eodhd.json"
python3 fetch_eodhd_panel.py --out "$PANEL" "$@"
echo "=== ablation (verbatim shipped StockSageNetCostSim + StockSageDeflatedSharpe) ==="
./build_and_run.sh "$PANEL"
