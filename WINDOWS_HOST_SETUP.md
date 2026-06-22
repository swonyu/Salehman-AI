# Windows 11 Pro — always-on Salehman host + remote control

Goal: the **Windows PC runs everything always-on** (the local Salehman LLM brain + the
autonomous Claude Code dev loop), you build/verify the Swift app on the **Mac** when you
want, and you can **remote-control the PC from anywhere** (Mac, phone, any browser).

> ⚠️ **The one thing Windows CANNOT do:** compile/verify this app. It's a macOS/Xcode
> Swift app — `xcodebuild` + SwiftUI + the MainActor-isolation toolchain are Mac-only.
> So on Windows the loop *edits and commits* code but cannot run `tools/typecheck.sh`.
> **You (or Claude on the Mac) pull `main` and build there to catch errors.** See §F.

---

## A. Make the PC stay on forever
Settings → System → Power:
- **Sleep / Screen → Never** (on AC).
- PowerShell (admin): `powercfg /change standby-timeout-ac 0` and `powercfg /change hibernate-timeout-ac 0`.
- Optional: Control Panel → Power Options → choose **High performance**; disable "Fast startup."
- Leave it plugged in. That's it — it's now a 24/7 server.

## B. The brain — Ollama always-on (local, no API keys)
1. Install **Ollama for Windows**: <https://ollama.com/download>. It installs a background
   service on `http://localhost:11434` and **auto-starts at login** (GPU-accelerated if you
   have an NVIDIA GPU — ideal for the always-on PC).
2. Load the Salehman model:
   - If it's on Hugging Face: `ollama pull <hf-repo>` (or `ollama run <model>` once to fetch).
   - If you have a local GGUF + Modelfile: `ollama create salehman -f Modelfile`.
3. Make it reachable on the LAN/Tailscale (so the Mac app can use it): set env var
   `OLLAMA_HOST=0.0.0.0:11434` (System → Environment Variables) and restart Ollama.
4. **In the Mac Salehman app**, point the *Custom server / Ollama* brain at the PC:
   `http://<pc-tailscale-name>:11434`. Now the always-on PC is the brain for the app —
   from anywhere. (Local-first still holds: Ollama needs **no API keys**.)

## C. The dev loop — Claude Code on the PC (WSL2)
1. Install WSL2 + Ubuntu: PowerShell (admin) → `wsl --install` → reboot.
2. In Ubuntu: install Node LTS (`nvm` or `apt`), then
   `npm install -g @anthropic-ai/claude-code`.
3. `claude` once to log in (your Anthropic account — separate from the app's provider keys).
4. Clone the repo there: `git clone <your-remote> "Salehman AI"` (git/`main` is the source
   of truth — every backlog + DEVELOPMENT_LOG carries over).
5. Start the autonomous loop from the running session (or `/loop`). It picks up
   `HARDENING_BACKLOG.md`, `SIGNAL_BACKLOG.md`, `OSRS_BACKLOG.md`, `RANKING_BACKLOG.md`, etc.
   and continues — committing + pushing as it goes.
   - **Caveat:** it will **skip `tools/typecheck.sh`** (no Swift on Windows). Tell it so in
     the loop prompt: *"Windows host — cannot typecheck; make conservative edits, mark Swift
     changes UNVERIFIED, the Mac verifies."* Keep changes small + reviewable.

## D. Remote control from anywhere (free)
1. Install **Tailscale** (<https://tailscale.com>) on the **PC, the Mac, and your phone** —
   same account. Now all three are on a private network reachable anywhere, no port-forwarding.
2. Pick your control surface:
   - **Remote Desktop (Windows 11 Pro has this built in):** Settings → System → Remote Desktop
     → On. From the Mac use *Microsoft Remote Desktop*; from the phone the RD app —
     connect to the PC's Tailscale name. Full desktop from anywhere.
   - **SSH/terminal:** install OpenSSH Server on Windows (or just `ssh` into WSL) →
     `ssh you@<pc-tailscale-name>` → `claude`. Drive the loop from a terminal anywhere.
   - **Browser/phone:** <https://claude.ai/code> to drive Claude Code sessions remotely.

## E. Secrets — what travels and what doesn't
- **Ollama:** no keys (local).
- **Claude Code:** its own login on the PC (do it once with `claude`).
- **The app's provider keys** (NVIDIA/HF/etc.) live in the **macOS Keychain** and stay on
  the Mac — the local-first brain doesn't need them. If you ever paste a key in chat, rotate it.

## F. The verification handoff (important)
Because Windows can't build the Swift app, adopt this rhythm so nothing rots:
1. The PC loop edits + commits + pushes to `main` (Swift changes flagged UNVERIFIED).
2. On the **Mac**, periodically: `git pull` → open in Xcode (⌘B) or run the canonical
   `xcodebuild … build` + `xcodebuild test …`. Fix any breakage (or have Claude-on-Mac do it).
3. Treat the Mac as the **CI gate** before you trust a green build. The PC is the tireless
   author; the Mac is the verifier.

---

### TL;DR
- PC: Ollama (brain) + Claude Code in WSL2 (dev loop), Tailscale, never sleeps → always-on.
- Mac: `git pull` + Xcode build/verify when you want → the truth machine.
- Control from anywhere: Tailscale + Remote Desktop / SSH, or claude.ai/code.
- Everything the loop does is in `main`, so any machine resumes the work; only the Mac proves it compiles.
