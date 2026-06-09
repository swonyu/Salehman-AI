#!/usr/bin/env python3
"""
grok_terminal_bridge.py — let grok.com (the WEB app, your subscription) drive your
Mac's terminal. NO xAI API key and NO Grok credits are used: the brain is the web
chat you already pay for; this script is just the *hands*.

How it works (the only way a web chatbot can ever touch your machine):
    grok.com  --you/automation-->  Grok's reply (text, with ```run fences)
                                          |
                                   THIS SCRIPT parses the command,
                                   runs it locally behind a HARD safety
                                   floor + approval, captures the output,
                                          |
    grok.com  <--you/automation--  the command output (so Grok continues)

Two modes:
  • manual   (default) — you copy-paste between grok.com and this script. Robust,
               no browser automation, no scraping, no ToS gray area. Works today.
  • auto     — drives grok.com via the `agent-browser` CLI (install separately).
               Convenience only; fragile (breaks when grok.com's UI changes).

SAFETY MODEL (owner wants full power — NOTHING is refused outright):
  • There is NO hard block. sudo, rm, disk tools, everything — they all RUN.
  • The ONLY guard is a confirmation prompt: commands that can damage your Mac or
    escalate ("dangerous" — the rm -rf/sudo/disk/fork-bomb/redirect families,
    mirrored from the app's ToolPolicy.CommandRisk) are SHOWN to you and need a
    single y/N before running. This is NOT a refusal — it runs the instant you
    type y. It exists because the command source is a web chatbot that can
    HALLUCINATE a destroyer; one keystroke stops `rm -rf /` from a bad parse
    silently wiping your machine. It does not stop YOU from doing anything.
  • --auto-approve : safe commands run with no prompt; dangerous ones still confirm.
  • --yolo         : run EVERYTHING with no prompts at all (your explicit choice).
  • Every command runs with a timeout and an output cap.

You are handing command execution to text produced by a web chatbot. Read each
command before approving it (or use --yolo and own the risk).
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import textwrap
import time

# ─────────────────────────────────────────────────────────────────────────────
# Safety floor — ported VERBATIM from Salehman AI/Tools/ToolPolicy.swift
# (CommandRisk). Keep in sync with that file; it is the single source of truth.
# ─────────────────────────────────────────────────────────────────────────────

BLOCKED_SUBSTRINGS = [
    "rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf ~/", "rm -fr /", "rm -rf .", "rm -rf *",
    ":(){", "fork()",
    "mkfs", "diskutil erasedisk", "diskutil erasevolume", "diskutil reformat",
    "diskutil partitiondisk", "dd if=", "of=/dev/",
    "/dev/disk", "/dev/rdisk", "/dev/sd", "> /dev/", ">/dev/",
    "> /etc/", ">/etc/", "csrutil disable", "spctl --master-disable", "nvram ",
    "chmod -r 000", "chmod 000", "chmod -r ", "chown -r", "chgrp -r",
]

BLOCKED_LEADING = {
    "shutdown", "reboot", "halt", "poweroff",
    "sudo", "su", "doas",
    "killall", "mkfs", "fdisk", "newfs_apfs", "newfs_hfs", "diskutil",
    "eval", "exec", "source", "launchctl", "chgrp",
}

RISKY_MARKERS = [
    "rm ", "rmdir", "mv ", "trash", "delete", "truncate", "format",
    ">",
    "sudo", "doas", "chmod", "chown", "chgrp",
    "kill ", "killall", "git push", "git reset --hard", "git clean",
    "python -c", "python3 -c", "node -e", "ruby -e", "perl -e", "php -r",
    "bash -c", "sh -c", "zsh -c", "osascript",
    "tee ", "cp ", "ln ", "scp ", "ditto ", "curl ", "wget ",
    "defaults write", "crontab", "launchctl", "systemsetup",
    "swift package", "swift build", "swift test",
]

_PIPED_INTERPRETERS = {
    "sh", "bash", "zsh", "ksh", "fish", "python", "python3",
    "node", "ruby", "perl", "php", "osascript", "tclsh",
}

_SEGMENT_SPLIT = re.compile(r"[;|&\n\r`\x00]")


def _segments(command: str) -> list[str]:
    """Operator-aware split mirroring ToolPolicy.isBlocked: collapse the two-char
    operators to a sentinel first, then split on control operators."""
    normalized = (command.replace("&&", "\x00").replace("||", "\x00").replace("|&", "\x00"))
    return _SEGMENT_SPLIT.split(normalized)


def catastrophic_match(command: str) -> str | None:
    """Return the matched token for a command in the can-wreck-your-Mac family
    (rm -rf /, disk erase, fork bomb, write /dev or /etc, csrutil disable, sudo, …),
    else None. NOT a refusal — used only to warn LOUDER before the y/N prompt.
    Two layers: dangerous substrings anywhere, then dangerous leading token per segment."""
    lower = command.lower()
    for pattern in BLOCKED_SUBSTRINGS:
        if pattern in lower:
            return pattern
    for seg in _segments(lower):
        seg = seg.strip()
        if not seg:
            continue
        first = seg.split()[0] if seg.split() else ""
        name = first.split("/")[-1] if first else first
        if name in BLOCKED_LEADING:
            return name
    return None


def _pipes_into_interpreter(lower: str) -> bool:
    for seg in lower.replace("||", "\x00").split("|")[1:]:
        seg = seg.strip()
        if not seg:
            continue
        first = seg.split()[0] if seg.split() else ""
        name = first.split("/")[-1] if first else first
        if name in _PIPED_INTERPRETERS:
            return True
    return False


def looks_risky(command: str) -> bool:
    """True for commands that ALWAYS require confirmation (mutate/escalate/exfiltrate)."""
    lower = command.lower()
    if any(marker in lower for marker in RISKY_MARKERS):
        return True
    return _pipes_into_interpreter(lower)


# ─────────────────────────────────────────────────────────────────────────────
# Local executor — mirrors Salehman AI/Tools/ShellTool.swift Shell.run
# ─────────────────────────────────────────────────────────────────────────────

OUTPUT_CAP = 8000
DEFAULT_TIMEOUT = 60


def run_command(command: str, cwd: str, timeout: int = DEFAULT_TIMEOUT) -> tuple[int, str, bool]:
    """Run via /bin/zsh -c, capturing combined stdout/stderr. Returns (exit, output, timed_out)."""
    try:
        proc = subprocess.run(
            ["/bin/zsh", "-c", command],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        timed_out = False
        code = proc.returncode
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or "") + (e.stderr or "") if isinstance(e.stdout, str) else ""
        out += f"\n(timed out after {timeout}s; process terminated)"
        timed_out = True
        code = -1
    if len(out) > OUTPUT_CAP:
        out = out[:OUTPUT_CAP] + "\n…(output truncated at 8KB)"
    if not out.strip():
        out = "(no output before timeout)" if timed_out else "(no output)"
    return code, out, timed_out


# ─────────────────────────────────────────────────────────────────────────────
# Grok-reply parsing — commands live inside ```run … ``` fences; [[DONE]] ends it.
# ─────────────────────────────────────────────────────────────────────────────

# Match ANY fenced code block — ```run, ```bash, ```sh, ```zsh, ```shell, ```console,
# or a bare ``` — and tolerate a MISSING closing fence (capture to end of text). This
# survives however grok.com renders the block.
_FENCE = re.compile(r"```[^\n`]*\n(.*?)(?:```|\Z)", re.DOTALL)
DONE_SENTINEL = "[[DONE]]"


def parse_commands(grok_text: str) -> list[str]:
    """Pull the command(s) out of Grok's reply, robustly:
    1) every fenced code block (any tag; missing closing fence is OK); else
    2) NO fence at all → treat the whole pasted text as ONE command. That's exactly
       what grok.com's 'Copy' button gives you (the bare command, no fence markup).
    The y/N confirmation always shows the command before it runs, so a stray prose
    paste just gets declined rather than executed."""
    blocks = [m.strip() for m in _FENCE.findall(grok_text) if m.strip()]
    if blocks:
        return blocks
    body = grok_text.strip()
    if not body or DONE_SENTINEL in body:
        return []
    return [body]


def is_done(grok_text: str) -> bool:
    # Guard against our own PRIMER being echoed back — it literally contains the
    # phrase "Do NOT output [[DONE]]", which would otherwise trip a false finish.
    if DONE_SENTINEL not in grok_text:
        return False
    if "NOT YOUR CLOUD SANDBOX" in grok_text or "Do NOT output" in grok_text:
        return False
    return True


PRIMER = textwrap.dedent(f"""\
    You are operating my REAL Mac's terminal. After each command I paste back its real output.

    RULES — follow exactly (this is NOT a request to design a bridge or relay; just DO it):
    • Reply with EXACTLY ONE shell command, inside a ```bash code block. Nothing else —
      no prose, no `$` prompt, no commentary in or around it.
    • Wait for my pasted output before the next command. One command at a time.
    • This is a real macOS machine (paths like /Users/saleh/...), NOT a cloud sandbox —
      no prior state exists; don't claim you already did anything.
    • Don't claim any result until you've seen its real pasted output.
    • When the task is fully done and proven by real output, reply with only {DONE_SENTINEL}.
    • Any command runs; destructive ones (sudo, rm, disk tools) may ask me for one y/N.

    Your FIRST command must be exactly:
    pwd && uname -a && whoami

    Then work toward this task:
    """)


def _primer_for(cwd: str, task: str) -> str:
    """PRIMER + a working-directory note (commands already run in `cwd`, so Grok
    shouldn't cd or use ~ in quotes — zsh won't expand it) + the task."""
    return (PRIMER
            + f"\nNOTE: every command ALREADY runs inside: {cwd}\n"
              "So do NOT `cd` there, and never put ~ inside quotes (zsh won't expand it) —\n"
              "use absolute paths or paths relative to that directory.\n\n"
            + task)


# ─────────────────────────────────────────────────────────────────────────────
# Approval + command execution shared by both modes
# ─────────────────────────────────────────────────────────────────────────────

def gate_and_run(command: str, cwd: str, auto_approve: bool, yolo: bool) -> str:
    """Confirm as needed (NEVER refuse), run, and return a Grok-readable report.
    Nothing is blocked — dangerous commands just get a louder prompt unless --yolo."""
    catastrophic = catastrophic_match(command)          # token or None — warn louder, not a refusal
    dangerous = catastrophic is not None or looks_risky(command)

    if yolo:
        print(f"\n  ▶︎ (yolo) running: {command}")
    else:
        needs_prompt = dangerous or not auto_approve
        if needs_prompt:
            if catastrophic:
                print(f"\n  ☢️  CAN DAMAGE YOUR MAC (matched \"{catastrophic}\"):\n      {command}")
            elif dangerous:
                print(f"\n  ⚠️  dangerous command from Grok:\n      {command}")
            else:
                print(f"\n  ▶︎ command from Grok:\n      {command}")
            try:
                answer = input("      run it? [y/N] ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                answer = "n"
            if answer not in ("y", "yes"):
                print("      ✗ skipped.")
                return (f"$ {command}\nThe user DECLINED to run this command. It was NOT run. "
                        f"Acknowledge and propose a different approach.")
        else:
            print(f"\n  ▶︎ auto-running: {command}")

    code, output, timed_out = run_command(command, cwd=cwd)
    report = f"$ {command}\n"
    if timed_out:
        report += "(timed out; process terminated)\n"
    report += f"exit code: {code}\n---\n{output}"
    print(f"      exit {code}" + (" (timed out)" if timed_out else ""))
    return report


# ─────────────────────────────────────────────────────────────────────────────
# Mode: manual relay (default) — copy/paste between grok.com and here.
# ─────────────────────────────────────────────────────────────────────────────

def _read_pasted_block(prompt: str) -> str:
    """Read a multi-line paste until a lone 'EOF' line (or Ctrl-D)."""
    print(prompt)
    print("  (Easiest: click the Copy button on Grok's command block, paste here, press Ctrl-D.")
    print("   Or paste Grok's whole reply. End the paste with Ctrl-D or a lone 'EOF' line.)")
    lines: list[str] = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line.strip() == "EOF":
            break
        lines.append(line)
    return "\n".join(lines)


def run_manual(task: str, cwd: str, auto_approve: bool, yolo: bool) -> None:
    sep = "─" * 72
    print(sep)
    print("STEP 1 — paste this whole message into grok.com as your first message:")
    print(sep)
    print(_primer_for(cwd, task))
    print(sep)

    while True:
        reply = _read_pasted_block("\nSTEP 2 — paste Grok's reply here:")
        if not reply.strip():
            print("(empty — type 'quit' to stop, or paste a reply)")
            if input("> ").strip().lower() in ("quit", "q", "exit"):
                return
            continue

        commands = parse_commands(reply)
        if not commands:
            if is_done(reply):
                print("\n✅ Grok signalled DONE. Bridge finished.")
                return
            print("\n  (no ```run block found in that reply — nothing to run.)")
            if is_done(reply):
                return
            continue

        reports = [gate_and_run(c, cwd=cwd, auto_approve=auto_approve, yolo=yolo) for c in commands]
        blob = "\n\n".join(reports)
        print("\n" + sep)
        print("STEP 3 — paste this output back into grok.com:")
        print(sep)
        print(blob)
        print(sep)

        if is_done(reply):
            print("\n✅ Grok signalled DONE. Bridge finished.")
            return


