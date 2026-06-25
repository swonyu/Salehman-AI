#!/usr/bin/env bash
# INSTALL: build the plugin jar and drop it into RuneLite's sideloaded-plugins
# folder, so it appears in your normal plugin list in the OFFICIAL RuneLite
# client. Re-run this after code changes, then restart RuneLite. Private/local —
# nothing is uploaded to the Plugin Hub.
set -e
export JAVA_HOME="$(ls -d "$HOME"/tools/jdk-11*/Contents/Home)"
cd "$(dirname "$0")"

echo "==> building plugin jar"
./gradlew jar --no-daemon -q

DEST="$HOME/.runelite/sideloaded-plugins"
mkdir -p "$DEST"
cp build/libs/salehman-ge-flips-*.jar "$DEST/"
echo "==> installed: $DEST/$(ls -1 build/libs/salehman-ge-flips-*.jar | xargs basename)"
echo "    Now launch with ./play.sh (the official client must run with -ea --developer-mode"
echo "    for side-loaded plugins to load; the normal launcher does NOT do this)."
