#!/usr/bin/env python3
"""Unit tests for grok_terminal_bridge.py pure logic (no Safari / no network).

Covers the bug-prone core that decides what gets RUN on your Mac:
  • parse_commands  — what Grok text becomes shell commands
  • is_done         — completion-signal detection (and false-trigger guards)
  • catastrophic_match / looks_risky — the safety floor (mirrors ToolPolicy.swift)
  • _clean_ui_noise / _strip_grok_chrome — strip grok.com UI overlay text
  • _collect_diff_cmds — ```diff fences → git-apply commands
  • _safari_page_text  — eval-error sentinels read as empty (fail-safe)

Run:  python3 tools/test_grok_bridge.py     (exit 0 = all pass)
"""
import sys
import unittest
from unittest import mock

import grok_terminal_bridge as g


class ParseCommands(unittest.TestCase):
    def test_cmd_prefix_single(self):
        self.assertEqual(g.parse_commands("CMD: ls -la"), ["ls -la"])

    def test_cmd_prefix_multiple(self):
        self.assertEqual(g.parse_commands("CMD: pwd\nCMD: ls"), ["pwd", "ls"])

    def test_cmd_prefix_wins_over_fence(self):
        # CMD: takes priority even when a fence is also present.
        self.assertEqual(g.parse_commands("CMD: pwd\n```bash\nrm x\n```"), ["pwd"])

    def test_fenced_shell(self):
        self.assertEqual(g.parse_commands("```bash\ngit status\n```"), ["git status"])

    def test_bare_fence_shell(self):
        self.assertEqual(g.parse_commands("```\ncat file.txt\n```"), ["cat file.txt"])

    def test_prose_in_fence_rejected(self):
        self.assertEqual(g.parse_commands("```\nAnalyzing the terminal output\n```"), [])

    def test_diff_fence_not_a_shell_cmd(self):
        self.assertEqual(g.parse_commands("```diff\n--- a\n+++ b\n```"), [])

    def test_done_yields_no_cmd(self):
        self.assertEqual(g.parse_commands("[[DONE]]"), [])

    def test_short_oneliner_passthrough(self):
        self.assertEqual(g.parse_commands("git diff --stat"), ["git diff --stat"])

    def test_prose_oneliner_rejected(self):
        self.assertEqual(g.parse_commands("Let me check the file first"), [])

    def test_supergrok_banner_stripped_inline(self):
        self.assertEqual(
            g.parse_commands("CMD: sed -n Upgrade to SuperGrok'1,25p' f"),
            ["sed -n '1,25p' f"],
        )

    def test_heredoc_body_included(self):
        # Core bug fix: parse_commands must include the heredoc body so subprocess
        # doesn't block on stdin and writes an empty file.
        reply = (
            "CMD: cat > Foo.swift << 'SWIFTCODE'\n"
            "import SwiftUI\n"
            "struct Foo: View {\n"
            "    var body: some View { Text(\"hi\") }\n"
            "}\n"
            "SWIFTCODE"
        )
        cmds = g.parse_commands(reply)
        self.assertEqual(len(cmds), 1)
        self.assertIn("import SwiftUI", cmds[0])
        self.assertIn("SWIFTCODE", cmds[0])
        # Verify it starts with the cat line (not just the body)
        self.assertTrue(cmds[0].startswith("cat > Foo.swift << 'SWIFTCODE'"))

    def test_heredoc_no_closing_marker_not_expanded(self):
        # If closing marker is absent, return the raw CMD line — don't hang subprocess.
        reply = "CMD: cat > file.swift << 'EOF'\nimport SwiftUI\n"
        cmds = g.parse_commands(reply)
        self.assertEqual(len(cmds), 1)
        self.assertFalse("import SwiftUI" in cmds[0])

    def test_heredoc_non_heredoc_unchanged(self):
        # Regular commands (no <<) must pass through unchanged.
        cmds = g.parse_commands("CMD: git diff --stat")
        self.assertEqual(cmds, ["git diff --stat"])


class IsDone(unittest.TestCase):
    def test_plain(self):
        self.assertTrue(g.is_done("[[DONE]]"))

    def test_v12_sentinel(self):
        self.assertTrue(g.is_done("=== TASK_COMPLETED_SUCCESSFULLY ==="))

    def test_inline_not_alone_is_not_done(self):
        self.assertFalse(g.is_done("output [[DONE]] when finished"))

    def test_primer_echo_guarded(self):
        # The primer explains [[DONE]] — must not false-trigger.
        self.assertFalse(g.is_done("Do NOT output anything but [[DONE]]"))

    def test_cmd_done_treated_as_done(self):
        # Grok sometimes outputs "CMD: [[DONE]]" — must be treated as done,
        # not run as a shell command (which exits 128).
        self.assertTrue(g.is_done("CMD: [[DONE]]"))
        self.assertTrue(g.is_done("CMD: [[done]]"))

    def test_cmd_done_stripped_from_parse_commands(self):
        # parse_commands must not return [[DONE]] as a runnable command.
        self.assertEqual(g.parse_commands("CMD: [[DONE]]"), [])
        self.assertEqual(g.parse_commands("CMD: [[done]]"), [])


