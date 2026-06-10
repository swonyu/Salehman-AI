# Used by the Salehman AI team (Grok Victor - Head Orchestrator) to build the premium AI Personal Trainer app. Current focus: Phase 1 Core Intelligence. Keep it simple, no over-engineering early.
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
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import textwrap
import time
import uuid
from datetime import datetime
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Terminal colours — auto-disabled when stdout is not a tty (e.g. piped)
# ─────────────────────────────────────────────────────────────────────────────

_USE_COLOR = sys.stdout.isatty()

def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text

def _green(t: str)  -> str: return _c("92", t)
def _yellow(t: str) -> str: return _c("93", t)
def _cyan(t: str)   -> str: return _c("96", t)
def _red(t: str)    -> str: return _c("91", t)
def _dim(t: str)    -> str: return _c("2",  t)
def _bold(t: str)   -> str: return _c("1",  t)

# ─────────────────────────────────────────────────────────────────────────────
# Session state — shared across the bridge lifetime
# ─────────────────────────────────────────────────────────────────────────────

_SESSION_ID     = uuid.uuid4().hex[:10]   # unique ID for this run (used as boundary marker)
_SESSION_MARKER = f"[B:{_SESSION_ID}]"   # boundary tag embedded in every outgoing turn
_SESSION_START  = time.time()
_SEEN_CMDS:     set[str] = set()          # dedup: warn if Grok repeats a command
_LOG_PATH:      Path | None = None        # set by --log flag
_SHUTDOWN       = False                   # set by Ctrl+C handler
_VERIFY:        bool = False              # --verify: append git state to each feedback turn
_MAX_COMMANDS   = 0                       # --max-commands: hard cap on commands run (0 = unlimited)
_CMD_COUNT      = 0                       # commands executed so far this run


def _elapsed() -> str:
    s = int(time.time() - _SESSION_START)
    return f"{s // 60}m{s % 60:02d}s"


def _log(msg: str, level: str = "info") -> None:
    """Timestamped, coloured log line — also writes to log file if --log is set."""
    icons = {"info": _cyan("→"), "ok": _green("✓"), "warn": _yellow("!"), "err": _red("✗")}
    ts   = datetime.now().strftime("%H:%M:%S")
    line = f"[{ts}|{_elapsed()}] {icons.get(level, '·')} {msg}"
    print(line)
    if _LOG_PATH:
        plain = re.sub(r"\033\[[0-9;]*m", "", line)
        with _LOG_PATH.open("a") as fh:
            fh.write(plain + "\n")


# ─────────────────────────────────────────────────────────────────────────────
# Machine-readable trail — so Salehman (read_grok_session / ingest daemon) and a
# multi-agent dashboard can SEE EVERYTHING without scraping prose:
#   ~/grok_sessions/<session>.jsonl      — append-only event log (one JSON/line)
#   ~/grok_sessions/<session>.status.json — live, overwritten heartbeat
# ─────────────────────────────────────────────────────────────────────────────

def _sessions_dir() -> Path:
    d = Path.home() / "grok_sessions"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _events_path() -> Path:
    return _sessions_dir() / f"{_GROK_SESSION}-{_SESSION_ID[:6]}.jsonl"


def _status_path() -> Path:
    return _sessions_dir() / f"{_GROK_SESSION}-{_SESSION_ID[:6]}.status.json"


def _emit_event(kind: str, **fields) -> None:
    """Append one structured event for Salehman to ingest. Never raises."""
    try:
        rec = {
            "ts": datetime.now().isoformat(timespec="seconds"),
            "elapsed": _elapsed(),
            "session": _GROK_SESSION,
            "session_id": _SESSION_ID,
            "label": _LABEL,
            "lane": _COORDINATE_LANE,
            "pid": os.getpid(),
            "kind": kind,
            **fields,
        }
        with _events_path().open("a") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass  # observability must never break the run


def _write_status(state: str, **fields) -> None:
    """Overwrite the live status heartbeat (one per running bridge). Never raises."""
    try:
        rec = {
            "session": _GROK_SESSION, "session_id": _SESSION_ID, "label": _LABEL,
            "lane": _COORDINATE_LANE, "pid": os.getpid(), "state": state,
            "commands": _CMD_COUNT, "max_commands": _MAX_COMMANDS or None,
            "elapsed": _elapsed(), "updated": datetime.now().isoformat(timespec="seconds"),
            "log": str(_LOG_PATH) if _LOG_PATH else None,
            "events": str(_events_path()),
            **fields,
        }
        _status_path().write_text(json.dumps(rec, ensure_ascii=False, indent=2))
    except Exception:
        pass


def _notify(title: str, body: str) -> None:
    """macOS notification — silently ignored on non-Mac or if osascript missing."""
    subprocess.run(
        ["osascript", "-e", f'display notification {repr(body)} with title {repr(title)}'],
        capture_output=True,
    )


def _handle_sigint(sig: int, frame) -> None:  # type: ignore[type-arg]
    global _SHUTDOWN
    _SHUTDOWN = True
    print(_yellow("\n  Ctrl+C — will stop after current command…"))


signal.signal(signal.SIGINT, _handle_sigint)

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

OUTPUT_CAP      = 8000
DEFAULT_TIMEOUT = 60
SEND_CHUNK_SIZE = 4096   # max chars per injection (grok.com drops very long pastes)


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

# Match executable fenced code blocks (```run, ```bash, ```sh, ```zsh, ```shell,
# bare ```) but NOT ```diff blocks — those are handled by _DIFF_FENCE below.
_FENCE = re.compile(r"```(?!diff\b)[^\n`]*\n(.*?)(?:```|\Z)", re.DOTALL)
# Match ```diff blocks separately so their content can be written to a temp file
# and applied via git apply rather than run as a shell command.
_DIFF_FENCE = re.compile(r"```diff\b[^\n]*\n(.*?)(?:```|\Z)", re.DOTALL | re.IGNORECASE)
DONE_SENTINEL = "[[DONE]]"
DONE_SENTINEL_V12 = "=== TASK_COMPLETED_SUCCESSFULLY ==="  # Protocol v1.2 alternate


_PROSE_INDICATORS = re.compile(
    r"^(i'?ll|i will|let me|i need to|first|next|now|okay|sure|great|here|to |this |the |we |you )",
    re.IGNORECASE,
)
_LOOKS_LIKE_CMD = re.compile(r"^[\w./\-\"'`${}()\[\]\\|<>&;: ]+$", re.MULTILINE)


_CMD_PREFIX = re.compile(r"^CMD:\s*(.+)$", re.MULTILINE)

