#!/usr/bin/env bash
# Helpers to drive an emulator over hdc. Usage: scripts/emu.sh shot <name> | tap <x> <y> | swipe x1 y1 x2 y2 | texts
# Target comes from $DEVICE (default 127.0.0.1:55557).
set -euo pipefail
export PATH="$HOME/setup-ohos-sdk/darwin/23/toolchains:$PATH"
D="${DEVICE:-127.0.0.1:55557}"
case "${1:-}" in
  shot)  hdc -t "$D" shell "snapshot_display -f /data/local/tmp/shot.jpeg" >/dev/null
         mkdir -p docs/screenshots && hdc -t "$D" file recv /data/local/tmp/shot.jpeg "docs/screenshots/$2.jpeg" >/dev/null
         echo "docs/screenshots/$2.jpeg" ;;
  tap)   hdc -t "$D" shell "uitest uiInput click $2 $3" ;;
  swipe) hdc -t "$D" shell "uitest uiInput swipe $2 $3 $4 $5 600" ;;
  texts) hdc -t "$D" shell "uitest dumpLayout -p /data/local/tmp/l.json" >/dev/null
         hdc -t "$D" file recv /data/local/tmp/l.json /tmp/wisp-layout.json >/dev/null
         python3 - <<'PY'
import json
def walk(n):
    a = n.get('attributes', {})
    if a.get('text'): print(a.get('type'), '|', a['text'], '|', a.get('bounds'))
    for c in n.get('children', []): walk(c)
walk(json.load(open('/tmp/wisp-layout.json')))
PY
         ;;
  text)  hdc -t "$D" shell "uitest uiInput text $2" ;;
  *) echo "usage: $0 shot <name> | tap x y | swipe x1 y1 x2 y2 | texts"; exit 1 ;;
esac
