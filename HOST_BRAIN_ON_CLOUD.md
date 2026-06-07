# Host Salehman's brain on a cloud GPU

This is the **"app + cloud brain"** setup: the model runs on a rented cloud GPU and
exposes an OpenAI-compatible API; the **Salehman macOS app stays on your Mac** and
talks to it over the internet. The app already supports this — it ships a **vLLM**
brain (and an **Unsloth Studio** brain) that take any OpenAI-compatible URL + an
optional API key. Nothing else to install in the app.

> 💡 **"Free" reality check.** A GPU big enough to serve an LLM 24/7 is **not free**
> anywhere — expect roughly **$0.20–$0.80/hr** (stop the pod when idle). If you want
> *free*, the cloud brains the app already has — **DeepSeek / Groq / OpenRouter** — are
> hosted for you on free/cheap tiers; you just paste a key in Settings. Host-your-own
> below is for running **your own fine-tuned Salehman model**.

---

## Option A — RunPod (recommended; you already use it)

1. **Create a pod**: runpod.io → Deploy → pick a GPU (a 24 GB card like an **RTX A5000 / 4090**
   serves a 7–14B model comfortably). Choose a **vLLM** template, or the base
   "RunPod PyTorch" template and install vLLM yourself.

2. **Serve the model with auth** (in the pod's terminal). Pick any secret token:

   ```bash
   pip install vllm
   vllm serve Qwen/Qwen2.5-Coder-7B-Instruct \
     --host 0.0.0.0 --port 8000 \
     --api-key sk-salehman-PICK-A-LONG-RANDOM-TOKEN
   ```

   To serve **your own fine-tuned Salehman** model, point `vllm serve` at the merged
   HF weights you produced in [`salehman-training/`](salehman-training/) (the
   `03_merge.py` output), e.g. `vllm serve /workspace/salehman_fused --api-key …`.

3. **Expose the port.** In RunPod, add **HTTP port 8000**; RunPod gives you a public
   proxy URL like:

   ```
   https://<your-pod-id>-8000.proxy.runpod.net
   ```

4. **Connect the app**: Salehman → **Settings → vLLM (local or cloud server)**:
   - **Endpoint URL**: `https://<your-pod-id>-8000.proxy.runpod.net/v1`
   - **Model name**: exactly what you passed to `vllm serve` (e.g. `Qwen/Qwen2.5-Coder-7B-Instruct` or `/workspace/salehman_fused`)
   - **vLLM API key**: the `sk-salehman-…` token from step 2 → **Save** (stored in your Mac's Keychain)
   - **Test connection** → should say *Connected ✓*
   - Then pick **vLLM** in the **Brain** grid.

That's it — every chat now runs on your cloud brain, and because it's
OpenAI-compatible it also gets the **terminal tool-calling** the app adds (it runs
commands on *your Mac*, not the pod).

---

## Option B — any other GPU host

Vast.ai, Lambda, Modal, Together, etc. all work the same way: get a public
`https://…/v1` URL, serve with `vllm serve … --api-key …`, paste URL + key into
Settings → vLLM. (Unsloth Studio's row works identically if you prefer it.)

## Security (do this)

- **Always** start a public endpoint with `--api-key`. Without it, anyone who finds
  the URL can run your GPU on your dime.
- The key is stored only in your Mac's **Keychain** (never in source or logs).
- **Stop/terminate the pod when you're done** — you're billed while it runs.

## Want a phone app too?

The current app is macOS. The same cloud brain can back an **iOS** build of this
SwiftUI app (shared code, add an iOS target) distributed via **TestFlight** — ask and
I'll scaffold the iOS target.
