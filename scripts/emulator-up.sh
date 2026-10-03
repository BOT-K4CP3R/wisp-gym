#!/usr/bin/env bash
# Starts the Oniro (QEMU) emulator headless, waits until the system has booted, then
# installs and launches the HAP. Works on macOS (Apple Silicon: slow TCG, first boot
# takes a few minutes) and Linux (KVM).
#
#   ./scripts/emulator-up.sh            # start (if needed) + install + launch dist/wisp-gym.hap
#
# macOS needs `brew install qemu`. Port 55555 can be taken on some machines, so the hdc
# bridge uses 55557 by default (override with PORT=...).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="${TOOLS_DIR:-$HOME/hackathon/_tools}"
PORT="${PORT:-55557}"
D="127.0.0.1:$PORT"
HAP="${HAP:-$ROOT/dist/wisp-gym.hap}"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$HOME/setup-ohos-sdk/darwin/23/toolchains:$PATH"

[ -f "$HAP" ] || { echo "Build first: ./scripts/build.sh"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "Install QEMU first (macOS: brew install qemu)"; exit 1; }

cd "$TOOLS_DIR"
[ -d "$HOME/oniro-emulator/images" ] || npx oniro-app emulator install
if ! pgrep -f qemu-system-x86_64 >/dev/null; then
  npx oniro-app emulator start --headless --connect "$D" --log "$TOOLS_DIR/emulator.log"
fi

echo "Waiting for hdc ($D)..."
for _ in $(seq 1 60); do
  hdc tconn "$D" >/dev/null 2>&1 || true
  hdc list targets 2>/dev/null | grep -q "$PORT" && break
  sleep 5
done
echo "Waiting for the system to finish booting (can take several minutes under TCG)..."
for _ in $(seq 1 120); do
  v=$(hdc -t "$D" shell "param get bootevent.boot.completed" 2>/dev/null | tail -1 | tr -d '[:space:]' || true)
  b=$(hdc -t "$D" shell "bm dump -a 2>&1 | head -1" 2>/dev/null || true)
  [ "$v" = "true" ] && echo "$b" | grep -q "ID" && break
  sleep 10
done

hdc -t "$D" shell "mkdir -p /data/local/tmp/w"
hdc -t "$D" file send "$HAP" /data/local/tmp/w/app.hap
hdc -t "$D" shell "bm install -p /data/local/tmp/w/app.hap"
hdc -t "$D" shell "aa force-stop com.hackyeah.wispgym; aa start -a EntryAbility -b com.hackyeah.wispgym -m entry"
echo "Launched. Screenshots: DEVICE=$D ./scripts/emu.sh shot <name>"
