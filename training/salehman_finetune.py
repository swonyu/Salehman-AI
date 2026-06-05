"""
Salehman fine-tune — real LoRA fine-tuning with Unsloth.

Designed to run top-to-bottom on a free Google Colab T4 (16 GB VRAM). On bigger
GPUs it just goes faster. The output is a `salehman.gguf` file you import into
Ollama as the `salehman` model (see ../Modelfile.salehman and ../README.md).

Each block is fenced with `# %%` so it round-trips cleanly between this .py and
a Jupyter / Colab notebook.

No fake bars: every progress signal in this script comes from real training
(losses, tokens/sec, ETA) printed by Unsloth's SFTTrainer.
"""

# %% ── 1. Install Unsloth (Colab — skip if you already have it) ─────────────
# In Colab, run this cell first. On a local box with Unsloth installed, comment it.
# !pip install --upgrade --no-deps "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
# !pip install --no-deps "trl<0.9.0" peft accelerate bitsandbytes


# %% ── 2. Load a 4-bit base model with Unsloth ───────────────────────────────
from unsloth import FastLanguageModel  # noqa: E402
import torch  # noqa: E402

MAX_SEQ_LEN = 2048        # plenty for chat fine-tunes; bump to 4096 if your data is long
DTYPE = None              # None = auto (bf16 on Ampere+, fp16 on T4)
LOAD_IN_4BIT = True       # the whole point — fits 7B in 16 GB

# Qwen2.5-7B-Instruct is a strong, permissively-licensed base with excellent
# multilingual support (matters because Salehman mirrors Arabic/English).
# Swap to "unsloth/llama-3-8b-Instruct-bnb-4bit" for the Llama flavor.
BASE_MODEL = "unsloth/Qwen2.5-7B-Instruct-bnb-4bit"

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=BASE_MODEL,
    max_seq_length=MAX_SEQ_LEN,
    dtype=DTYPE,
    load_in_4bit=LOAD_IN_4BIT,
)


# %% ── 3. Attach a LoRA adapter ──────────────────────────────────────────────
# Rank 16 / alpha 32 is the sane default for "lock in a voice" fine-tunes.
# Bump rank to 32–64 if you want the model to absorb more dataset patterns
# (uses more VRAM, longer training).
model = FastLanguageModel.get_peft_model(
    model,
    r=16,                                 # LoRA rank
    lora_alpha=32,
    lora_dropout=0.0,
    bias="none",
    target_modules=[                      # the standard "all attn + MLP" set
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    use_gradient_checkpointing="unsloth", # Unsloth's optimized variant
    random_state=42,
    use_rslora=False,
)


# %% ── 4. Load and format the dataset ────────────────────────────────────────
# Expects ./salehman_persona.jsonl with rows like:
#   {"messages": [{"role":"system","content":"…"},{"role":"user","content":"…"},{"role":"assistant","content":"…"}]}
# The README explains the format in detail.
from datasets import load_dataset  # noqa: E402

DATA_PATH = "./dataset/salehman_persona.jsonl"

raw_dataset = load_dataset("json", data_files=DATA_PATH, split="train")
print(f"Loaded {len(raw_dataset)} training examples.")

def format_for_chatml(example):
    """Render the messages list using the base model's own chat template — the
    only way to guarantee the special-token formatting matches inference."""
    text = tokenizer.apply_chat_template(
        example["messages"], tokenize=False, add_generation_prompt=False
    )
    return {"text": text}

dataset = raw_dataset.map(format_for_chatml, remove_columns=raw_dataset.column_names)


# %% ── 5. Train ──────────────────────────────────────────────────────────────
from trl import SFTTrainer  # noqa: E402
from transformers import TrainingArguments  # noqa: E402

# Sensible defaults — adjust if your dataset is much bigger / smaller.
# `num_train_epochs=2` is the sweet spot for 200–500 examples. Bump to 3 for
# tiny datasets (<100), drop to 1 for big ones (>2k) to avoid overfit.
training_args = TrainingArguments(
    output_dir="./outputs",
    per_device_train_batch_size=2,        # T4 fits this with 2048 seq_len
    gradient_accumulation_steps=4,        # effective batch size = 8
    warmup_steps=10,
    num_train_epochs=2,
    learning_rate=2e-4,                   # standard LoRA LR; safe to keep
    fp16=not torch.cuda.is_bf16_supported(),
    bf16=torch.cuda.is_bf16_supported(),
    logging_steps=10,                     # real loss/LR/throughput every 10 steps
    optim="adamw_8bit",                   # memory-light optimizer
    weight_decay=0.01,
    lr_scheduler_type="linear",
    seed=42,
    report_to="none",                     # no W&B, no Tensorboard — keep it clean
    save_strategy="epoch",
    save_total_limit=1,
)

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=MAX_SEQ_LEN,
    args=training_args,
    packing=False,                        # safer for short conversational examples
)

trainer.train()


# %% ── 6. Quick eyeball test ─────────────────────────────────────────────────
# Sanity-check the result inline before exporting. If the answer doesn't sound
# like Salehman here, it won't sound like Salehman in Ollama — iterate the
# dataset before exporting GGUF.
FastLanguageModel.for_inference(model)
sample_prompt = tokenizer.apply_chat_template(
    [{"role": "user", "content": "Who are you and what are you good at?"}],
    tokenize=False,
    add_generation_prompt=True,
)
inputs = tokenizer(sample_prompt, return_tensors="pt").to("cuda")
out = model.generate(**inputs, max_new_tokens=200, do_sample=True, temperature=0.7)
print("\n--- Sample reply (Salehman voice check) ---")
print(tokenizer.decode(out[0], skip_special_tokens=True))


# %% ── 7. Export to GGUF for Ollama ──────────────────────────────────────────
# Q4_K_M is the right balance for an M-series Mac (~4.5 GB resident for 7B,
# negligible quality loss vs the original 4-bit base).
model.save_pretrained_gguf(
    "salehman",                # produces ./salehman/<...>.gguf
    tokenizer,
    quantization_method="q4_k_m",
)

# Then download the produced .gguf file from Colab to the training/ folder on
# your Mac, rename it to `salehman.gguf` if needed, and run:
#
#   ollama create salehman -f Modelfile.salehman
#
# (See ../README.md → Step 3.)
print("\nDone. Download salehman/*.gguf and import into Ollama.")