# ─────────────────────────────────────────────────────────────────────────────
# Mode: auto (agent-browser) — drives grok.com directly, no copy-paste.
#
# Design goals given grok.com's DOM is unknown and changes:
#   • Read replies by TEXT DIFF, not CSS selectors — capture page innerText, send,
#     poll until it stops changing (Grok finished streaming), return the suffix
#     after our message. Survives UI changes.
#   • Type via `keyboard inserttext` (CDP text injection → React sees it) so the
#     multi-line primer goes in WITHOUT triggering Enter-to-send; one `press Enter`
#     then sends it.
#   • Persist login via a dedicated Chrome profile (AGENT_BROWSER_PROFILE) so you
#     log into grok.com once, headed, and stay logged in across runs.
# This is a v1 written without live testing (the safety classifier blocks the
# author from running it) — expect to tune selectors/timing together.
# ─────────────────────────────────────────────────────────────────────────────

_GROK_SESSION = "grok-bridge"   # one named session reused by every call (see _ab)
_GROK_URL = "https://grok.com"
# Generic composer selector — grok.com uses a textarea or a contenteditable box.
_COMPOSER_JS = "document.querySelector('textarea, [contenteditable=\"true\"]')"


def _ab(args: list[str], input_text: str | None = None, timeout: int = 90) -> subprocess.CompletedProcess:
    """Run an agent-browser subcommand. EVERY call passes `--headed` + the SAME
    `--session-name`, so all our separate `agent-browser` invocations attach to ONE
    visible, persistent browser. Without this, each command spawned its own browser
    and the prior window closed (the "opens then closes" bug) — and login never stuck.
    `--session-name` also persists the grok.com login across script runs."""
    base = ["agent-browser", "--headed", "--session-name", _GROK_SESSION]
    try:
        return subprocess.run(base + args, input=input_text,
                              capture_output=True, text=True, timeout=timeout)
    except FileNotFoundError:
        sys.exit("agent-browser not found. Install: npm i -g agent-browser && agent-browser install")
    except subprocess.TimeoutExpired:
        return subprocess.CompletedProcess(args, 1, "", "timeout")


