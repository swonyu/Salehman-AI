#!/usr/bin/env bash
# DEV PREVIEW: launch RuneLite from source with the plugin side-loaded via
# loadBuiltin — fast way to preview code changes. This does NOT use the
# installed sideloaded jar (a source run can't see it). To install the plugin
# into your normal RuneLite plugin list, use install-plugin.sh + the official
# RuneLite client. Nothing here is published.
set -e
export JAVA_HOME="$(ls -d "$HOME"/tools/jdk-11*/Contents/Home)"
cd "$(dirname "$0")"
exec ./gradlew runClient --no-daemon
