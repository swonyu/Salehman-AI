# 🦋 Parallel Grok Agents — Full Guide

Run **multiple Grok web agents at once**, straight from your terminal, each doing
real coding work in your repo. They drive **your own signed-in Safari** (so they
sail past Cloudflare — no API key needed), each in its **own browser tab**, all in
parallel, looping on tasks until you stop them.

> TL;DR: `tools/run_parallel_safari.sh "task 1" "task 2" "task 3"` → 3 Grok agents
> start working. Watch with `tools/grok_status.sh --watch`. Stop with
> `pkill -f grok_terminal_bridge.py`.

---

## What is this, exactly?

`grok_terminal_bridge.py` is a bridge that:
1. Opens **grok.com in Safari** and types your task into the chat.
2. Reads Grok's reply, pulls out any **shell commands** Grok suggests (`CMD: …`).
3. **Runs those commands** on your machine and feeds the results back to Grok.
4. Repeats — so Grok can read files, edit them, run tests, etc., like a coding agent.

`run_parallel_safari.sh` launches **several of these at once**, each in its own Safari
tab, each on its own task. It's how one person gets a "team" of Grok agents working
a codebase in parallel.

---

## What you need

- **macOS** with **Safari** (it must be **signed into grok.com** — open Safari, go to
  grok.com, log in once).
- **Python 3** (ships with macOS, or `brew install python`).
- A **SuperGrok** subscription helps a lot — free/low tiers hit the message limit fast
  with multiple agents (see Troubleshooting → rate limits).
- The repo checked out locally (these scripts live in `tools/`).

---

## One-time setup (required — do this once)

Safari blocks automation by default. Turn it on:

1. **Safari → Settings → Advanced →** check **"Show features for web developers."**
2. **Safari → Develop menu → check "Allow JavaScript from Apple Events."**

Without this, the agents can't drive Safari and you'll get "couldn't open tab" errors.

---

## Quick start

From the repo root:

```bash
tools/run_parallel_safari.sh \
  "Add docstrings to every function in tools/grok_parser.py. Only that file. Do NOT git commit." \
  "Create a file tools/hello.py that prints hello. New file only. Do NOT git commit."
```

That launches **2 agents** (one per quoted task). You'll see:

```
🦋 launching 2 parallel SAFARI agents (own tab each · Think on · loop on)
→ creating 2 grok.com tabs (race-free) …
   window id 1234 · tabs: 1 2
  • safari-1  [tab 1 of window id 1234] ⟶  Add docstrings to every function…
  • safari-2  [tab 2 of window id 1234] ⟶  Create a file tools/hello.py…
✅ 2 Safari agents launched.
```

Each task = one agent = one tab. Pass as many tasks as you want.

---

## Watch them work

```bash
tools/grok_status.sh --watch      # live dashboard, refreshes every 2s
tools/grok_status.sh              # one snapshot
tail -f ~/grok_sessions/safari-1.out   # raw log of agent #1
```

The dashboard shows each agent's state, commands run, and current command.

## Stop them

```bash
pkill -f grok_terminal_bridge.py  # stops ALL agents
```

(Closing the Safari tabs does **not** stop the agents — use `pkill`.)

---

## Options (environment variables)

Set these *before* the command, e.g. `MAX_AGENTS=5 MAX_CMDS=100 tools/run_parallel_safari.sh …`

| Variable | Default | What it does |
|----------|---------|--------------|
| `MAX_AGENTS` | **auto** (from RAM) | Hard cap on how many agents run. Auto-detected from your Mac's RAM (16 GB → 3, etc.) so you don't overload it. Set it to override. |
| `MAX_CMDS` | `60` | Max commands **per agent** before it stops. Safety cap so a loop can't run forever. |
| `THINK` | `1` (on) | Grok's deep-reasoning "Think" mode. **`THINK=0`** turns it off — *do this for big fleets*, because Think uses the rate-limited reasoning model and burns quota fast. |
| `STAGGER` | `4` | Seconds between launching each agent. |
| `REPO` | this repo | Working directory the agents operate in. |

**RAM auto-limit:** the launcher reads your Mac's memory and caps agents to a safe
number (reserve ~10 GB for macOS + apps, ~2 GB per heavy grok.com tab). If you ask for
more than is safe, it tells you and caps. Override with `MAX_AGENTS=N`.

---

## Run a single agent (no launcher)

```bash
python3 tools/grok_terminal_bridge.py --auto --yolo --loop \
  --max-commands 60 \
  "Your task here. Do NOT git commit."
```

Flags:
- `--auto` — Safari mode (drives grok.com in Safari).
- `--yolo` — run commands without asking (autonomous). Drop it to get prompted per command.
- `--loop` — after finishing, pull the next task in its lane and keep going.
- `--think` — turn on deep-reasoning mode.
- `--max-commands N` — stop after N commands.
- `--safari-target "tab 3 of window id 42"` — drive a specific tab (the launcher sets this for you).

Run `python3 tools/grok_terminal_bridge.py --help` for everything.

---

## Keep them off your screen

The agents open real Safari tabs. To keep them out of your way, **make a new macOS
Space** (Mission Control → **+**), switch to it, and run the launcher *there* — the tabs
open on that Space, run at full speed, and you flip back to your main desktop.
(Minimizing/hiding the window would throttle them — a separate Space keeps them fast.)

---

## Troubleshooting

**"1 hour before limit is gone" / agents stuck at 0 commands**
→ You hit grok.com's **message rate limit**. Many parallel agents (especially with
`THINK=1`) burn through it fast. The agents now **back off and wait** for the reset
automatically (they won't spin). To avoid it: run **fewer agents**, set **`THINK=0`**,
or upgrade your grok plan. Wait for the reset (it tells you how long), then relaunch.

**"couldn't pre-create Safari tabs" / agents can't drive Safari**
→ You skipped the one-time setup. Safari → Develop → **Allow JavaScript from Apple Events.**

**"grok.com looks logged-out"**
→ Open Safari, go to grok.com, sign in. The agents reuse your logged-in session.

**Mac gets slow / RAM pressure**
→ Each grok.com tab is heavy (hundreds of MB). The RAM auto-limit prevents this, but if
you overrode it, `pkill -f grok_terminal_bridge.py` and run fewer (`MAX_AGENTS=2`).

**Tabs pile up after stopping**
→ Closing the agents doesn't close their tabs. Close them in Safari, or quit/reopen Safari.

---

## ⚠️ Safety — read this

- Agents run with `--yolo` (they execute shell commands automatically). They operate in
  **`REPO`** only, but treat that as **"they can run any command."** Use on repos you can
  recover (committed + pushed).
- They are told **not to `git commit`** — their edits stay in your working tree. **Always
  `git diff` and review before committing.** Grok makes mistakes (wrong files, deletions).
- For parallel safety they each claim a "lane" in `COORDINATION.md` and stay in it — but
  overlapping tasks can still collide. Give each agent a **distinct file/area.**
- Nothing leaves your machine except the chat with grok.com (same as using Grok normally).

---

## How it works (one paragraph)

The bridge injects your task into grok.com via AppleScript + JavaScript, polls the page
for Grok's reply, parses `CMD:` lines out of it, runs them with `subprocess`, and sends
the output back as the next message — looping until Grok says `[[DONE]]` or the command
cap is hit. The launcher pre-creates N tabs **sequentially** (so two agents can't grab
the same tab) and assigns each agent one via `--safari-target`. That's the whole trick.

---

*Questions? Run any script with `--help`, or read `tools/grok_terminal_bridge.py` —
it's commented throughout.*