def _ab_eval(js: str, timeout: int = 40) -> str:
    """Evaluate JS in the page via `eval --stdin` (no shell escaping headaches)."""
    return (_ab(["eval", "--stdin"], input_text=js, timeout=timeout).stdout or "").strip()


def _grok_page_text() -> str:
    return _ab_eval("document.body.innerText")


# Logged-out grok.com shows "Sign in" / "Sign up" in its nav; a signed-in account
# does not. (We do NOT key on the cookie banner / "log in" — those persist/are too
# broad and made the old check loop forever.)
_LOGGED_OUT_MARKERS = ("sign up to continue", "sign up for free", "sign up", "sign in")

# grok.com page chrome (nav, sidebar, banners) to strip from a scraped reply so the
# command parser sees Grok's actual message, not the UI furniture.
_GROK_NOISE = {
    "imagine", "sign in", "sign up", "new chat", "search", "build", "new", "projects",
    "new project", "see all", "history", "skills and connectors", "ask anything",
    "expert", "share", "continue your conversation", "chat history", "generate files",
    "cookies settings", "reject all", "accept all cookies", "reject all accept all cookies",
    "use skills & connectors", "make stunning ai images & videos", "sign up for free",
    "sign up to continue seamlessly with grok's full power",
}


def _strip_grok_chrome(text: str) -> str:
    """Drop grok.com nav/banner lines from scraped page text."""
    keep = [ln for ln in text.splitlines() if ln.strip() and ln.strip().lower() not in _GROK_NOISE]
    return "\n".join(keep).strip()