# First non-empty token of a valid shell command starts with a path character,
# a common built-in name, or a variable assignment. Used to reject prose-in-fences.
_SHELL_FIRST_TOKEN = re.compile(
    r"^\s*("
    r"[\./~\$]|"                   # path / $VAR
    r"[A-Z_]+=|"                   # VAR=value export
    r"git|cd|ls|cat|sed|grep|awk|python3?|swift|xcode|bash|zsh|sh\s|"
    r"echo|mkdir|rm|mv|cp|find|curl|wget|tee|chmod|diff|patch|"
    r"make|env|export|unset|head|tail|wc|sort|tr|cut|pbcopy|open|"
    r"xcodebuild|swift\s|pod\s|npm\s|yarn\s|ruby\s|perl\s|php\s"
    r")",
    re.IGNORECASE,
)


def _block_looks_like_shell(block: str) -> bool:
    """Return True if the first non-empty, non-comment line looks like a shell command.
    Filters out prose blocks Grok sometimes wraps in code fences
    (e.g. 'Analyzing the terminal output • 5s')."""
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        return bool(_SHELL_FIRST_TOKEN.match(line))
    return False


def _collect_diff_cmds(reply: str, session_id: str) -> list[str]:
    """Extract ```diff blocks, write each to a temp file, return git-apply commands.

    Keeps diff content out of the shell executor — a raw unified diff is NOT a
    valid shell command and would cause spurious errors if run via /bin/zsh -c.
    """
    cmds = []
    for i, raw in enumerate(_DIFF_FENCE.findall(reply)):
        content = raw.strip()
        if not content:
            continue
        diff_path = f"/tmp/grok_diff_{session_id}_{i}.patch"
        Path(diff_path).write_text(content + "\n", encoding="utf-8")
        cmds.append(f"bash tools/apply_grok_diff.sh {shlex.quote(diff_path)}")
    return cmds


# grok.com UI noise — suggestion chips and upsell banners that bleed into page text.
# Two patterns: _UI_NOISE_INLINE for inline removal (banner appears mid-line because
# the CSS overlay is positioned over code text), _UI_NOISE for whole-line drops.
_UI_NOISE_INLINE = re.compile(
    r"Upgrade to SuperGrok\s*|SuperGrok\s*",
    re.IGNORECASE,
)
_UI_NOISE = re.compile(
    r"Upgrade to SuperGrok|SuperGrok|"
    r"Thinking about your request|"
    r"^\s*Explore\s|^\s*Investigate\s|^\s*Regenerate\s|"
    r"^\s*Are you satisfied|^\s*Like\s*$|^\s*Dislike\s*$|"
    r"^\s*Pin\s*$|^\s*Move to Project\s*$|^\s*Delete Chat\s*$|"
    r"Replace TASK_DONE with|Replace.*\[\[DONE\]\]",
    re.IGNORECASE | re.MULTILINE,
)


def _clean_ui_noise(text: str) -> str:
    """Strip grok.com UI overlay noise so it never reaches parse_commands.

    Two-pass: (1) inline substitution removes banners that bleed mid-line
    (e.g. 'sed -n Upgrade to SuperGrok\'1,25p\''); (2) whole-line removal
    drops chip/suggestion lines that survived the first pass.
    """
    if not text:
        return text
    text = _UI_NOISE_INLINE.sub("", text)   # pass 1: inline removal
    return "\n".join(                        # pass 2: whole-line removal
        line for line in text.splitlines()
        if not _UI_NOISE.search(line)
    )


def parse_commands(grok_text: str) -> list[str]:
    """Extract shell commands from Grok's reply.

    Priority:
    1. CMD: prefix lines  — what the auto-safari primer asks for (no fences, no
       auto-execution by SuperGrok's sandbox).
    2. Fenced code blocks — fallback for manual mode / old prompts.
    3. Short single-line text with no prose markers — grok.com Copy-button output.
    """
    grok_text = _clean_ui_noise(grok_text)
    # Priority 1: CMD: prefix
    cmd_lines = [m.strip() for m in _CMD_PREFIX.findall(grok_text) if m.strip()]
    if cmd_lines:
        return cmd_lines

    # Priority 2: fenced code blocks — only those whose first line looks like shell
    blocks = [m.strip() for m in _FENCE.findall(grok_text)
              if m.strip() and _block_looks_like_shell(m.strip())]
    if blocks:
        return blocks

    body = grok_text.strip()
    if not body or DONE_SENTINEL in body:
        return []
    lines = [l for l in body.splitlines() if l.strip()]
    if len(lines) > 3:
        return []
    if _PROSE_INDICATORS.match(body):
        return []
    if not _block_looks_like_shell(body):
        return []
    return [body]


def is_done(grok_text: str) -> bool:
    """True only when Grok signals completion ([[DONE]] or v1.2 sentinel), not an echo."""
    sentinels = (DONE_SENTINEL, DONE_SENTINEL_V12)
    lines = grok_text.splitlines()
    found = any(line.strip() in sentinels for line in lines)
    if not found:
        return False
    # Guard: primer/UI noise contains [[DONE]] in explanatory text — don't false-trigger
    if "NOT YOUR CLOUD SANDBOX" in grok_text or "Do NOT output" in grok_text:
        return False
    # Guard: primer marker present → this is an echo, not a real done signal
    if _SESSION_MARKER in grok_text and len(grok_text) > 2000:
        return False
    return True


PRIMER = textwrap.dedent(f"""\
    You are operating my REAL Mac terminal. I paste back real output. \
You NEVER run anything yourself — no built-in runner, no sandbox, no DeepSearch.

    YOUR ENTIRE REPLY = one line only:
        CMD: <shell command>

    No prose. No markdown. No code fences. No headers. No commentary. Just CMD:.

    RULES — breaking any = task failure:
    1. ONE CMD: per reply. Stop. Wait for real output before the next command.
    2. READ before editing — cat the target file first; never write from memory.
    3. VERIFY each edit — git diff <file> after every write to confirm the change.
    4. No assumed results — never state something worked without seeing its output.
    5. DONE check — before signalling done, run:
       CMD: git diff --stat && git status --porcelain
       If git shows zero changes, the task is NOT complete. Issue more commands.
    6. Signal done — reply with ONLY this exact line (nothing else):
       {DONE_SENTINEL}

    Your FIRST reply (nothing else, no explanation):
    CMD: pwd && uname -a && whoami

    Task:
    """)


