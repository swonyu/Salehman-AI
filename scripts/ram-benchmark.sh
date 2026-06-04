#!/bin/zsh
# Salehman AI — Ollama brain RAM benchmark.
#
# Measures the loaded model's resident size (`ollama ps` SIZE) and system free
# memory across N turns, then confirms the 30s keep_alive eviction fires.
#
# WHY NOT INSTRUMENTS: the model weights live in the `ollama serve` (runner)
# process, not the app's address space — so `instruments -t Allocations` on the
# app would miss the ~14 GB swing entirely. `ollama ps` is the right signal.
#
# Usage (run BOTH, compare the SIZE column — that delta is the win):
#   MODEL=qwen2.5-coder:7b  zsh scripts/ram-benchmark.sh
#   MODEL=qwen2.5-coder:32b zsh scripts/ram-benchmark.sh
#   (optional) TURNS=10
emulate -L zsh
MODEL="${MODEL:-qwen2.5-coder:7b}"
TURNS="${TURNS:-10}"
HOST="http://localhost:11434"

free_pct() { memory_pressure 2>/dev/null | awk -F': ' '/free percentage/{print $2}'; }
loaded()   { ollama ps 2>/dev/null | awk 'NR==2'; }   # full data row: NAME ID SIZE PROCESSOR UNTIL

echo "== Salehman AI RAM benchmark =="
echo "model: $MODEL   turns: $TURNS"

if ! curl -sf "$HOST/api/version" >/dev/null; then
  echo "❌ Ollama not reachable at $HOST. Start it:  ollama serve"; exit 1
fi
if ! ollama list 2>/dev/null | grep -q "${MODEL%%:*}"; then
  echo "⚠️  $MODEL not installed. Pull it first:  ollama pull $MODEL"; exit 1
fi

ollama stop "$MODEL" >/dev/null 2>&1
sleep 2
echo "baseline free: $(free_pct)   (model unloaded)"
echo "---"

for i in $(seq 1 "$TURNS"); do
  curl -s "$HOST/api/generate" \
    -d "{\"model\":\"$MODEL\",\"prompt\":\"In one sentence, what is $i+$i?\",\"stream\":false,\"keep_alive\":\"30s\"}" \
    >/dev/null
  printf "turn %2d  free=%-6s  loaded: %s\n" "$i" "$(free_pct)" "$(loaded)"
done

echo "---"
echo "loaded now:"; ollama ps
echo "free after run: $(free_pct)"
echo "waiting 35s for keep_alive (30s) eviction…"
sleep 35
n=$(ollama ps 2>/dev/null | tail -n +2 | grep -c .)
echo "after idle: $n model(s) loaded   (expect 0 — proves keep_alive eviction)"
echo "free after idle: $(free_pct)"
echo "== done. The 'loaded' SIZE column is the model's RAM footprint. =="