def _grok_logged_in() -> bool:
    """Logged in == a composer exists AND the signup wall isn't showing.
    agent-browser uses its OWN Chrome profile, so the first run is logged out until
    you sign in once in its window (the profile then persists it)."""
    if not _ab_eval(f"!!({_COMPOSER_JS})").lower().endswith("true"):
        return False
    txt = _grok_page_text().lower()
    return not any(m in txt for m in _LOGGED_OUT_MARKERS)


def _ensure_logged_in(max_attempts: int = 6) -> bool:
    """Prompt the user to sign in, with a CAP so it can't loop forever (the bug you
    saw). Returns True if logged in, False to abort auto mode."""
    for _ in range(max_attempts):
        if _grok_logged_in():
            return True
        print("\n⚠️  grok.com looks logged-OUT (or no chat box is visible).")
        print("    A browser window should have opened — it's agent-browser's OWN Chrome,")
        print("    SEPARATE from your normal one. If you can't see it, it may be headless/stuck.")
        ans = input("    Sign in there + open a new chat, then press Enter — or 'skip' / 'q': ").strip().lower()
        if ans in ("q", "quit"):
            return False
        if ans == "skip":
            return True
        _ab(["reload"], timeout=60)
        _ab(["wait", "--load", "networkidle"], timeout=60)
    print("\n🛑 Still can't detect a logged-in grok.com. The agent-browser window is probably")
    print("   not visible/usable. Try `agent-browser doctor`, or just use manual mode (always works).")
    return False