def _primer_for(cwd: str, task: str) -> str:
    """PRIMER + a working-directory note (commands already run in `cwd`, so Grok
    shouldn't cd or use ~ in quotes — zsh won't expand it) + the task."""
    coord = ""
    if _COORDINATE_LANE:
        coord = (
            "\nCOORDINATION — you are ONE of several agents working this repo in parallel.\n"
            f"Your lane label is: {_COORDINATE_LANE}\n"
            "BEFORE editing ANY file:\n"
            "  CMD: cat COORDINATION.md\n"
            "Then append a claim row to the 'Live Lane Board' naming the EXACT files you\n"
            f"will touch, with lane '{_COORDINATE_LANE}'. NEVER edit a file another lane has\n"
            "claimed (one driver per file). Stay strictly in your lane. Keep the build GREEN\n"
            "(xcodebuild ... build) before handing a file back. When finished, set your row\n"
            "to 'released' in COORDINATION.md. Treat a red build from another lane's WIP as\n"
            "NOT yours — note it on the board, don't fix it.\n"
            "GIT SAFETY (you share ONE working tree with the other agents):\n"
            "  • Do NOT `git commit`, `git push`, `git checkout`, `git switch`, `git reset`,\n"
            "    `git stash`, or create/delete branches. Leave your edits in the working tree;\n"
            "    the human reviews and commits. Use `git diff <file>` to verify — never commit.\n"
            "  • When appending to COORDINATION.md, append a single line/row; do not rewrite\n"
            "    or reorder existing rows (other agents are editing it too).\n"
        )
    return (PRIMER
            + f"\nNOTE: every command ALREADY runs inside: {cwd}\n"
              "So do NOT `cd` there, and never put ~ inside quotes (zsh won't expand it) —\n"
              "use absolute paths or paths relative to that directory.\n"
              "IMPORTANT: The task below may contain ```run / ```bash examples as CONTEXT.\n"
              "Do NOT copy that format. YOUR responses must always use the CMD: prefix,\n"
              "never code fences. One CMD: line, then stop and wait.\n"
            + coord
            + "\n"
            + task)


# ─────────────────────────────────────────────────────────────────────────────
# Approval + command execution shared by both modes
# ─────────────────────────────────────────────────────────────────────────────

def gate_and_run(command: str, cwd: str, auto_approve: bool, yolo: bool) -> str:
    """Confirm as needed (NEVER refuse), run, and return a Grok-readable report.
    Nothing is blocked — dangerous commands just get a louder prompt unless --yolo."""
    global _CMD_COUNT, _SHUTDOWN
    # Runaway guard — cap total commands (matters most for unattended parallel YOLO).
    if _MAX_COMMANDS and _CMD_COUNT >= _MAX_COMMANDS:
        _SHUTDOWN = True
        _emit_event("aborted", reason="max-commands", command=command, limit=_MAX_COMMANDS)
        _write_status("aborted", reason="max-commands")
        _log(f"hit --max-commands ({_MAX_COMMANDS}); stopping.", "warn")
        return (f"$ {command}\nSTOPPED: reached the --max-commands limit ({_MAX_COMMANDS}). "
                f"This command was NOT run. End the session now with {DONE_SENTINEL}.")

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
                _emit_event("declined", command=command, dangerous=dangerous)
                return (f"$ {command}\nThe user DECLINED to run this command. It was NOT run. "
                        f"Acknowledge and propose a different approach.")
        else:
            print(f"\n  ▶︎ auto-running: {command}")

    _CMD_COUNT += 1
    code, output, timed_out = run_command(command, cwd=cwd)
    report = f"$ {command}\n"
    if timed_out:
        report += "(timed out; process terminated)\n"
    report += f"exit code: {code}\n---\n{output}"
    print(f"      exit {code}" + (" (timed out)" if timed_out else ""))
    _emit_event("command", n=_CMD_COUNT, command=command, exit_code=code,
                timed_out=timed_out, dangerous=dangerous,
                output_excerpt=(output or "")[:600])
    _write_status("running", last_command=command, last_exit=code)
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

_GROK_SESSION = "grok-bridge"   # agent-browser session name; override with --session-name.
                                # Distinct names ⇒ isolated browsers ⇒ safe PARALLEL bridges.
_LABEL = "grok-bridge"          # short human tag for prompts/logs (set from --label/--session-name)
_COORDINATE_LANE: str | None = None  # when set (--coordinate), Grok must claim this lane in COORDINATION.md
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
        if sys.stdin.isatty():
            ans = input("    Sign in there + open a new chat, then press Enter — or 'skip' / 'q': ").strip().lower()
            if ans in ("q", "quit"):
                return False
            if ans == "skip":
                return True
        else:
            # Detached / parallel launch — no terminal to prompt at. Poll instead
            # of crashing on EOF: give you time to sign into the opened window.
            _log(f"no TTY — waiting 30s for grok.com sign-in (attempt {_+1}/{max_attempts})", "warn")
            time.sleep(30)
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


# ─────────────────────────────────────────────────────────────────────────────
# Mode: auto-safari — drives grok.com via osascript + Safari's built-in
# JavaScript bridge. No agent-browser needed; your real signed-in Safari
# session passes Cloudflare's bot checks automatically.
#
# ONE-TIME SETUP (only needed once):
#   Safari → Settings → Advanced → check "Show features for web developers"
#   Then: Safari → Develop menu → "Allow JavaScript from Apple Events"
# ─────────────────────────────────────────────────────────────────────────────

# Which Safari window this agent drives. "1" = frontmost (single-agent default).
# In parallel Safari mode each agent opens its OWN window and sets this to
# "id <n>" so 5 agents never fight over one window. Targeting a window by id
# works even when it's NOT frontmost — no focus-stealing between agents.
_SAFARI_OWN_WINDOW = False   # --safari-window: open + drive this agent's OWN tab
_THINK = False               # --think: enable grok.com's deep-reasoning "Think" mode
# AppleScript reference for THIS agent's grok tab. Single-agent default = the
# frontmost window's current tab. In parallel mode each agent opens its OWN TAB
# (Safari makes new documents as tabs, not windows) and targets it by index, e.g.
# "tab 3 of window id 603" — so N agents never drive the same tab.
_SAFARI_TARGET = "current tab of window 1"

def _safari_eval(js: str, timeout: int = 30) -> str:
    """Run JS in this agent's Safari window via osascript. Returns the string result."""
    import json as _json
    wrapped = f"(function(){{try{{return String({js})}}catch(e){{return 'err:'+e.message}}}})()"
    osa = f'tell application "Safari" to do JavaScript {_json.dumps(wrapped)} in {_SAFARI_TARGET}'
    try:
        r = subprocess.run(["osascript", "-e", osa],
                           capture_output=True, text=True, timeout=timeout)
        return (r.stdout or "").strip()
    except subprocess.TimeoutExpired:
        return ""
    except Exception as e:
        return f"(osascript error: {e})"


def _safari_open_url(url: str) -> None:
    subprocess.run(["osascript", "-e",
                    f'tell application "Safari"\n  activate\n  open location "{url}"\nend tell'],
                   capture_output=True)


