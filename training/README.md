# Training Salehman — real fine-tuning with Unsloth

This folder is a **real** workflow for fine-tuning a base LLM into a Salehman-flavored model that the Salehman AI app can run locally via Ollama. No fake progress bars: every command here actually does what it claims.

The plan, in one breath: write conversations in Salehman's voice → fine-tune a 7B base on a free Colab T4 with Unsloth LoRA → export to GGUF → `ollama create salehman` → pin **"Salehman (your model)"** in the app.

---

## 🤔 Why this folder exists

The Salehman AI app is a **client/orchestrator** — it does not contain trainable weights. To get a "Salehman model" that runs **without** Apple Intelligence and **without** depending on qwen, you train your own weights once (here) and then point the app at the result.

Two engines can back the in-app **`.salehman`** brain:
1. **Apple Intelligence** (default) — works immediately with the [Salehman persona](../Salehman%20AI/LLM/SalehmanPersona.swift) as the system prompt. Zero setup. No fine-tune required. ← do this first.
2. **A locally-pulled Ollama model named whatever you set in Settings → "Your model (Salehman)"** (default `salehman`). ← this folder is how you build that model.

If you just want Salehman to *work* right now, turn on Apple Intelligence and you're done. This folder is for the **"I want it to genuinely sound like me / my brand / my training data"** path.

---

## 🧠 Why Unsloth specifically

Vanilla HuggingFace `transformers` won't fit a 7B-parameter LoRA fine-tune in a free Colab T4's 16 GB of VRAM. Unsloth's custom Triton kernels + 4-bit quantization make it fit comfortably, **and** run ~2× faster. That puts the whole "I want my own model" pipeline within reach of a free notebook + the dataset you'll write in a couple of hours — no rented GPUs, no cluster, no fabrication.

**Update (2026-06-05): Unsloth now supports macOS.** Unsloth Studio runs *natively on Apple Silicon* — training, MLX, and GGUF inference are all supported. So you have three routes (in order of "easiest for a Mac user → most scriptable"): **Unsloth Studio on your Mac** (one install command, UI), **Unsloth on a free Colab T4** (no local setup), or the **CLI scripts** in this folder (`build_mac.sh` for MLX-LM, plus the Colab `.py`). Pick whichever fits your taste — they all produce a GGUF that `ollama create salehman` can load.

---

## 📋 The full workflow

### Step 1 — Write a dataset (~1–2 hours, the only real work)

Open [`dataset/salehman_persona.jsonl`](dataset/salehman_persona.jsonl). It's pre-seeded with ~20 examples in the JSONL format Unsloth expects:

```jsonl
{"messages": [{"role": "system", "content": "<persona>"}, {"role": "user", "content": "<q>"}, {"role": "assistant", "content": "<answer in Salehman's voice>"}]}
```

**Add 100–500 of your own examples.** The more they capture the *exact* voice / domain / preferences you want, the more Salehman will sound like you. Quality beats quantity hard here — 200 great examples train a better model than 2000 mid ones.

Tips that genuinely help:
- Include the kinds of questions you ACTUALLY ask (coding, productivity, Arabic↔English, Mac admin, whatever).
- Show the *tone* you want: concise, direct, no "Certainly!" boilerplate, no signoffs.
- Include refusals (clearly harmful asks rejected without moralizing) so the persona stays balanced.
- Mix English and Arabic if you use both — the language-mirror rule needs examples to lock in.

### Step 2 — Fine-tune (pick a route)

#### 2a. Unsloth Studio on your Mac (recommended, easiest for Apple Silicon)

Unsloth Studio runs natively on macOS now — full LoRA training, MLX, and GGUF inference, no Colab round-trip. One install, one launch, all-UI.

```bash
# Install (once) — also works to update later
curl -fsSL https://unsloth.ai/install.sh | sh

# Launch the local UI
unsloth studio -H 0.0.0.0 -p 8888
```

Then in the Studio UI:
1. **Load a base model** (e.g. `unsloth/Qwen2.5-7B-Instruct-bnb-4bit`).
2. **Import data** → point it at `dataset/salehman_persona.jsonl`.
3. **(Optional) refine the dataset** in Data Recipes.
4. **Start training** — recommended preset, or paste a YAML config.
5. **Export GGUF** locally.
6. `ollama create salehman -f Modelfile.salehman` → pin **"Salehman (your model)"** in the app.

Studio runs **100 % offline** (no telemetry, no usage data leaving your Mac) — see Unsloth's FAQ.

#### 2b. Fine-tune on Colab (free, no local install — ~30–60 min)

1. Open Google Colab → New notebook → **Runtime → Change runtime type → T4 GPU**.
2. Upload `salehman_finetune.py` (or copy-paste its contents into cells).
3. Upload your `salehman_persona.jsonl` to Colab's file pane.
4. Run the script top-to-bottom. It will:
   - Install Unsloth.
   - Load `unsloth/Qwen2.5-7B-Instruct-bnb-4bit` (4-bit, ~5 GB).
   - Apply a LoRA adapter (rank 16, alpha 32 — sensible defaults).
   - Train 1–3 epochs over your dataset (SFTTrainer, LR 2e-4).
   - **Merge** the LoRA into base weights.
   - **Export to GGUF** (Q4_K_M — the right balance for an M-series Mac).