def _grok_send(text: str) -> None:
    """Focus the composer, inject the (multi-line) text without submitting, then send."""
    _ab_eval(f"(()=>{{const e={_COMPOSER_JS}; if(e){{e.focus();}} return !!e;}})()")
    _ab(["keyboard", "inserttext", text])
    _ab(["press", "Enter"])


def _distinctive_tail(text: str) -> str:
    """A short, searchable needle from the END of what we sent, to locate it in the
    page text and slice off everything after it (= Grok's reply)."""
    for line in reversed(text.strip().splitlines()):
        s = line.strip()
        if len(s) >= 8:
            return s[:80]
    return text.strip()[-80:]


def _grok_wait_reply(sent_text: str, settle: float = 2.0, stable_needed: int = 2,
                     timeout: int = 180) -> str:
    """Poll page text until it stops changing (Grok done streaming), then return the
    text AFTER our sent message. DOM-agnostic."""
    needle = _distinctive_tail(sent_text) if sent_text else ""
    deadline = time.time() + timeout
    last, cur, stable = "", "", 0
    while time.time() < deadline:
        time.sleep(settle)
        cur = _grok_page_text()
        if cur and cur == last:
            stable += 1
            if stable >= stable_needed:
                break
        else:
            stable, last = 0, cur
    if needle:
        idx = cur.rfind(needle)
        if idx >= 0:
            return _strip_grok_chrome(cur[idx + len(needle):])
    return _strip_grok_chrome(cur)


