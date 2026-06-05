#!/usr/bin/env bash
# Salehman fine-tune — MLX-LM (Apple Silicon, runs ON your Mac, no NVIDIA GPU).
# A scriptable/headless Mac route. NOTE: Unsloth Studio now runs on macOS too
# (`curl -fsSL https://unsloth.ai/install.sh | sh && unsloth studio …`) — that's
# the UI route. This script is for CI / no-UI / "just give me a one-liner" use.
# LoRA fine-tune → fuse → GGUF.
set -euo pipefail

# ── 0. Install (once) ───────────────────────────────────────────────────────
pip install -U mlx-lm

# ── 1. Prepare data ──────────────────────────────────────────────────────────
# MLX-LM reads a folder with train.jsonl (+ optional valid.jsonl). It accepts the
# same chat format as dataset.jsonl: {"messages":[{"role","content"}...]}.
mkdir -p data
cp dataset.jsonl data/train.jsonl
# (Recommended: split off ~10% into data/valid.jsonl so you can watch val loss.)

BASE="mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"   # swap for a Qwen/Mistral MLX repo if you like

# ── 2. LoRA fine-tune (adapters land in ./adapters) ──────────────────────────
# --iters is training STEPS, not "times". Keep it sane for a small dataset
# (a few hundred); more data > more iters. 20k iters on few examples overfits.
python -m mlx_lm.lora \
  --model "$BASE" \
  --train \
  --data ./data \
  --batch-size 2 \
  --num-layers 16 \
  --iters 600 \
  --learning-rate 2e-4 \
  --adapter-path ./adapters

# ── 3. Fuse the LoRA adapters back into the base model ───────────────────────
python -m mlx_lm.fuse \
  --model "$BASE" \
  --adapter-path ./adapters \
  --save-path ./salehman-merged

echo "✅ Fused model in ./salehman-merged"

# ── 4. Convert to GGUF for Ollama (needs llama.cpp once) ─────────────────────
cat <<'NEXT'

Now convert ./salehman-merged → salehman.gguf with llama.cpp:

  git clone https://github.com/ggerganov/llama.cpp
  cd llama.cpp && pip install -r requirements.txt
  python convert_hf_to_gguf.py ../salehman-merged \
      --outfile ../salehman.gguf --outtype q4_k_m
  cd ..

Then import + run:

  ollama create salehman -f Modelfile
  ollama run salehman "Who are you?"

Finally: in the app, pick Settings → Brain → "Salehman (your model)".
NEXT
