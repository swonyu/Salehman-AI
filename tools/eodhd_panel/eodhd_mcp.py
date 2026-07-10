#!/usr/bin/env python3
"""Minimal MCP-over-HTTP client for the authorized EODHD server.
Token read from Keychain at runtime; never printed.
Usage: eodhd_mcp.py <tool_name> '<json_args>' [outfile]
Prints result to stdout (or writes to outfile and prints byte count)."""
import json, subprocess, sys, urllib.request

URL = "https://mcp.eodhd.com/v2/mcp"

def token():
    raw = subprocess.run(["security", "find-generic-password", "-s",
                          "Claude Code-credentials", "-w"],
                         capture_output=True, text=True).stdout
    d = json.loads(raw)
    for k, v in d["mcpOAuth"].items():
        if "eodhd" in k.lower():
            return v["accessToken"]
    raise SystemExit("no eodhd token")

TOK = token()

def rpc(payload, session=None):
    hdrs = {"Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {TOK}"}
    if session:
        hdrs["mcp-session-id"] = session
    req = urllib.request.Request(URL, json.dumps(payload).encode(), hdrs)
    with urllib.request.urlopen(req, timeout=120) as r:
        sid = r.headers.get("mcp-session-id")
        body = r.read().decode()
    # streamable-http may wrap in SSE
    if body.startswith("event:") or "\ndata:" in body or body.startswith("data:"):
        datas = [ln[5:].strip() for ln in body.splitlines() if ln.startswith("data:")]
        body = datas[-1] if datas else body
    return (json.loads(body) if body.strip() else None), sid

_SESSION = None
def ensure_session():
    global _SESSION
    if _SESSION is not None:
        return _SESSION
    init = {"jsonrpc": "2.0", "id": 0, "method": "initialize",
            "params": {"protocolVersion": "2025-03-26",
                       "capabilities": {},
                       "clientInfo": {"name": "acceptance-test", "version": "1"}}}
    resp, sid = rpc(init)
    _SESSION = sid or ""
    if sid:
        # notifications/initialized
        try:
            rpc({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid)
        except Exception:
            pass
    return _SESSION

def call(tool, args):
    sid = ensure_session()
    payload = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
               "params": {"name": tool, "arguments": args}}
    resp, _ = rpc(payload, sid or None)
    if resp is None:
        raise SystemExit("empty response")
    if "error" in resp:
        raise SystemExit(f"RPC error: {resp['error']}")
    res = resp["result"]
    # tool results come as content list
    if isinstance(res, dict) and "content" in res:
        out = "".join(c.get("text", "") for c in res["content"])
        if res.get("isError"):
            raise SystemExit(f"tool error: {out[:500]}")
        return out
    return json.dumps(res)

if __name__ == "__main__":
    tool = sys.argv[1]
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    out = call(tool, args)
    if len(sys.argv) > 3:
        with open(sys.argv[3], "w") as f:
            f.write(out)
        print(f"wrote {len(out)} bytes to {sys.argv[3]}")
    else:
        print(out)