def run_auto(task: str, cwd: str, auto_approve: bool, yolo: bool) -> None:
    import shutil
    if shutil.which("agent-browser") is None:
        sys.exit("auto mode needs agent-browser: npm i -g agent-browser && agent-browser install")

    print("🌐 opening grok.com (a VISIBLE browser window should appear and STAY open) …")
    _ab(["open", _GROK_URL], timeout=90)
    _ab(["wait", "--load", "networkidle"], timeout=60)

    if not _ensure_logged_in():
        return

    sent = _primer_for(cwd, task)
    print("→ sending primer + task to grok.com …")
    _grok_send(sent)

    while True:
        reply = _grok_wait_reply(sent)
        preview = reply[:1200] + ("…" if len(reply) > 1200 else "")
        print("\n── Grok replied ──\n" + preview + "\n──────────────────")

        cmds = parse_commands(reply)
        if not cmds:
            if is_done(reply):
                print("\n✅ Grok signalled DONE. Bridge finished.")
                return
            ans = input("No command found in that reply. [r]e-read / [q]uit? ").strip().lower()
            if ans in ("q", "quit"):
                return
            sent = ""   # re-read the whole latest page text next loop
            continue

        reports = [gate_and_run(c, cwd=cwd, auto_approve=auto_approve, yolo=yolo) for c in cmds]
        sent = "\n\n".join(reports)
        print("→ sending command output back to grok.com …")
        _grok_send(sent)
        if is_done(reply):
            print("\n✅ Grok signalled DONE. Bridge finished.")
            return


# ─────────────────────────────────────────────────────────────────────────────
# Mode: autofix — build the app; if it fails, drive Grok to fix it; rebuild; loop
# until green. THE BUILD IS RUN BY THIS SCRIPT (not Grok), so Grok cannot fake a
# green build — the real compiler is the judge. Stops on: green / no-progress /
# max rounds. Safe-ish because a bad edit just fails the next build and is visible;
# still: COMMIT FIRST so you can `git restore` if a round makes a mess.
# ─────────────────────────────────────────────────────────────────────────────

_BUILD_CMD = [
    "xcodebuild", "-scheme", "Salehman AI", "-destination", "platform=macOS",
    "-configuration", "Debug", "CODE_SIGNING_ALLOWED=NO", "build",
]


