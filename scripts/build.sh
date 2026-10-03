#!/usr/bin/env bash
# Builds a signed debug HAP. Signing material is generated locally with the SDK's built-in
# development certificate (no account needed) and is never committed: build-profile.json5 is
# restored afterwards and signatures/ is git-ignored.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${TOOLS_DIR:-$HOME/.wisp-gym-tools}"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

cd "$ROOT"
cp build-profile.json5 build-profile.json5.orig
trap 'mv -f build-profile.json5.orig build-profile.json5' EXIT

( cd "$TOOLS_DIR" && npx oniro-app sign "$ROOT" )
( cd "$TOOLS_DIR" && npx oniro-app build "$ROOT" )

HAP="$ROOT/entry/build/default/outputs/default/entry-default-signed.hap"
mkdir -p "$ROOT/dist" && cp "$HAP" "$ROOT/dist/wisp-gym.hap"
echo "HAP: $ROOT/dist/wisp-gym.hap"