def _safari_open_own_window(url: str) -> bool:
    """Open a NEW Safari TAB to `url` and pin THIS agent to it by index, captured
    at creation (e.g. "tab 3 of window id 603"). Safari opens new documents as
    TABS in one window (not separate windows), so per-agent isolation is per-tab,
    not per-window — that's what stops 5 agents driving the same tab. Returns True
    on success. Targeting a specific tab works without it being frontmost."""
    global _SAFARI_TARGET
    # Capture window id + the new tab's index in ONE osascript (atomic), so a
    # sibling agent's tab-open can't shift what we read between create and capture.
    osa = (
        'tell application "Safari"\n'
        f'  make new document with properties {{URL:"{url}"}}\n'
        '  set wid to id of window 1\n'
        '  set tidx to (index of current tab of window 1)\n'
        '  return ((wid as string) & "," & (tidx as string))\n'
        'end tell'
    )
    r = subprocess.run(["osascript", "-e", osa], capture_output=True, text=True, timeout=30)
    out = (r.stdout or "").strip()
    parts = out.split(",")
    if len(parts) == 2 and parts[0].lstrip("-").isdigit() and parts[1].isdigit():
        _SAFARI_TARGET = f"tab {parts[1]} of window id {parts[0]}"
        _log(f"own grok tab: {_SAFARI_TARGET}", "ok")
        return True
    _log(f"couldn't open own Safari tab: {r.stderr.strip() or out}", "warn")
    return False


def _safari_navigate(url: str) -> None:
    """Point this agent's window at `url` (reuse the own-window instead of opening
    a new one for each task)."""
    subprocess.run(["osascript", "-e",
                    f'tell application "Safari" to set URL of {_SAFARI_TARGET} to "{url}"'],
                   capture_output=True)


def _safari_enable_think() -> str:
    """Best-effort: turn ON grok.com's 'Think' (deep-reasoning) mode by clicking
    its toggle. grok.com's UI changes often, so this matches several label/aria
    variants and is non-fatal if it can't find the button."""
    return _safari_eval("""
    (function(){
      var nodes = Array.from(document.querySelectorAll('button,[role="switch"],[role="button"],a'));
      for (var el of nodes){
        var t = ((el.textContent||'') + ' ' + (el.getAttribute('aria-label')||'')).toLowerCase();
        if (t.includes('think')){
          var on = el.getAttribute('aria-pressed')==='true' || el.getAttribute('aria-checked')==='true';
          if(!on){ el.click(); return 'think-on'; }
          return 'think-already-on';
        }
      }
      return 'think-toggle-not-found';
    })()
    """)


def _safari_page_text() -> str:
    return _safari_eval("document.body.innerText")


def _safari_scroll_bottom() -> None:
    """Scroll grok.com to bottom so the latest message is visible."""
    _safari_eval("window.scrollTo(0, document.body.scrollHeight)")


def _safari_new_chat() -> None:
    """Click grok.com's New Chat button to start a fresh conversation."""
    _safari_eval("""
    (function() {
      var els = Array.from(document.querySelectorAll('button, a'));
      for (var el of els) {
        var t = (el.textContent || el.innerText || '').trim();
        if (t === 'New Chat' || t === 'New chat') { el.click(); return 'clicked'; }
      }
      return 'not-found';
    })()
    """)
    time.sleep(1.5)


def _safari_is_generating() -> bool:
    """True while Grok is still streaming a response (stop button visible)."""
    result = _safari_eval("""
    (function() {
      var sel = 'button[aria-label*="Stop"], button[data-testid*="stop"], '
              + 'button[aria-label*="stop"], button[aria-label*="Cancel generating"]';
      if (document.querySelector(sel)) return 'yes';
      var txt = document.body.innerText || '';
      if (txt.includes('Stop generating') || txt.includes('Cancel')) return 'maybe';
      return 'no';
    })()
    """)
    return result in ("yes", "maybe")


def _safari_detect_error() -> str | None:
    """Return a short error description if grok.com shows an error state, else None."""
    txt = _safari_page_text().lower()
    if "rate limit" in txt or "too many requests" in txt:
        return "rate limit"
    if "sign in" in txt or "sign up" in txt:
        return "logged out"
    if "something went wrong" in txt or "error occurred" in txt:
        return "page error"
    if "cloudflare" in txt or "you are unable to access" in txt:
        return "cloudflare block"
    return None


def _safari_get_last_message() -> str | None:
    """Extract just Grok's last reply from the DOM (multiple selector strategies)."""
    result = _safari_eval("""
    (function() {
      // Strategy 1 (HIGHEST PRIORITY): Last rendered code block.
      // Browsers strip backtick fences from HTML — reconstruct a fake fence so
      // parse_commands() can extract the command reliably.
      var pres = document.querySelectorAll('pre');
      if (pres.length > 0) {
        var lastPre = pres[pres.length - 1];
        var codeEl = lastPre.querySelector('code') || lastPre;
        // textContent (not innerText) avoids CSS overlay contamination — innerText
        // includes floating UI banners ("Upgrade to SuperGrok") positioned over code.
        var codeText = (codeEl.textContent || '').trim();
        if (codeText && codeText.length > 1) {
          // Check full page for [[DONE]] so we don't miss the finish signal
          var pageText = document.body.innerText || '';
          var doneSuffix = pageText.includes('[[DONE]]') ? '\n[[DONE]]' : '';
          return 'PRE:```\n' + codeText + '\n```' + doneSuffix;
        }
      }
      // Strategy 2: data-testid / role selectors for the last assistant message
      var selectors = [
        '[data-testid*="message-content"]',
        '[data-testid*="bot-message"]',
        '[data-testid*="assistant"]',
        '[data-testid*="response"]',
        '[role="article"]',
        '[role="listitem"]',
      ];
      for (var sel of selectors) {
        var els = document.querySelectorAll(sel);
        if (els.length > 0) {
          var last = els[els.length - 1];
          if (last.innerText && last.innerText.trim().length > 20)
            return 'DOM:' + last.innerText;
        }
      }
      return 'FALLBACK';
    })()
    """, timeout=10)

    if not result or result == "FALLBACK" or result.startswith("err:"):
        return None
    for prefix in ("DOM:", "PRE:"):
        if result.startswith(prefix):
            return result[len(prefix):]
    return result


