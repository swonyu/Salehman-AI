# Tips — making Salehman actually good

The training tools are easy. The *dataset* is where models become genuinely good
or genuinely bad. This is the practical-craft side most tutorials skip.

---

## The single most important thing
**Dataset quality and diversity beat dataset size, which beats step count.**

A 300-example dataset of *carefully written, varied* exchanges produces a better
Salehman than a 20,000-example dataset of repetitive, shallow ones — and a much
better one than the same 300 examples run for 20,000 steps (which just memorises).

If you only remember one thing from this file: **add more good examples** before
turning up `--iters`.

---

## Size rules of thumb

| Examples | What you'll get |
|---:|---|
| <50 | Overfit. The model parrots your exact examples and gets *worse* at everything else. |
| 50–300 | A clear persona shift (voice, refusal style, formatting), but knowledge unchanged. |
| 300–2,000 | The sweet spot for a personal assistant. Real shaping of behaviour. |
| 2,000–20,000 | Diminishing returns *unless* you're teaching domain knowledge (a tutor on physics, a coder on a specific stack). |
| >20,000 | You're now doing serious work. Track validation loss, expect epochs not single steps. |

For a personal "Salehman = me" → aim for **400–1,000 high-quality examples** spread across the personas in `personas/`.

---

## What makes one example "good"
Each row in `dataset.jsonl` should answer this checklist:

1. **Voice consistency.** Does the assistant reply sound like *one Salehman* across all your rows? Pick a few traits ("concise", "warm", "never apologises for itself") and hold them.
2. **Specific, not generic.** "I can help you with code." is filler. "Use `.task(id:)` to debounce — it auto-cancels." teaches.
3. **Realistic prompt.** Don't write the prompt you wish users sent. Write the messy, half-formed one they actually will.
4. **Length matches purpose.** A greeting → one line. A code explanation → as long as it needs.
5. **Format consistency.** If half your code answers use fenced blocks and half use inline, the model will become inconsistent too.
6. **One refusal example per ~50 helpful ones.** The model needs to learn what *not* to do. See the game-cheats example in the casual dataset for shape.

---

## The five common mistakes (with fixes)

**1. The "model agrees with everything" trap.**
*Cause:* every example shows the assistant being agreeable.
*Fix:* include 5–10 examples of polite, reasoned disagreement (`"Actually, I'd push back on that — here's why."`).

**2. The "model never says it doesn't know" trap.**
*Cause:* every example shows the assistant succeeding.
*Fix:* a handful of `"I don't have the source for that — can you share it?"`-style rows. Saves you from confident hallucinations.

**3. Mode collapse on opening words.**
*Cause:* most assistant replies start with "Sure!" / "Of course!" / "Here's".
*Fix:* vary openings deliberately. The model imitates patterns, including ones you didn't mean to teach.

**4. Multilingual rule isn't actually trained.**
*Cause:* 100% of your rows are in English.
*Fix:* the `validate_dataset.py` warning flags this. Add ≥10% Arabic rows (or whatever languages your users use) and the language-mirror rule sticks.

**5. The "personality dropout" trap.**
*Cause:* you write 100 examples in one session and the voice subtly drifts after row 50.
*Fix:* re-read all your rows in one sitting before training. If anything reads "off", fix it now — the model will lock that in.

---

## Validating before training (free, fast)

```bash
python validate_dataset.py dataset.jsonl
python validate_dataset.py personas/*.jsonl   # checks all personas
```

This catches the silent bugs that waste training time:
JSON errors, role typos (`asistant`), empty assistant content, no-Arabic-rows,
and dataset-too-small warnings.

---

## Combining personas

You can merge the persona starters into a single dataset:

```bash
cat personas/coder.jsonl personas/writer.jsonl personas/tutor.jsonl personas/casual.jsonl > dataset.jsonl
python validate_dataset.py dataset.jsonl
bash build_mac.sh        # or upload to Colab + run finetune_unsloth_colab.py
```

A blended Salehman that codes, writes, teaches, and is pleasant company.

---

## Iteration loop (this is how Salehman gets better)

1. Train → run in the app → use it for a day.
2. Notice 5–10 things that felt *off* (too long, wrong tone, missed the question).
3. Write 5–10 new examples that demonstrate the *fixed* behaviour.
4. Append to `dataset.jsonl`, re-validate, re-train.
5. Repeat.

This is the real loop. Each pass is small (~30 min on Apple Silicon for a few hundred examples) and each pass *visibly* improves things. After ~5 passes you have a Salehman that feels like yours.
