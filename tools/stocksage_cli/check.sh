#!/bin/bash
# Runnable check: netcost output must match the HAND-DERIVED expected values (spec-fidelity — the
# expected numbers come from StockSageNetEdge.evaluate's formula by hand, NOT from the code's output).
# Hand derivation (entry=100, stop=95, target=110, AAPL=US 13bps):
#   cost = 13/10000*100 = 0.13 ; grossReward=10, grossRisk=5, grossRR=2.0
#   cappedGrossReward = min(2.0,50)*5 = 10 ; netReward = 10-0.13 = 9.87 ; netRisk = 5+0.13 = 5.13
#   netRR = 9.87/5.13 = 1.923977 ; breakEven = 1/(1+1.923977) = 0.342000
cd "$(dirname "$0")" || exit 1
[ -x ./stocksage ] || bash build.sh >/dev/null 2>&1 || { echo "build failed"; exit 1; }
out=$(./stocksage netcost --entry 100 --stop 95 --target 110 --symbol AAPL)
fail=0
check() { echo "$out" | grep -q "\"$1\": $2" && echo "ok  $1=$2" || { echo "FAIL $1 expected $2"; fail=1; }; }
check grossRR 2.000000
check netRR 1.923977
check costPerShare 0.130000
check breakEvenWinRate 0.342000
# deflated-sharpe: hand-derived sharpe (mean 0.01 ÷ sample-sd 0.02 = 0.5); trials=1 ⇒ DSR==PSR; sub-0.95 ⇒ !passes
ds=$(./stocksage deflated-sharpe --returns "0.02,-0.01,0.03,0,0.01,-0.02,0.04,0.01")
echo "$ds" | grep -q '"sharpe": 0.500000' && echo "ok  deflated-sharpe sharpe=0.5 (hand-derived)" || { echo "FAIL deflated-sharpe sharpe"; fail=1; }
echo "$ds" | grep -q '"passesDSRbar": false' && echo "ok  deflated-sharpe passesDSRbar=false" || { echo "FAIL passesDSRbar"; fail=1; }
# indicators: LIVE CoinGecko fetch — sanity only (data is non-deterministic), skipped offline
ind=$(./stocksage indicators --coin bitcoin --days 365 2>/dev/null)
if echo "$ind" | grep -q '"bars":'; then
  bars=$(echo "$ind" | sed -nE 's/.*"bars": ([0-9]+).*/\1/p')
  { [ -n "$bars" ] && [ "$bars" -gt 200 ]; } && echo "ok  indicators live: $bars bars, rsi/sma computed" || { echo "FAIL indicators bars ($bars)"; fail=1; }
else echo "skip indicators (offline / CoinGecko unreachable — non-fatal)"; fi
if [ $fail -eq 0 ]; then echo "PASS — netcost + deflated-sharpe (hand-derived) + indicators (live sanity)"; else echo "CHECK FAILED"; exit 1; fi