def _safari_inject_and_send(text: str, retries: int = 3) -> bool:  # noqa: C901
    """
    Inject text into grok.com and send. Two-tier strategy:

    Strategy A — truly background (no focus steal):
      JS execCommand('insertText') fills the composer; geometric button scan
      finds + clicks Send. Runs via 'do JavaScript' which works without Safari
      being frontmost.

    Strategy B — quick-switch fallback (~1.2s focus steal, then restores):
      pbcopy + System Events Cmd+A/V/Enter, then immediately re-activates
      whatever app was frontmost. User sees a brief flash, not a permanent switch.
    """
    import json as _j

    for attempt in range(retries):
        if attempt > 0:
            print(f"  ↺ inject retry {attempt}/{retries-1}…")
            time.sleep(1.5)

        # ── Strategy A: pure JS, zero focus steal ────────────────────────────
        inject_js = f"""
(function() {{
  var el = document.querySelector('textarea,[contenteditable="true"]');
  if (!el) return 'no-el';
  el.focus();
  var r = document.createRange();
  r.selectNodeContents(el);
  var s = window.getSelection();
  s.removeAllRanges();
  s.addRange(r);
  var ok = document.execCommand('insertText', false, {_j.dumps(text)});
  if (ok) return 'exec-ok';
  if (el.tagName === 'TEXTAREA') {{
    var setter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
    setter.call(el, {_j.dumps(text)});
    el.dispatchEvent(new Event('input', {{bubbles:true}}));
    return 'setter-ok';
  }}
  el.textContent = {_j.dumps(text)};
  el.dispatchEvent(new Event('input', {{bubbles:true}}));
  return 'tc-ok';
}})()
"""
        inject_result = _safari_eval(inject_js, timeout=15)
        if inject_result != 'no-el':
            time.sleep(0.7)

            # Geometric send-button detection — no hardcoded selector needed
            send_js = """
(function() {
  var composer = document.querySelector('textarea,[contenteditable="true"]');
  if (!composer) return 'no-composer';
  var cR = composer.getBoundingClientRect();

  // Try explicit attribute selectors first
  var explicit = document.querySelector(
    'button[data-testid*="send"],button[aria-label*="Send"],button[aria-label*="send"],button[type="submit"]'
  );
  if (explicit && !explicit.disabled) { explicit.click(); return 'explicit'; }

  // Geometric: find enabled button to the right of and near the composer
  var best = null, bestScore = -Infinity;
  document.querySelectorAll('button').forEach(function(b) {
    if (b.disabled) return;
    var br = b.getBoundingClientRect();
    if (br.width < 5 || br.height < 5) return;
    var vertOk  = Math.abs((br.top + br.height/2) - (cR.top + cR.height/2)) < cR.height + 24;
    var horizOk = br.left >= cR.right - 24;
    if (horizOk && vertOk) {
      var score = -(br.left - cR.right);
      if (score > bestScore) { bestScore = score; best = b; }
    }
  });
  if (best) { best.click(); return 'geometric'; }

  // Last resort: last enabled non-hidden button on page
  var all = Array.from(document.querySelectorAll('button'))
    .filter(function(b){ return !b.disabled && b.getBoundingClientRect().width > 10; });
  if (all.length) { all[all.length - 1].click(); return 'last-btn'; }
  return 'no-send';
})()
"""
            send_result = _safari_eval(send_js, timeout=10)
            if send_result not in ('no-send', 'no-composer', '', None):
                time.sleep(0.3)
                _log(f"sent via JS ({inject_result}+{send_result}) — no focus stolen", "ok")
                return True
            print(f"  ⚠️  JS send failed ({send_result}) — falling back to quick-switch")

        # ── Strategy B: quick-switch (steals focus ~1.2s then restores) ──────
        subprocess.run(["pbcopy"], input=text, text=True)
        time.sleep(0.2)
        osa = (
            'try\n'
            '  set prevApp to name of first application process whose frontmost is true\n'
            'on error\n'
            '  set prevApp to "Finder"\n'
            'end try\n'
            'tell application "Safari" to activate\n'
            'delay 0.4\n'
            'tell application "System Events"\n'
            '  keystroke "a" using {command down}\n'
            '  delay 0.1\n'
            '  keystroke "v" using {command down}\n'
            '  delay 0.9\n'
            '  key code 36\n'
            'end tell\n'
            'delay 0.2\n'
            'tell application prevApp to activate\n'
        )
        r = subprocess.run(["osascript", "-e", osa], capture_output=True, text=True)
        if r.returncode == 0:
            time.sleep(0.4)
            return True
        print(f"  ⚠️  System Events: {(r.stderr or '').strip() or 'failed (grant Accessibility to Terminal in System Settings → Privacy)'}")

    print("  ✗ inject failed after all retries")
    return False


def _safari_stream_reply(marker: str, timeout: int = 240) -> str:
    """
    Stream Grok's reply live to the terminal as it generates.
    Uses the session marker to find the reply boundary.
    Falls back to DOM extraction and page-text slicing.
    Returns the final complete reply.
    """
    deadline = time.time() + timeout

    # Phase 1: wait for generation to start (stop-button appears)
    print(_cyan("  ⏳"), end=" ", flush=True)
    start_limit = time.time() + 25
    started = False
    while time.time() < start_limit:
        if _safari_is_generating():
            started = True
            break
        # Also check if a reply already appeared (instant responses)
        quick = _safari_get_last_message()
        if quick and len(quick) > 30:
            started = True
            break
        time.sleep(0.8)
        print(".", end="", flush=True)

    if not started:
        _log("no generation detected — reading page as-is", "warn")
    else:
        print(_cyan(" streaming ▸ "), end="", flush=True)

    # Phase 2: incremental print while generating
    last_reply      = ""
    last_page       = ""
    last_progress_t = time.time()   # reset whenever reply grows — timeout if stuck
    NO_PROGRESS_SEC = 45

    while time.time() < deadline:
        if _SHUTDOWN:
            break
        generating = _safari_is_generating()

        # Try DOM extraction (precise), fall back to page-text+marker.
        # Clean noise before length comparison and display so overlay text
        # (e.g. "Upgrade to SuperGrok" banners) doesn't corrupt the diff.
        raw = _safari_get_last_message()
        if raw:
            raw = _clean_ui_noise(raw)
        if raw and len(raw) > len(last_reply):
            new_chars = raw[len(last_reply):]
            print(new_chars, end="", flush=True)
            last_reply = raw
            last_progress_t = time.time()
        elif not raw:
            page = _safari_page_text()
            if page != last_page:
                idx = page.rfind(marker) if marker else -1
                if idx >= 0:
                    current = _strip_grok_chrome(page[idx + len(marker):])
                    if len(current) > len(last_reply):
                        print(current[len(last_reply):], end="", flush=True)
                        last_reply = current
                        last_progress_t = time.time()
                last_page = page

        if not generating:
            time.sleep(1.5)
            # Final read
            final = _safari_get_last_message()
            if final and len(final) > len(last_reply):
                print(final[len(last_reply):], end="", flush=True)
                last_reply = final
            print()
            break

        # No-progress watchdog — Grok stopped streaming but stop-button vanished
        if time.time() - last_progress_t > NO_PROGRESS_SEC:
            _log(f"no new content for {NO_PROGRESS_SEC}s — assuming generation complete", "warn")
            print()
            break

        time.sleep(0.5)

    if not last_reply:
        page = _safari_page_text()
        idx  = page.rfind(marker)
        last_reply = _strip_grok_chrome(page[idx + len(marker):] if idx >= 0 else page)

    return last_reply


