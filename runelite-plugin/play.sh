#!/usr/bin/env bash
# Play OSRS with the Salehman GE Flips plugin in your normal plugin list.
#
# Why this script exists: RuneLite only loads side-loaded plugins
# (~/.runelite/sideloaded-plugins/*.jar) when the client runs with BOTH
# assertions enabled (-ea) AND --developer-mode. The official RuneLite launcher
# does neither, so it silently ignores side-loaded plugins. This launches the
# exact same official client jars directly, with those two flags. 100% local —
# nothing is published to the Plugin Hub.
#
# Keeping the client updated: occasionally run the official RuneLite launcher
# (~/Applications/RuneLite.app) — it refreshes the client jars in
# ~/.runelite/repository2/. Then use this script to actually play with the plugin.
set -e
export JAVA_HOME="$(ls -d "$HOME"/tools/jdk-11*/Contents/Home)"
HERE="$(cd "$(dirname "$0")" && pwd)"

# 1) build + install the latest plugin jar
echo "==> building + installing plugin"
( cd "$HERE" && ./gradlew jar --no-daemon -q )
mkdir -p "$HOME/.runelite/sideloaded-plugins"
cp "$HERE"/build/libs/salehman-ge-flips-*.jar "$HOME/.runelite/sideloaded-plugins/"

# 2) launch the official client directly with the flags side-loading requires
REPO="$HOME/.runelite/repository2"
if ! ls "$REPO"/client-*.jar >/dev/null 2>&1; then
  echo "!! RuneLite client jars not found in $REPO"
  echo "   Run the official launcher once (open ~/Applications/RuneLite.app) to download them, then re-run this."
  exit 1
fi
CP="$(ls "$REPO"/*.jar | tr '\n' ':')"

# Jagex-account login: if we captured the launcher's credentials (see
# capture-jagex.sh), feed them in so the injected game client logs into your
# Jagex account. Without this you only get the legacy username/password screen.
JX_ENV="$HOME/.runelite/.salehman-jx.env"
if [ -f "$JX_ENV" ]; then
  # shellcheck disable=SC1090
  source "$JX_ENV"
  echo "==> using captured Jagex credentials${JX_DISPLAY_NAME:+ for $JX_DISPLAY_NAME}"
else
  echo "==> no Jagex credentials found ($JX_ENV); you'll get the legacy login screen."
  echo "    For a Jagex account: launch RuneLite via the Jagex Launcher, then run ./capture-jagex.sh"
fi

echo "==> launching official RuneLite client (developer mode) with the plugin"
exec "$JAVA_HOME/bin/java" -ea \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens=java.base/java.net=ALL-UNNAMED \
  --add-opens=java.base/java.io=ALL-UNNAMED \
  --add-opens=java.desktop/com.apple.eawt=ALL-UNNAMED \
  -Dsun.java2d.opengl=true \
  -cp "$CP" net.runelite.client.RuneLite --developer-mode "$@"
