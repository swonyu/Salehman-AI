#!/usr/bin/env bash
#
# Sandbox-friendly full-module type-check for the Salehman AI app target.
#
# Why this exists: inside the Claude Code agent sandbox, `xcodebuild` cannot run
# because its build-service daemon (XCBBuildService) is denied the DerivedData
# arena write ("Operation not permitted"), and the sandbox can't be disabled.
# This script drives `swiftc` DIRECTLY instead — it writes only to a module cache
# under TMPDIR — and type-checks every app source file together in Swift 6 mode
# with the project's exact isolation settings. That catches the dominant risk
# class for unverified edits (type errors, Swift-6 concurrency violations,
# exhaustive-switch breaks) without a full build.
#
# It does NOT link, compile the asset catalog, or run tests — run the canonical
# `xcodebuild` for those (see CLAUDE.md). Flags below mirror the .xcodeproj build
# settings (SWIFT_VERSION 6.0, SWIFT_DEFAULT_ACTOR_ISOLATION MainActor,
# MACOSX_DEPLOYMENT_TARGET 26.5, MemberImportVisibility); keep them in sync if the
# project changes.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV="$(xcode-select -p)"
SDK="$DEV/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
SWIFTC="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
CACHE="${TMPDIR:-/tmp}/salehman_mcache"

find "Salehman AI" -name '*.swift' -not -path '*External Artifacts*' -print0 \
  | xargs -0 "$SWIFTC" -typecheck \
      -sdk "$SDK" \
      -target arm64-apple-macosx26.5 \
      -swift-version 6 \
      -default-isolation MainActor \
      -D DEBUG \
      -enable-upcoming-feature MemberImportVisibility \
      -module-name SalehmanAI \
      -module-cache-path "$CACHE"

echo "✅ Salehman AI app target type-checks clean (Swift 6, MainActor default isolation)."