5. Download `salehman.gguf` from Colab to this `training/` folder.

The notebook prints honest numbers throughout: loss curves, tokens/sec, ETA. No theatre.

### Step 3 — Import into Ollama (~30 seconds)

From this `training/` folder, with `salehman.gguf` next to `Modelfile.salehman`:

```bash
ollama create salehman -f Modelfile.salehman
```

That's it. `ollama list` should now show `salehman` alongside any other models.

### Step 4 — Wire it up in the app (10 seconds)

1. Open Salehman AI → ⚙️ Settings.
2. **"Your model (Salehman)"** section → make sure the field says `salehman` (matches the name you `ollama create`'d).
3. **Brain** grid → click **"Salehman (your model)"** to pin it.
4. Send a message. It runs *your* model.

The brain header at the top of the chat will read **"Local · salehman (your model)"** when you're talking to it. The dot is brand red.

---

## 🧪 Iterating

After you talk to it for a while you'll notice things you'd change. The whole point of having the dataset checked in is that the loop is **fast**:

1. Add / refine examples in `salehman_persona.jsonl`.
2. Re-run the Colab notebook (LoRA training is cheap — 30 min from scratch each time).
3. `ollama rm salehman && ollama create salehman -f Modelfile.salehman` to swap in the new weights.
4. Send a few messages — does it sound more like you?

Each iteration is real progress, not 20000 fake reps. Two or three iterations is usually all it takes for a 7B base to genuinely lock in a voice.

---

## 🍎 MLX-LM CLI route (headless / scriptable)

> Historical note: this used to be the *only* on-Mac option. Now that Unsloth Studio runs on macOS (see Step 2a above), MLX-LM is one of three Mac routes — pick it if you prefer scriptable / headless / no-UI fine-tuning, or want to embed the whole pipeline in CI. For interactive iteration, Unsloth Studio is faster.

For a no-UI, no-Colab Mac fine-tune, swap Unsloth for `mlx-lm` (Apple's native MLX framework). Same idea, different commands:

```bash
pip install mlx-lm
mlx_lm.lora --model mlx-community/Qwen2.5-7B-Instruct-4bit \
            --train --data ./dataset/salehman_persona.jsonl \
            --iters 1000 --learning-rate 2e-4
mlx_lm.fuse --model mlx-community/Qwen2.5-7B-Instruct-4bit \
            --adapter-path adapters --export-gguf
```

Memory needs ~16 GB unified RAM for 7B. Slower than Colab T4 but stays on-device. The Modelfile + Ollama-import steps are identical from there.

---

## 📊 Honest expectations

What 200–500 good examples + LoRA fine-tune actually delivers:
- ✅ Voice — concise / direct / no boilerplate / consistent.
- ✅ Identity — answers "who are you" as Salehman, not as Qwen.
- ✅ Preferences — formatting habits, language-mirroring, domain leaning.
- ⚠️ **Not** new factual knowledge — fine-tuning teaches style, not facts. For up-to-date info Salehman still needs `web_search` (the tool's wired).
- ⚠️ **Not** improved reasoning on hard problems — the base model's reasoning ceiling stays put. For genuinely smarter behavior you'd swap to a stronger base (Qwen2.5-14B, Llama-3-8B-Instruct) and re-train.

That's the truth. Anyone telling you LoRA gives a 7B "GPT-4-level reasoning" is selling something.

---

## 🧰 Additional files in this folder (merged from `salehman-training/`, 2026-06-05)

| File | What |
|---|---|
| **`TIPS.md`** | The dataset-craft wisdom — what makes a fine-tune actually good (size rules, the five common mistakes, the iteration loop). Read this before you write more rows. |
| `validate_dataset.py` | **Run before training.** Catches silent dataset bugs (role typos, empty content, missing-Arabic warning, dataset-too-small). |
| `build_mac.sh` | One-shot Apple Silicon pipeline: validate → MLX LoRA → fuse → llama.cpp GGUF → `ollama create`. The Mac-native equivalent of the Colab notebook. |
| `finetune_mlx.sh` | Just the MLX-LM steps (called by `build_mac.sh`, also usable standalone). |
| `personas/coder.jsonl` | Themed starter — Salehman as a sharp code assistant. |
| `personas/writer.jsonl` | Themed starter — Salehman as an editor with taste. |
| `personas/tutor.jsonl` | Themed starter — Salehman as a patient teacher. |
| `personas/casual.jsonl` | Themed starter — Salehman as conversational company. |

### Blend the personas into one Salehman
```bash
cat personas/*.jsonl >> dataset/salehman_persona.jsonl   # append, don't overwrite
python3 validate_dataset.py dataset/salehman_persona.jsonl
bash build_mac.sh                                        # or upload to Colab
```
