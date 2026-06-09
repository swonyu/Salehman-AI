#!/usr/bin/env bash
#
# tools/finetune_local_mlx.sh — local LoRA fine-tune of the in-app coding
# model (qwen2.5-coder:7b) on Apple Silicon via MLX, from a ChatML JSONL
# dataset produced by tools/export_chat_training.py (or the in-app
# "Export Training Data (JSONL)" menu item).
#
# Requires: claude-app/.venv with mlx-lm installed
#   (cd "Salehman AI" && claude-app/.venv/bin/pip install mlx-lm)
#
# Usage:
#   bash tools/finetune_local_mlx.sh [path/to/training.jsonl]
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DATA_FILE="${1:-tools/salehman_training.jsonl}"
MIN_EXAMPLES=50
MODEL="mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"
DATA_DIR="tools/mlx_data"
ADAPTER_DIR="tools/mlx_adapters/salehman"
VENV_BIN="claude-app/.venv/bin"

if [ ! -s "$DATA_FILE" ]; then
  echo "error: $DATA_FILE is empty or missing." >&2
  echo "Run 'python3 tools/export_chat_training.py' first (or use the in-app" >&2
  echo "Export Training Data menu) after chatting with Salehman for a while." >&2
  exit 1
fi

COUNT=$(wc -l < "$DATA_FILE" | tr -d ' ')
if [ "$COUNT" -lt "$MIN_EXAMPLES" ]; then
  echo "error: only $COUNT example(s) in $DATA_FILE — need at least $MIN_EXAMPLES." >&2
  echo "Fine-tuning on this little data memorizes those exact exchanges instead of" >&2
  echo "generalizing, which makes the model worse, not smarter. Keep using" >&2
  echo "Salehman normally, then re-export and re-run this script." >&2
  exit 1
fi

mkdir -p "$DATA_DIR"
cp "$DATA_FILE" "$DATA_DIR/train.jsonl"
# mlx_lm.lora requires a valid.jsonl; reusing train.jsonl is fine for a small
# personal dataset where holding out a slice would leave too little to train on.
cp "$DATA_FILE" "$DATA_DIR/valid.jsonl"

echo "Training on $COUNT examples with $MODEL ..."
"$VENV_BIN/mlx_lm.lora" \
  --model "$MODEL" \
  --train \
  --data "$DATA_DIR" \
  --iters 200 \
  --batch-size 1 \
  --num-layers 8 \
  --adapter-path "$ADAPTER_DIR"

echo
echo "Done. LoRA adapter saved to $ADAPTER_DIR"
echo
echo "Next — fuse the adapter into a full model and convert for Ollama:"
echo "  $VENV_BIN/mlx_lm.fuse --model $MODEL --adapter-path $ADAPTER_DIR --save-path tools/mlx_fused"
echo "  $VENV_BIN/python3 -m mlx_lm.convert --hf-path tools/mlx_fused --mlx-path tools/mlx_fused_gguf --quantize"
echo "  # then write a Modelfile pointing FROM at the converted weights and:"
echo "  ollama create salehman -f tools/Modelfile"
