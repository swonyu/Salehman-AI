#!/usr/bin/env python3
"""grok_cleanup.py — stdlib only. Delete files in ~/grok_sessions older than N days (default 7). Prints count and names of removed files."""
import sys
import time
from pathlib import Path
def cleanup(days: int = 7) -> None:
    sessions_dir = Path.home() / "grok_sessions"
    if not sessions_dir.exists():
        print("No ~/grok_sessions directory found.")
        return
    cutoff = time.time() - days * 86400
    removed = []
    for f in list(sessions_dir.iterdir()):
        if f.is_file():
            try:
                if f.stat().st_mtime < cutoff:
                    f.unlink()
                    removed.append(f.name)
            except Exception as exc:
                print(f"Error with {f.name}: {exc}")
    print(f"Removed {len(removed)} file(s) older than {days} days from ~/grok_sessions:")
    for name in removed:
        print(f"  - {name}")
if name == "main":
    days = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    cleanup(days)
