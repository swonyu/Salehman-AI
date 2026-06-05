#!/usr/bin/env bash
# build_mac.sh — one-shot Salehman pipeline on Apple Silicon.
#
# Drops a single dataset.jsonl into the pipeline and walks it all the way to a
# running Ollama model named `salehman`. Honest end-to-end: every step is a real
# tool (MLX-LM → llama.cpp → Ollama), nothing simulated.
#
# Usage:
#     bash build_mac.sh                    # uses ./dataset.jsonl
#     bash build_mac.sh personas/coder.jsonl
#     ITERS=1200 BASE="..." bash build_mac.sh   # tune anything via env vars
#
# Run validate_dataset.py first — this script bails early if your data is bad.

set -euo pipefail

DATA_FILE="${1:-dataset/salehman_persona.jsonl}"
BASE="${BASE:-mlx-community/Meta-Llama-3.1-8B-Instruct-4bit}"
ITERS="${ITERS:-600}"
LR="${LR:-2e-4}"
BATCH="${BATCH:-2}"
LORA_LAYERS="${LORA_LAYERS:-16}"
MODEL_NAME="${MODEL_NAME:-salehman}"
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-./llama.cpp}"

say()  { printf "\n\033[1;35m▸ %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

# ── 0. Sanity ────────────────────────────────────────────────────────────────
[[ -f "$DATA_FILE" ]] || fail "Dataset not found: $DATA_FILE"
command -v python3 >/dev/null  || fail "python3 not found (install Python ≥3.10)"
command -v ollama  >/dev/null  || fail "ollama not found (https://ollama.com/download)"

# Validate first — catch the silent dataset bugs before burning training time.
if [[ -f "validate_dataset.py" ]]; then
    say "Validating dataset…"
    python3 validate_dataset.py "$DATA_FILE" || fail "Dataset failed validation. Fix the ❌ errors above."
fi

# ── 1. Install MLX-LM (idempotent) ───────────────────────────────────────────
say "Installing/upgrading mlx-lm…"
python3 -m pip install -q -U mlx-lm

# ── 2. Split dataset into train/valid for MLX's expected layout ──────────────
say "Splitting $DATA_FILE → ./data/train.jsonl + ./data/valid.jsonl (90/10)…"
mkdir -p data
python3 - <<PY
from pathlib import Path
lines = [l for l in Path("$DATA_FILE").read_text("utf-8").splitlines() if l.strip()]
n = len(lines); cut = max(1, int(n * 0.9))
Path("data/train.jsonl").write_text("\n".join(lines[:cut]) + "\n", "utf-8")
Path("data/valid.jsonl").write_text("\n".join(lines[cut:]) + "\n", "utf-8")
print(f"  train: {cut} rows, valid: {n-cut} rows")
PY

# ── 3. LoRA fine-tune (adapters land in ./adapters) ──────────────────────────
say "LoRA fine-tuning $BASE for $ITERS iters (this is the GPU/MLX-heavy step)…"
python3 -m mlx_lm.lora \
    --model "$BASE" \
    --train --data ./data \
    --batch-size "$BATCH" \
    --num-layers "$LORA_LAYERS" \
    --iters "$ITERS" \
    --learning-rate "$LR" \
    --adapter-path ./adapters

# ── 4. Fuse adapters into a single merged model ──────────────────────────────
say "Fusing LoRA adapters into the base model → ./salehman-merged …"
rm -rf ./salehman-merged
python3 -m mlx_lm.fuse \
    --model "$BASE" \
    --adapter-path ./adapters \
    --save-path ./salehman-merged

# ── 5. Convert the merged model to GGUF (needs llama.cpp) ────────────────────
if [[ ! -d "$LLAMA_CPP_DIR" ]]; then
    say "Cloning llama.cpp into $LLAMA_CPP_DIR (one-time)…"
    git clone --depth 1 https://github.com/ggerganov/llama.cpp "$LLAMA_CPP_DIR"
fi
say "Installing llama.cpp Python requirements…"
python3 -m pip install -q -r "$LLAMA_CPP_DIR/requirements.txt"
say "Converting → salehman.gguf (q4_k_m)…"
python3 "$LLAMA_CPP_DIR/convert_hf_to_gguf.py" \
    ./salehman-merged \
    --outfile salehman.gguf \
    --outtype q4_k_m

# ── 6. Create the Ollama model from the canonical Modelfile ──────────────────
MODELFILE="${MODELFILE:-Modelfile.salehman}"
[[ -f "$MODELFILE" ]] || fail "$MODELFILE missing — keep it next to build_mac.sh"
say "Importing into Ollama as \"$MODEL_NAME\" (via $MODELFILE)…"
ollama create "$MODEL_NAME" -f "$MODELFILE"

# ── 7. Done — point the user at the app ─────────────────────────────────────
say "✅ All done."
cat <<NEXT

Your Salehman is live:
    ollama run $MODEL_NAME "Who are you?"

In the app:
    Settings → Brain → "Salehman (your model)"
    (set the model-name field to "$MODEL_NAME" if it isn't already)

To improve it further: add more good examples to $DATA_FILE,
then re-run this script. Dataset quality > step count.
NEXT
