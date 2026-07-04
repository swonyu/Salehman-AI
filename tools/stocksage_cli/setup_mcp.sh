#!/bin/bash
# One-time MCP setup. macOS system python is externally-managed (PEP 668), so install `mcp` into a
# dedicated venv rather than the system python. Prints the exact `claude mcp add` command to run next.
cd "$(dirname "$0")" || exit 1
echo "creating venv + installing mcp..."
python3 -m venv .venv || { echo "ERROR: venv creation failed (need python3)"; exit 1; }
.venv/bin/pip install --quiet --upgrade pip >/dev/null 2>&1
.venv/bin/pip install --quiet mcp || { echo "ERROR: mcp install failed"; exit 1; }
# also build the CLI if not present
[ -x ./stocksage ] || bash build.sh >/dev/null 2>&1
echo ""
echo "MCP ready. Register it with Claude (absolute paths — Claude runs it from elsewhere):"
echo ""
echo "  claude mcp add stocksage -- \"$(pwd)/.venv/bin/python\" \"$(pwd)/mcp_server.py\""
echo ""
