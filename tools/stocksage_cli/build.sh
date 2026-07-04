#!/bin/bash
# Build the stocksage CLI from an EXPLICIT minimal closure of DECOUPLED engine files (reused verbatim,
# zero port). The full advise/EV idea-pipeline is Store-coupled (StockSageIdea lives in the SwiftUI
# StockSageStore) and is NOT included here — that needs an app-side decoupling / Xcode CLI target.
cd "$(dirname "$0")" || exit 1
ENG="../../Salehman AI/StockSage"
# Grow this list by re-running and adding any "cannot find X in scope" file until it compiles.
CORE="StockSageNetEdge.swift StockSageLiquidity.swift StockSageAllocation.swift"
files=()
for name in $CORE; do files+=("$ENG/$name"); done
echo "compiling main.swift + ${#files[@]} decoupled engine files: $CORE"
swiftc -O main.swift "${files[@]}" -o stocksage 2>err.log
rc=$?
echo "rc=$rc"
if [ "$rc" -ne 0 ]; then
  echo "--- missing symbols (add their file to CORE) ---"
  grep -oE "cannot find '[A-Za-z0-9_]+' in scope|cannot find type '[A-Za-z0-9_]+'" err.log | sort -u | head
  echo "--- first 3 errors ---"; grep -E "error:" err.log | head -3
else
  echo "BUILT ok"
fi