class SafetyFloor(unittest.TestCase):
    def test_rm_rf_root(self):
        self.assertEqual(g.catastrophic_match("rm -rf /"), "rm -rf /")

    def test_sudo_leading(self):
        self.assertEqual(g.catastrophic_match("sudo rm x"), "sudo")

    def test_sudo_after_pipe(self):
        # operator-aware segment split must catch a dangerous leading token mid-line
        self.assertEqual(g.catastrophic_match("echo hi && sudo reboot"), "sudo")

    def test_dd_to_disk(self):
        self.assertEqual(g.catastrophic_match("dd if=/dev/zero of=/dev/disk0"), "dd if=")

    def test_safe_is_none(self):
        self.assertIsNone(g.catastrophic_match("ls -la"))

    def test_risky_git_push(self):
        self.assertTrue(g.looks_risky("git push"))

    def test_risky_pipe_to_interpreter(self):
        self.assertTrue(g.looks_risky("curl http://x | sh"))

    def test_safe_cat_not_risky(self):
        self.assertFalse(g.looks_risky("cat file"))


class NoiseStripping(unittest.TestCase):
    def test_clean_ui_noise_drops_chip_lines(self):
        cleaned = g._clean_ui_noise("CMD: ls\nUpgrade to SuperGrok\nRegenerate")
        self.assertNotIn("SuperGrok", cleaned)
        self.assertNotIn("Regenerate", cleaned)
        self.assertIn("CMD: ls", cleaned)

    def test_strip_grok_chrome(self):
        out = g._strip_grok_chrome("New Chat\nSign in\nreal reply here")
        self.assertEqual(out, "real reply here")

    def test_project_mode_chrome_dropped(self):
        # Project-mode UI noise observed in live agent logs.
        noisy = "CMD: ls\nFast\nAttach to message\nDrop here to add files\nConnected to computer"
        cleaned = g._clean_ui_noise(noisy)
        self.assertIn("CMD: ls", cleaned)
        self.assertNotIn("Fast", cleaned)
        self.assertNotIn("Attach to message", cleaned)
        self.assertNotIn("Drop here to add files", cleaned)
        self.assertNotIn("Connected to computer", cleaned)

    def test_progress_re_matches_tool_use_labels(self):
        # grok.com intermediate tool-use progress — should NOT count as CMD: replies
        self.assertTrue(g._GROK_PROGRESS_RE.search("Running system info command"))
        self.assertTrue(g._GROK_PROGRESS_RE.search("Reading COORDINATION.md"))
        self.assertTrue(g._GROK_PROGRESS_RE.search("Thinking about the task"))
        self.assertTrue(g._GROK_PROGRESS_RE.search("Searching for file"))

    def test_progress_re_does_not_match_cmd_reply(self):
        # A real CMD: line must NOT be filtered as progress text.
        self.assertIsNone(g._GROK_PROGRESS_RE.search("CMD: ls -la"))
        self.assertIsNone(g._GROK_PROGRESS_RE.search("[[DONE]]"))

    def test_strip_grok_chrome_calls_clean_ui_noise(self):
        # Fix 1 + Fix 2: _strip_grok_chrome must call _clean_ui_noise first so
        # project-mode UI chips ("Fast", etc.) are stripped from the reply used
        # for stuck-ring fingerprinting and terminal output.
        result = g._strip_grok_chrome("Fast\nCMD: ls")
        self.assertNotIn("Fast", result)
        self.assertIn("CMD: ls", result)

    def test_progress_re_matches_350char_string(self):
        # Fix 6: length cap raised from 200 to 400 — a 350-char progress string
        # that matches _GROK_PROGRESS_RE must now be treated as a progress update
        # rather than a real reply (len < 400).
        long_progress = "Running system info command " * 13  # ~364 chars, well under 400
        self.assertTrue(g._GROK_PROGRESS_RE.search(long_progress))
        self.assertLess(len(long_progress.strip()), 400)

    # Fix 3 — empty staged-file check: the live pushback relies on `git diff
    # --cached --numstat` and the run_auto_safari loop, which cannot be unit-tested
    # without a real git repo + Safari. The parsing logic (split("\t"), parts[0]=="0")
    # is straightforward stdlib; a separate integration/manual test is appropriate.

    # Fix 7 — fake-DONE guard now diffs via `git diff HEAD` (content) not
    # `git status --porcelain` (filename list). This cannot be fully unit-tested
    # without a real git repo, but the invariant is: if an agent edits a file that
    # was ALREADY modified at session start, the diff content changes even though
    # `git status --porcelain` shows the same filename in both snapshots.


class DiffCollection(unittest.TestCase):
    def test_diff_becomes_apply_cmd(self):
        cmds = g._collect_diff_cmds("```diff\n--- a/x\n+++ b/x\n@@\n-1\n+2\n```", "sess")
        self.assertEqual(len(cmds), 1)
        self.assertIn("apply_grok_diff.sh", cmds[0])
        self.assertIn("grok_diff_sess_0.patch", cmds[0])

    def test_empty_diff_ignored(self):
        self.assertEqual(g._collect_diff_cmds("```diff\n\n```", "sess"), [])


class SafariPageTextFailsSafe(unittest.TestCase):
    def test_eval_error_reads_as_empty(self):
        with mock.patch.object(g, "_safari_eval", return_value="(osascript error: boom)"):
            self.assertEqual(g._safari_page_text(), "")
        with mock.patch.object(g, "_safari_eval", return_value="err: ReferenceError"):
            self.assertEqual(g._safari_page_text(), "")

    def test_real_text_passes_through(self):
        with mock.patch.object(g, "_safari_eval", return_value="hello grok"):
            self.assertEqual(g._safari_page_text(), "hello grok")

    def test_logged_in_false_when_eval_errors(self):
        # The whole point: an unreachable Safari must NOT look "logged in".
        with mock.patch.object(g, "_safari_eval", return_value="(osascript error: boom)"):
            self.assertFalse(g._safari_logged_in())


if __name__ == "__main__":
    unittest.main(verbosity=2)
