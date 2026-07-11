#!/usr/bin/env python3
"""Minimal MCP-over-HTTP client for the authorized EODHD server.
Token read from Keychain at runtime; never printed.
Usage: eodhd_mcp.py <tool_name> '<json_args>' [outfile]
Prints result to stdout (or writes to outfile and prints byte count)."""
import json, subprocess, sys, time, urllib.parse, urllib.request

URL = "https://mcp.eodhd.com/v2/mcp"
TOKEN_URL = "https://mcp.eodhd.com/token"
CACHE_ITEM = "salehman-eodhd-mcp-token"   # dedicated Keychain item; never the shared blob


def _keychain_read(service):
    r = subprocess.run(["security", "find-generic-password", "-s", service, "-w"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def token():
    """Access-token resolution (2026-07-11, after the first MCP-session expiry):
    1. the dedicated cache item (written by our own refresh), if unexpired;
    2. the shared Claude Code credentials blob's access token (fresh after the owner
       re-auths in their window);
    3. an OAuth refresh-token grant using the blob's refresh token — MAY FAIL if the
       server strictly rotates refresh tokens and one was already consumed; the fix
       then is the owner reconnecting the MCP server once in their window.
    Tokens are never printed; the shared blob is never written (other servers live in it)."""
    raw = _keychain_read(CACHE_ITEM)
    if raw:
        try:
            c = json.loads(raw)
            if c.get("expiresAt", 0) > time.time() + 60:
                return c["accessToken"]
        except (json.JSONDecodeError, KeyError):
            pass
    blob = _keychain_read("Claude Code-credentials")
    d = json.loads(blob) if blob else {}
    ent = next((v for k, v in d.get("mcpOAuth", {}).items() if "eodhd" in k.lower()), None)
    if ent is None:
        raise SystemExit("no eodhd credentials in keychain")
    if ent.get("expiresAt", 0) / 1000 > time.time() + 60:
        return ent["accessToken"]
    body = urllib.parse.urlencode({"grant_type": "refresh_token",
                                   "refresh_token": ent["refreshToken"],
                                   "client_id": ent["clientId"]}).encode()
    req = urllib.request.Request(TOKEN_URL, data=body,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        r = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        raise SystemExit(f"eodhd token refresh failed (HTTP {e.code}) — reconnect the MCP "
                         "server once in the owner's Claude Code window") from e
    tok = r["access_token"]
    subprocess.run(["security", "add-generic-password", "-U", "-s", CACHE_ITEM, "-a", "salehman",
                    "-w", json.dumps({"accessToken": tok,
                                      "expiresAt": int(time.time()) + int(r.get("expires_in", 3600))})],
                   capture_output=True, text=True)
    return tok

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