def _run_build(cwd: str, timeout: int = 600) -> tuple[bool, str]:
    """Run the canonical build. Returns (succeeded, deduped error summary)."""
    try:
        r = subprocess.run(_BUILD_CMD, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return False, f"(build timed out after {timeout}s)"
    except FileNotFoundError:
        return False, "(xcodebuild not found — is this run on a Mac with Xcode?)"
    out = (r.stdout or "") + (r.stderr or "")
    if "** BUILD SUCCEEDED **" in out:
        return True, ""
    errors = [ln for ln in out.splitlines() if ": error:" in ln or ln.strip().startswith("error:")]
    summary = "\n".join(dict.fromkeys(errors))[:4000]   # dedupe (ordered), cap size
    return False, summary or "(build failed but no 'error:' lines were captured)"


AUTOFIX_PRIMER = textwrap.dedent("""\
    You are fixing BUILD ERRORS in a real macOS Xcode/Swift 6 project, through a local bridge.
    ⚠️ THIS IS A REAL MAC, not your cloud sandbox. Paths are /Users/saleh/... .
    I (the bridge) run the build MYSELF and paste you the errors — you cannot fake a green build.

    PROTOCOL — follow EXACTLY:
    • Work ONE step at a time: issue ONE command in a ```run fence, then STOP and wait for output.
    • INSPECT before editing — read the failing file/region first, e.g.:
      ```run
      sed -n '1,80p' "Salehman AI/path/File.swift"
      ```
    • EDIT in place with a precise command (python3 -c with a read/replace/write, or sed). Change
      the MINIMUM needed to fix the specific error. Do not rewrite whole files.
    • Do NOT run xcodebuild / swift build yourself — after your edit I rebuild and paste the result.
    • When I paste "BUILD SUCCEEDED", reply with ONLY [[DONE]].
    • Never claim a fix worked until I paste a successful build. Adapt if an error persists.

    Here are the CURRENT build errors:
    """)


def run_autofix(cwd: str, auto_approve: bool, yolo: bool, max_rounds: int = 25) -> None:
    import shutil
    if shutil.which("agent-browser") is None:
        sys.exit("autofix needs agent-browser: npm i -g agent-browser && agent-browser install")

    print("⚠️  Recommend `git commit` first so you can revert if a round makes a mess.")
    print("🔨 building the app to see if there's anything to fix …")
    ok, errors = _run_build(cwd)
    if ok:
        print("✅ build already SUCCEEDS — nothing to fix.")
        return
    print(f"❌ build failing. Errors:\n{errors}\n")

    print("🌐 opening grok.com (a VISIBLE browser window should appear and STAY open) …")
    _ab(["open", _GROK_URL], timeout=90)
    _ab(["wait", "--load", "networkidle"], timeout=60)
    if not _ensure_logged_in():
        return

    sent = AUTOFIX_PRIMER + errors
    print("→ sending build errors to grok.com …")
    _grok_send(sent)

    last_errors = errors
    strikes = 0
    for rnd in range(1, max_rounds + 1):
        reply = _grok_wait_reply(sent)
        print(f"\n── round {rnd}/{max_rounds} · Grok replied ──\n{reply[:1000]}\n──────────")
        cmds = parse_commands(reply)

        if cmds:
            reports = [gate_and_run(c, cwd=cwd, auto_approve=auto_approve, yolo=yolo) for c in cmds]
            print("🔨 rebuilding …")
            ok, errors = _run_build(cwd)
            if ok:
                _grok_send("BUILD SUCCEEDED ✅ — the project compiles. Reply with only [[DONE]].")
                print("\n🎉 BUILD SUCCEEDED — autofix done.")
                return
            if errors == last_errors:
                strikes += 1
                if strikes >= 3:
                    print("\n🛑 No progress for 3 rounds (same errors). Stopping — Grok is stuck.")
                    print(f"Remaining errors:\n{errors}")
                    return
            else:
                strikes = 0
                last_errors = errors
            sent = "\n\n".join(reports) + "\n\nBUILD STILL FAILING. Current errors:\n" + errors
            print("→ sending rebuild result back to grok.com …")
            _grok_send(sent)
        elif is_done(reply):
            print("🔨 Grok says done — verifying with a build …")
            ok, errors = _run_build(cwd)
            if ok:
                print("\n🎉 BUILD SUCCEEDED — autofix done.")
                return
            sent = "Not done yet — the build STILL FAILS. Current errors:\n" + errors
            _grok_send(sent)
        else:
            print("(no command and not done — nudging Grok)")
            sent = "I didn't see a ```run command. Inspect or edit ONE thing, in a ```run fence. Errors:\n" + errors
            _grok_send(sent)

    print(f"\n🛑 Hit max {max_rounds} rounds without a green build. Stopping.")
    print(f"Remaining errors:\n{errors}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Drive grok.com (web) as a safe local terminal agent.")
    ap.add_argument("task", nargs="*", help="What you want Grok to do on your Mac.")
    ap.add_argument("--mode", choices=["manual", "auto", "autofix"], default="manual",
                    help="manual = copy/paste (robust); auto = drive grok.com; "
                         "autofix = build→let Grok fix errors→rebuild until green.")
    ap.add_argument("--cwd", default=os.path.expanduser("~"),
                    help="Working directory for commands (default: your home dir).")
    ap.add_argument("--auto-approve", action="store_true",
                    help="Skip the prompt for SAFE commands. Dangerous ones still confirm. Use with care.")
    ap.add_argument("--yolo", action="store_true",
                    help="Run EVERYTHING with no prompts, including sudo/rm/disk tools. Full send — own the risk.")
    args = ap.parse_args()

    task = " ".join(args.task).strip()
    # autofix has its own goal (make the build green) — no task needed. Others do.
    if args.mode != "autofix" and not task:
        try:
            task = input("What should Grok do on your Mac? ").strip()
        except (EOFError, KeyboardInterrupt):
            sys.exit("\n(no task given)")
        if not task:
            sys.exit("(no task given)")

    cwd = os.path.abspath(os.path.expanduser(args.cwd))
    if not os.path.isdir(cwd):
        sys.exit(f"--cwd is not a directory: {cwd}")

    approval = "YOLO (no prompts)" if args.yolo else ("auto-safe" if args.auto_approve else "confirm dangerous")
    print(f"🌉 grok-terminal-bridge · mode={args.mode} · cwd={cwd} · approval={approval}")
    if args.mode == "autofix":
        run_autofix(cwd=cwd, auto_approve=args.auto_approve, yolo=args.yolo)
    elif args.mode == "auto":
        run_auto(task, cwd=cwd, auto_approve=args.auto_approve, yolo=args.yolo)
    else:
        run_manual(task, cwd=cwd, auto_approve=args.auto_approve, yolo=args.yolo)


if __name__ == "__main__":
    main()
