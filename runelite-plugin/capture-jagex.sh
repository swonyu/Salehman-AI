#!/usr/bin/env bash
# Capture the Jagex-account credentials the Jagex Launcher injects, and stash
# them for play.sh (which runs our developer-mode client the launcher can't).
#
# The five JX_* values are spread across processes and the access/refresh tokens
# live in short-lived launcher helper processes, so we scan repeatedly and merge
# the first non-empty value seen for each, over a few seconds.
#
# USAGE: with RuneLite/OSRS launched BY THE JAGEX LAUNCHER running, run:
#     ./capture-jagex.sh
#
# SECURITY: these tokens are PASSWORD-EQUIVALENT (bypass password + 2FA). Written
# to ~/.runelite/.salehman-jx.env, 0600, OUTSIDE this git repo. Never share them.
# Delete that file to revoke local auto-login.
set -uo pipefail

OUT="$HOME/.runelite/.salehman-jx.env"
VARS="JX_ACCESS_TOKEN JX_REFRESH_TOKEN JX_SESSION_ID JX_CHARACTER_ID JX_DISPLAY_NAME"

# holders (macOS bash 3.2 has no associative arrays)
A_JX_ACCESS_TOKEN=""; A_JX_REFRESH_TOKEN=""; A_JX_SESSION_ID=""
A_JX_CHARACTER_ID=""; A_JX_DISPLAY_NAME=""

echo "==> scanning for Jagex credentials (this takes a few seconds)"
for i in $(seq 1 40); do
  dump="$(ps ewwx 2>/dev/null || true)"
  for v in $VARS; do
    cur="$(eval "printf '%s' \"\$A_$v\"")"
    [ -n "$cur" ] && continue
    val="$(printf '%s\n' "$dump" | grep -oE "${v}=[^[:space:]]+" | head -1 | sed "s/^${v}=//" 2>/dev/null)"
    [ -n "$val" ] && eval "A_$v=\$val"
  done
  # stop early once we have the 4 that matter for login
  if [ -n "$A_JX_ACCESS_TOKEN" ] && [ -n "$A_JX_REFRESH_TOKEN" ] && \
     [ -n "$A_JX_SESSION_ID" ] && [ -n "$A_JX_CHARACTER_ID" ]; then
    break
  fi
  sleep 0.4
done

# report what we got (key names only)
got=""
for v in $VARS; do [ -n "$(eval "printf '%s' \"\$A_$v\"")" ] && got="$got $v"; done
echo "==> captured:${got:- (none)}"

if [ -z "$A_JX_SESSION_ID" ] || [ -z "$A_JX_CHARACTER_ID" ]; then
  echo "!! Missing JX_SESSION_ID / JX_CHARACTER_ID — is a Jagex-launched RuneLite actually running?"
  echo "   In the Jagex Launcher, set the OSRS client to RuneLite and click Play, then re-run."
  exit 1
fi
if [ -z "$A_JX_ACCESS_TOKEN" ] || [ -z "$A_JX_REFRESH_TOKEN" ]; then
  echo "!! Got the session IDs but not the access/refresh tokens (they flicker in launcher"
  echo "   helper processes). Re-run this once or twice more right after clicking Play."
fi

umask 077
{
  echo "# Salehman GE Flips - captured Jagex credentials (password-equivalent, do not share)"
  for v in $VARS; do
    val="$(eval "printf '%s' \"\$A_$v\"")"
    [ -n "$val" ] && printf 'export %s=%q\n' "$v" "$val"
  done
} > "$OUT"
chmod 600 "$OUT"
echo "==> wrote $OUT (0600). Run ./play.sh to launch with your Jagex account + the plugin."
