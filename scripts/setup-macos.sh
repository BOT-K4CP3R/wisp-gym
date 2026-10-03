#!/usr/bin/env bash
# One-time toolchain bootstrap for macOS (Apple Silicon or Intel) without DevEco Studio.
# Installs: JDK 17, the open-source Oniro App Builder CLI, the OpenHarmony SDK 6.1 (API 23)
# and the OpenHarmony command-line tools (hvigor, ohpm).
#
# Why the Linux command-line tools? Huawei hosts no public macOS build. hvigor and ohpm are
# Node.js programs, so the Linux archive works if its bundled Linux node binary is replaced
# by the system Node (>= 22). The archive's own SDK folder is not needed (we use the macOS
# SDK downloaded by oniro-app) and is removed to save ~6 GB.
set -euo pipefail

TOOLS_DIR="${TOOLS_DIR:-$HOME/.wisp-gym-tools}"
CLT_DIR="${CLT_DIR:-$HOME/command-line-tools}"
CLT_URL="${CLT_URL:-https://repo.huaweicloud.com/harmonyos/ohpm/5.1.0/commandline-tools-linux-x64-5.1.0.840.zip}"

command -v brew >/dev/null || { echo "Homebrew is required: https://brew.sh"; exit 1; }
command -v node >/dev/null || brew install node
[ "$(node -p 'process.versions.node.split(".")[0]')" -ge 22 ] || { echo "Node >= 22 required"; exit 1; }

brew list openjdk@17 >/dev/null 2>&1 || brew install openjdk@17

mkdir -p "$TOOLS_DIR" && cd "$TOOLS_DIR"
[ -f package.json ] || npm init -y >/dev/null
npm i @oniroproject/oniro-app >/dev/null
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

npx oniro-app sdk install 6.1

if [ ! -x "$CLT_DIR/bin/hvigorw" ]; then
  curl -L -C - --retry 5 -o cmdtools.zip "$CLT_URL"
  rm -rf clt && mkdir clt
  # The archive has case-colliding header names on macOS; skip them (answer "N" to prompts).
  unzip -q -n cmdtools.zip -d clt -x 'command-line-tools/sdk/*'
  rm -rf "$CLT_DIR" && mv clt/command-line-tools "$CLT_DIR"
  rm -rf "$CLT_DIR/tool/node" && mkdir -p "$CLT_DIR/tool/node/bin" "$CLT_DIR/sdk"
  ln -s "$(command -v node)" "$CLT_DIR/tool/node/bin/node"
  ln -s "$(command -v npm)"  "$CLT_DIR/tool/node/bin/npm"
  ln -s "$(command -v npx)"  "$CLT_DIR/tool/node/bin/npx"
  chmod +x "$CLT_DIR"/bin/* "$CLT_DIR/hvigor/bin/hvigorw" "$CLT_DIR/ohpm/bin/ohpm"
  rm -f cmdtools.zip
fi
npx oniro-app cmdtools status
echo "Toolchain ready."