def _safari_logged_in() -> bool:
    txt = _safari_page_text().lower()
    if not txt:
        return False
    return not any(m in txt for m in _LOGGED_OUT_MARKERS)


def _git_verify(cwd: str) -> str:
    """Run git status + diff --stat and return a compact block to send back to Grok."""
    _, status, _ = run_command("git status --porcelain", cwd=cwd)
    _, diff_stat, _ = run_command("git diff --stat", cwd=cwd)
    parts = [f"git status --porcelain:\n{status.strip()}" if status.strip()
             else "git status: clean — no uncommitted changes"]
    if diff_stat.strip():
        parts.append(f"git diff --stat:\n{diff_stat.strip()}")
    return "--- git state after last command ---\n" + "\n\n".join(parts)


def run_auto_safari(task: str, cwd: str, auto_approve: bool, yolo: bool,  # noqa: C901
                    new_chat: bool = True) -> None:
    global _SHUTDOWN
    _SHUTDOWN = False

    _log(_bold(f"session {_SESSION_ID}  task: {task!r}"))
    # Open/reuse the right Safari TAB. In parallel mode each agent drives its OWN
    # tab (by index) so N can run side-by-side without clashing on one tab.
    if _SAFARI_OWN_WINDOW:
        if _SAFARI_TARGET == "current tab of window 1":      # not yet claimed a tab
            _log("opening this agent's own Safari tab …")
            if not _safari_open_own_window(_GROK_URL):
                _safari_open_url(_GROK_URL)
        else:
            _log(f"reusing own grok tab: {_SAFARI_TARGET} …")
            _safari_navigate(_GROK_URL)
    else:
        _log("opening grok.com in Safari …")
        _safari_open_url(_GROK_URL)
    time.sleep(4)

    # Ensure logged in
    for _ in range(6):
        if _SHUTDOWN:
            return
        err = _safari_detect_error()
        if err:
            _log(f"grok.com error: {err}", "err")
            if err == "cloudflare block":
                _log("Cloudflare blocked the session. Try opening Safari manually first.", "err")
                return
        if _safari_logged_in():
            break
        _log("grok.com looks logged-out — sign into grok.com in Safari.", "warn")
        if sys.stdin.isatty():
            try:
                ans = input("   Press Enter when ready, or 'q' to quit: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                return
            if ans in ("q", "quit"):
                return
        else:
            # detached / parallel launch: no terminal to prompt at — poll instead
            _log("no TTY — waiting 10s for grok.com sign-in", "warn")
            time.sleep(10)
        time.sleep(2)
    else:
        _log("Could not detect a logged-in session after 6 attempts.", "err")
        _notify("Grok Bridge", "❌ Login check failed")
        return

    # Deep-thinking ("Think" reasoning mode) — best-effort toggle, non-fatal.
    if _THINK:
        _log(f"enabling Grok Think mode: {_safari_enable_think()}", "ok")

    if new_chat:
        _log("starting fresh chat …")
        _safari_new_chat()
        time.sleep(0.5)

    # Snapshot git state at session start — used by fake-DONE guard.
    # Comparing vs current state (not just "is clean?") correctly handles
    # sessions that begin with pre-existing uncommitted changes.
    _, _session_git_start, _ = run_command("git status --porcelain", cwd=cwd)

    # Build primer with the session marker so we can find the first reply boundary
    marker = _SESSION_MARKER
    primer = _primer_for(cwd, task) + f"\n{marker}"

    _log(f"injecting primer ({len(primer)} chars) …")
    if not _safari_inject_and_send(primer):
        _log("primer injection failed", "err")
        _notify("Grok Bridge", "❌ Primer injection failed")
        return

    turn         = 0
    no_cmd_streak = 0

    while not _SHUTDOWN:
        turn += 1
        _log(_bold(f"── turn {turn} ──────────────────────────────"))

        # Check for page errors before reading
        err = _safari_detect_error()
        if err:
            _log(f"grok.com error mid-session: {err}", "warn")
            if err in ("rate limit", "logged out"):
                _rate_limit_hits = getattr(run_auto_safari, "_rate_limit_hits", 0) + 1
                run_auto_safari._rate_limit_hits = _rate_limit_hits  # type: ignore[attr-defined]
                wait = min(30 * _rate_limit_hits, 300)  # 30s, 60s, 90s … cap at 5min
                _log(f"Pausing {wait}s then retrying (hit #{_rate_limit_hits}) …")
                time.sleep(wait)
                continue

        _safari_scroll_bottom()
        reply = _safari_stream_reply(marker, timeout=300)

        if _LOG_PATH:
            with _LOG_PATH.open("a") as fh:
                fh.write(f"\n--- TURN {turn} GROK REPLY ---\n{reply}\n")

        if is_done(reply):
            if _VERIFY:
                git_state = _git_verify(cwd)
                _, current_git, _ = run_command("git status --porcelain", cwd=cwd)
                # Compare vs snapshot taken at session start, not just "is clean?".
                # This fires correctly even when pre-existing uncommitted changes exist.
                if current_git.strip() == _session_git_start.strip():
                    _log("⚠️  fake DONE — git unchanged vs session start; pushing back …", "warn")
                    pushback = (f"{git_state}\n\n⚠️ FAKE_COMPLETION_DETECTED: "
                                f"git shows ZERO file changes since this session started. "
                                f"You claimed task complete but made no real edits. "
                                f"Provide concrete edit commands now.\n{marker}")
                    _safari_inject_and_send(pushback)
                    continue
            _log("[[DONE]] — task complete", "ok")
            _notify("Grok Bridge ✓", f"Task done in {_elapsed()} ({turn} turns)")
            return

        cmds = parse_commands(reply) + _collect_diff_cmds(reply, _SESSION_ID)
        if not cmds:
            no_cmd_streak += 1
            if no_cmd_streak >= 3:
                _log("no command in 3 consecutive replies — stopping", "err")
                _notify("Grok Bridge", f"⚠️ Stuck after {turn} turns")
                return
            _log(f"no command block — re-reading in 3s (streak {no_cmd_streak}/3)", "warn")
            time.sleep(3)
            # Don't clear marker — keep the last turn's marker so we slice correctly.
            # Clearing it causes rfind("") == 0, which treats the whole page as the reply.
            continue

        no_cmd_streak = 0

        # Run each command; skip (don't re-run) duplicates detected this session
        reports: list[str] = []
        for cmd in cmds:
            norm_key = ' '.join(cmd.split()).lower()
            if norm_key in _SEEN_CMDS:
                _log(f"duplicate command (skipped): {cmd[:80]}", "warn")
                reports.append(f"$ {cmd}\n(skipped — already executed this session)")
                continue
            _SEEN_CMDS.add(norm_key)
            if _SHUTDOWN:
                break
            reports.append(gate_and_run(cmd, cwd=cwd, auto_approve=auto_approve, yolo=yolo))

        if _SHUTDOWN:
            break

        sent = "\n\n".join(reports)
        if _VERIFY:
            sent += "\n\n" + _git_verify(cwd)
        if _LOG_PATH:
            with _LOG_PATH.open("a") as fh:
                fh.write(f"\n--- TURN {turn} COMMANDS ---\n{sent}\n")

        # Embed new marker so next reply boundary is findable
        marker = f"[B:{_SESSION_ID}:{turn:04d}]"

        # Cap output to avoid rate-limiting on Heavy mode — large file cats are the main trigger.
        # Grok gets the first OUTPUT_MAX chars + a note; it can request the rest if needed.
        OUTPUT_MAX = 3500
        if len(sent) > OUTPUT_MAX:
            sent = sent[:OUTPUT_MAX] + f"\n[output truncated — {len(sent)} chars total, showing first {OUTPUT_MAX}]"

        payload = sent + f"\n{marker}"

        # Chunk large payloads — grok.com silently drops very long clipboard pastes
        if len(payload) > SEND_CHUNK_SIZE:
            chunks = [payload[i:i + SEND_CHUNK_SIZE]
                      for i in range(0, len(payload), SEND_CHUNK_SIZE)]
            _log(f"output {len(payload)} chars — sending in {len(chunks)} chunks …")
            for ci, chunk in enumerate(chunks):
                suffix = "" if ci == len(chunks) - 1 else f"\n(continued in next message {ci+2}/{len(chunks)})"
                _safari_inject_and_send(chunk + suffix)
                if ci < len(chunks) - 1:
                    time.sleep(5)  # let Grok acknowledge each chunk (Heavy mode needs more time)
        else:
            _log("sending output back to Grok …")
            _safari_inject_and_send(payload)

    if _SHUTDOWN:
        _log(f"stopped by Ctrl+C after {turn} turns", "warn")
        _notify("Grok Bridge", f"Stopped at turn {turn}")


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

        cmds = parse_commands(reply) + _collect_diff_cmds(reply, _SESSION_ID)
        if not cmds:
            if is_done(reply):
                if _VERIFY:
                    git_state = _git_verify(cwd)
                    if "clean — no uncommitted changes" in git_state:
                        pushback = (f"{git_state}\n\n⚠️ FAKE_COMPLETION_DETECTED: "
                                    f"git shows ZERO file changes. Provide real edit commands.")
                        _grok_send(pushback)
                        continue
                print("\n✅ Grok signalled DONE. Bridge finished.")
                return
            ans = input("No command found in that reply. [r]e-read / [q]uit? ").strip().lower()
            if ans in ("q", "quit"):
                return
            sent = ""   # re-read the whole latest page text next loop
            continue

        reports = [gate_and_run(c, cwd=cwd, auto_approve=auto_approve, yolo=yolo) for c in cmds]
        sent = "\n\n".join(reports)
        if _VERIFY:
            sent += "\n\n" + _git_verify(cwd)
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
    ap = argparse.ArgumentParser(
        description="Drive grok.com (web) as a safe local terminal agent.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              # Fully automatic — Safari, zero prompts, fresh chat:
              python3 grok_terminal_bridge.py --mode auto --safari --yolo "make advance"

              # Auto-fix build errors until green:
              python3 grok_terminal_bridge.py --mode autofix --safari --yolo

              # Multiple tasks in sequence:
              python3 grok_terminal_bridge.py --mode auto --safari --yolo --tasks "make build" "make test" "make advance"

              # Log everything to a file:
              python3 grok_terminal_bridge.py --mode auto --safari --yolo --log ~/grok.log "make advance"
        """),
    )
    ap.add_argument("task", nargs="*", help="Task for Grok (can also use --tasks for multiple).")
    ap.add_argument("--auto", action="store_true",
                    help="Shortcut for --mode auto --safari (the normal way to run the bridge).")
    ap.add_argument("--mode", choices=["manual", "auto", "autofix"], default="manual",
                    help="manual=copy/paste · auto=drive grok.com · autofix=fix build errors until green")
    ap.add_argument("--safari", action="store_true",
                    help="Safari mode (bypasses Cloudflare). Needs: Safari→Develop→Allow JS from Apple Events.")
    ap.add_argument("--tasks", nargs="+", metavar="TASK",
                    help="Run multiple tasks in sequence (replaces positional task arg).")
    ap.add_argument("--cwd", default=os.path.expanduser("~"),
                    help="Working directory for all commands (default: home dir).")
    ap.add_argument("--auto-approve", action="store_true",
                    help="Auto-run safe commands; still confirm dangerous ones.")
    ap.add_argument("--yolo", action="store_true",
                    help="Zero prompts — run everything instantly. Own the risk.")
    ap.add_argument("--verify", action="store_true",
                    help="After each command batch, append git status + diff --stat to the feedback sent to Grok.")
    ap.add_argument("--no-new-chat", action="store_true",
                    help="Don't click New Chat on start (reuse the current grok.com conversation).")
    ap.add_argument("--branch", metavar="NAME",
                    help="Create grok/<NAME>-<timestamp> branch and switch to it before running "
                         "(inline equivalent of start_grok_session.sh).")
    ap.add_argument("--log", metavar="FILE",
                    help="Append all turns + commands to this log file. "
                         "In --auto mode a default log is written to ~/grok_sessions/<session>.log.")
    ap.add_argument("--session-name", metavar="NAME", default="grok-bridge",
                    help="agent-browser session = isolated browser. Give each PARALLEL bridge a "
                         "UNIQUE name (e.g. grok-1, grok-2) so they don't share one grok.com tab. "
                         "Only isolates --mode auto (agent-browser), NOT Safari. Default: grok-bridge.")
    ap.add_argument("--label", metavar="NAME", default=None,
                    help="Short tag shown in prompts/logs/notifications — handy when several "
                         "windows are open. Defaults to --session-name.")
    ap.add_argument("--coordinate", action="store_true",
                    help="Tell Grok to claim its lane in COORDINATION.md before editing any file "
                         "(safe parallel runs). Auto-enabled when --session-name is non-default.")
    ap.add_argument("--max-commands", type=int, default=0, metavar="N",
                    help="Stop after N commands (0 = unlimited). Safety cap for unattended "
                         "parallel --yolo runs so a loop can't run forever.")
    ap.add_argument("--safari-window", action="store_true",
                    help="Safari mode: open + drive this agent's OWN Safari window (targeted by id). "
                         "Lets several Safari agents run side-by-side without fighting over one window.")
    ap.add_argument("--think", action="store_true",
                    help="Turn on grok.com's deep-reasoning 'Think' mode before sending the task.")
    ap.add_argument("--loop", action="store_true",
                    help="Keep working after [[DONE]] — re-prime the agent for the next task in its "
                         "lane and continue until --max-commands (set one!) or you stop it.")
    args = ap.parse_args()
    global _VERIFY, _GROK_SESSION, _LABEL, _COORDINATE_LANE, _MAX_COMMANDS
    global _SAFARI_OWN_WINDOW, _THINK
    _VERIFY = args.verify
    _MAX_COMMANDS = max(0, args.max_commands)
    _SAFARI_OWN_WINDOW = args.safari_window
    _THINK = args.think

    # Per-instance browser session + human label (the keys to safe parallelism).
    _GROK_SESSION = args.session_name
    _LABEL = args.label or args.session_name
    # Coordinate explicitly, or implicitly whenever this is a non-default (parallel) session.
    if args.coordinate or args.session_name != "grok-bridge":
        _COORDINATE_LANE = _LABEL
    # agent-browser parallelism needs a unique --session-name; Safari parallelism
    # needs --safari-window. Warn if a parallel agent-browser session forgot the name.
    if args.session_name != "grok-bridge" and (args.safari or args.auto) and not args.safari_window:
        print(_yellow("⚠  For parallel SAFARI agents use --safari-window (own window per agent). "
                      "--session-name only isolates agent-browser, not Safari."))

    # --auto is a shortcut for --mode auto --safari
    if args.auto:
        args.mode = "auto"
        args.safari = True

    # --auto mode: verification defaults to True so fake completions are auto-rejected
    if args.mode == "auto" and not args.verify:
        _VERIFY = True

    # --log  (auto mode defaults to ~/grok_sessions/<session>.log so every run is captured)
    global _LOG_PATH
    if args.log:
        _LOG_PATH = Path(args.log).expanduser()
    elif args.mode == "auto":
        # Readable per-session name AND inside ~/grok_sessions/ so Salehman's
        # grok-session ingestion (read_grok_session / the launchd daemon) sees it.
        _LOG_PATH = Path.home() / "grok_sessions" / f"{_GROK_SESSION}-{_SESSION_ID[:6]}.log"
    if _LOG_PATH:
        _LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with _LOG_PATH.open("a") as fh:
            fh.write(f"\n{'='*60}\nSession {_SESSION_ID}  started {datetime.now().isoformat()}\n")
        print(_dim(f"logging to {_LOG_PATH}"))

    # Resolve task list
    task_list: list[str] = []
    if args.tasks:
        task_list = args.tasks
    else:
        t = " ".join(args.task).strip()
        if t:
            task_list = [t]

    if args.mode not in ("autofix",) and not task_list:
        try:
            t = input("What should Grok do on your Mac? ").strip()
        except (EOFError, KeyboardInterrupt):
            sys.exit("\n(no task given)")
        if not t:
            sys.exit("(no task given)")
        task_list = [t]

    cwd = os.path.abspath(os.path.expanduser(args.cwd))
    if not os.path.isdir(cwd):
        sys.exit(f"--cwd is not a directory: {cwd}")

    # --branch: create and switch to grok/<slug>-<timestamp> (like start_grok_session.sh)
    if args.branch:
        slug = re.sub(r"[^a-z0-9-]+", "-", args.branch.lower().strip()).strip("-")[:40]
        ts   = datetime.now().strftime("%Y%m%d-%H%M")
        branch = f"grok/{slug}-{ts}"
        r = subprocess.run(["git", "checkout", "-b", branch], cwd=cwd,
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"git checkout -b {branch} failed:\n{r.stderr.strip()}")
        print(_green(f"  ✓ branch: {branch}"))
        print(_dim(f"    merge:   git checkout main && git merge {branch}"))
        print(_dim(f"    discard: git checkout main && git branch -D {branch}"))

    approval = _red("YOLO") if args.yolo else (_yellow("auto-safe") if args.auto_approve else "confirm-dangerous")
    browser  = _cyan("Safari") if args.safari else "agent-browser"
    print(_bold(f"🌉 grok-bridge[{_LABEL}]") + f"  mode={args.mode}  browser={browser}  approval={approval}  cwd={cwd}")
    print(_dim(f"   session={_GROK_SESSION} ({_SESSION_ID[:6]})  coordinate={bool(_COORDINATE_LANE)}  "
               f"max-cmds={args.max_commands or '∞'}  tasks={task_list}"))
    _write_status(state="running", task=task_list[0] if task_list else "", cwd=cwd)
    _emit_event("start", mode=args.mode,
                browser=("safari" if args.safari else "agent-browser"),
                yolo=args.yolo, tasks=task_list, cwd=cwd)

    final_state = "done"
    try:
        if args.mode == "autofix":
            run_autofix(cwd=cwd, auto_approve=args.auto_approve, yolo=args.yolo)

        elif args.mode == "auto" and args.safari:
            def _under_cap() -> bool:
                return not _MAX_COMMANDS or _CMD_COUNT < _MAX_COMMANDS
            loop_task = (
                "Find the single next high-value improvement in your assigned lane and do it. "
                "Read files before editing, verify each change with git diff, keep the build green. "
                f"If there is genuinely nothing useful left, reply {DONE_SENTINEL}.")
            first = True
            while True:
                for i, task in enumerate(task_list):
                    if i > 0 or not first:
                        _log(f"task: {task!r}")
                    run_auto_safari(task, cwd=cwd, auto_approve=args.auto_approve, yolo=args.yolo,
                                    new_chat=(not args.no_new_chat or i == 0 or not first))
                    if _SHUTDOWN or not _under_cap():
                        break
                first = False
                # --loop: after the task list, keep pulling new work until stopped/capped.
                if not args.loop or _SHUTDOWN or not _under_cap():
                    break
                _log("loop: fetching next task …", "info")
                task_list = [loop_task]

        elif args.mode == "auto":
            run_auto(task_list[0] if task_list else "", cwd=cwd,
                     auto_approve=args.auto_approve, yolo=args.yolo)

        else:
            run_manual(task_list[0] if task_list else "", cwd=cwd,
                       auto_approve=args.auto_approve, yolo=args.yolo)
    except KeyboardInterrupt:
        final_state = "interrupted"
    except Exception as e:                       # observability: record the crash, then re-raise
        final_state = "error"
        _emit_event("error", error=str(e))
        _write_status("error", error=str(e))
        raise
    finally:
        if final_state != "error":
            _emit_event("end", state=final_state, commands=_CMD_COUNT)
            _write_status(final_state)


if __name__ == "__main__":
    main()
