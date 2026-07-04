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
# --- input-hardening / honesty regression guards (added 2026-07-04 after the adversarial CLI review) ---
# U2: non-finite input must die CLEANLY (exit 2), never SIGTRAP-crash (was exit 133).
./stocksage netcost --entry inf --stop 95 --target 110 >/dev/null 2>&1; [ $? -eq 2 ] && echo "ok  netcost rejects inf (clean exit 2, no crash)" || { echo "FAIL netcost inf not cleanly rejected"; fail=1; }
# U3: a --symbol containing a quote must still emit VALID JSON (was malformed).
if command -v python3 >/dev/null 2>&1; then
  ./stocksage netcost --entry 100 --stop 95 --target 110 --symbol 'A"B' | python3 -c 'import sys,json; json.load(sys.stdin)' 2>/dev/null && echo "ok  netcost escapes symbol → valid JSON" || { echo "FAIL netcost symbol breaks JSON"; fail=1; }
else echo "skip symbol-JSON check (no python3)"; fi
# U5: a non-numeric --returns token must die, never be silently dropped.
./stocksage deflated-sharpe --returns "0.02,foo,0.03,0.04,0.05" >/dev/null 2>&1; [ $? -ne 0 ] && echo "ok  deflated-sharpe rejects non-numeric token" || { echo "FAIL deflated-sharpe silently dropped a token"; fail=1; }
# U6: trials≥2 with NO var-trial-sharpe must NOT claim a haircut was applied (DSR==PSR there).
./stocksage deflated-sharpe --returns "0.02,-0.01,0.03,0,0.01,-0.02,0.04,0.01" --trials 200 | grep -q "NO selection-bias haircut" && echo "ok  deflated-sharpe note honest about no-op haircut" || { echo "FAIL deflated-sharpe haircut note misleading"; fail=1; }
# U7: usage string must advertise the real commands, not the nonexistent 'idea'.
u=$(./stocksage 2>&1); { echo "$u" | grep -q "deflated-sharpe" && ! echo "$u" | grep -q "idea"; } && echo "ok  usage lists real commands" || { echo "FAIL usage string stale"; fail=1; }
if [ $fail -eq 0 ]; then echo "PASS — netcost + deflated-sharpe (hand-derived) + indicators (live) + input-hardening guards"; else echo "CHECK FAILED"; exit 1; fi
