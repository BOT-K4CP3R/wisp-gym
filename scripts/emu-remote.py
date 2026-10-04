#!/usr/bin/env python3
"""Browser remote for the Oniro emulator: live screen + real touch input over hdc.

The QEMU VNC pointer does not move the OpenHarmony cursor reliably, so this page shows
screenshots taken with `snapshot_display` and turns clicks / drags / wheel into touch
events injected with `uinput -T`. Usage:

    ./scripts/emu-remote.py            # then open http://localhost:8765
    DEVICE=127.0.0.1:55557 PORT=8765 ./scripts/emu-remote.py
"""
import os
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

HDC = os.path.expanduser("~/setup-ohos-sdk/darwin/23/toolchains/hdc")
DEVICE = os.environ.get("DEVICE", "127.0.0.1:55557")
PORT = int(os.environ.get("PORT", "8765"))
LOCAL = "/tmp/wisp-remote-frame.jpeg"

frame = b""
frame_id = 0
lock = threading.Lock()


def hdc(*args, timeout=20):
    return subprocess.run([HDC, "-t", DEVICE, *args], capture_output=True, timeout=timeout)


def shell(cmd):
    return hdc("shell", cmd)


def grabber():
    global frame, frame_id
    while True:
        try:
            shell("snapshot_display -f /data/local/tmp/remote.jpeg")
            hdc("file", "recv", "/data/local/tmp/remote.jpeg", LOCAL)
            with open(LOCAL, "rb") as f:
                data = f.read()
            if data:
                with lock:
                    frame = data
                    frame_id += 1
        except Exception as e:  # keep going; the emulator may be busy
            print("grab failed:", e)
            time.sleep(1)


def act(kind, q):
    n = lambda k: str(int(float(q.get(k, ["0"])[0])))
    if kind == "tap":
        shell(f"uinput -T -c {n('x')} {n('y')} 60")
    elif kind == "swipe":
        shell(f"uinput -T -m {n('x1')} {n('y1')} {n('x2')} {n('y2')} {n('ms')}")
    elif kind == "key":
        code = {"back": "2", "home": "1"}.get(q.get("k", ["back"])[0], "2")
        shell(f"uinput -K -d {code} -u {code}")
    elif kind == "text":
        txt = q.get("t", [""])[0].replace("'", "")
        if txt:
            shell(f"uinput -K -t '{txt}'")


PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>Wisp emulator</title>
<style>
body{margin:0;background:#111;color:#ddd;font:14px -apple-system,sans-serif;display:flex;gap:16px;
padding:16px;align-items:flex-start;justify-content:center;height:100vh;box-sizing:border-box;overflow:hidden}
#scr{height:calc(100vh - 32px);max-height:1080px;aspect-ratio:1/2;width:auto;max-width:calc(100vw - 230px);
border-radius:24px;box-shadow:0 0 0 2px #333;cursor:pointer;user-select:none;-webkit-user-drag:none;object-fit:contain;
display:block;background:#000}
.side{display:flex;flex-direction:column;gap:8px;width:180px}
button{padding:10px;border-radius:10px;border:1px solid #444;background:#222;color:#eee;font-size:14px;cursor:pointer}
button:hover{background:#2c2c2c} #st{color:#888;font-size:12px} input{padding:8px;border-radius:8px;border:1px solid #444;
background:#1a1a1a;color:#eee}
</style></head><body>
<img id="scr" draggable="false">
<div class="side">
 <b>Wisp Gym emulator</b>
 <button onclick="key('back')">◁ Back</button>
 <button onclick="key('home')">○ Home</button>
 <input id="tx" placeholder="type text, Enter"><span id="st">connecting…</span>
 <span style="color:#888;font-size:12px">Click = tap, drag = swipe, wheel = scroll.
 Each action takes a moment on the software emulator.</span>
</div>
<script>
const img=document.getElementById('scr'),st=document.getElementById('st');
let last=-1,down=null;
async function loop(){
  try{const r=await fetch('/id');const id=+(await r.text());
    if(id!==last){last=id;img.src='/frame.jpg?'+id;}
    st.textContent='live';}catch(e){st.textContent='waiting for emulator…';}
  setTimeout(loop,250);}
loop();
function pos(e){const b=img.getBoundingClientRect();
  return [Math.round((e.clientX-b.left)*360/b.width),Math.round((e.clientY-b.top)*720/b.height)];}
function send(u){st.textContent='sending…';fetch(u,{method:'POST'});}
img.addEventListener('mousedown',e=>{down=pos(e);down.push(Date.now());});
img.addEventListener('mouseup',e=>{if(!down)return;const p=pos(e);const dx=p[0]-down[0],dy=p[1]-down[1];
  if(Math.abs(dx)+Math.abs(dy)<8) send(`/tap?x=${p[0]}&y=${p[1]}`);
  else send(`/swipe?x1=${down[0]}&y1=${down[1]}&x2=${p[0]}&y2=${p[1]}&ms=${Math.max(200,Math.min(1200,Date.now()-down[2]))}`);
  down=null;});
let wt=null,acc=0,wp=null;
img.addEventListener('wheel',e=>{e.preventDefault();acc+=e.deltaY;wp=pos(e);clearTimeout(wt);
  wt=setTimeout(()=>{const d=Math.max(-300,Math.min(300,acc));acc=0;
    const y2=Math.max(40,Math.min(680,wp[1]-d));send(`/swipe?x1=${wp[0]}&y1=${wp[1]}&x2=${wp[0]}&y2=${y2}&ms=350`);},120);},{passive:false});
function key(k){send('/key?k='+k);}
document.getElementById('tx').addEventListener('keydown',e=>{if(e.key==='Enter'){send('/text?t='+encodeURIComponent(e.target.value));e.target.value='';}});
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _send(self, code, body, ctype):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            self._send(200, PAGE.encode(), "text/html; charset=utf-8")
        elif path == "/id":
            with lock:
                self._send(200, str(frame_id).encode(), "text/plain")
        elif path == "/frame.jpg":
            with lock:
                data = frame
            self._send(200 if data else 503, data, "image/jpeg")
        else:
            self._send(404, b"", "text/plain")

    def do_POST(self):
        u = urlparse(self.path)
        kind = u.path.strip("/")
        threading.Thread(target=act, args=(kind, parse_qs(u.query)), daemon=True).start()
        self._send(204, b"", "text/plain")


if __name__ == "__main__":
    threading.Thread(target=grabber, daemon=True).start()
    print(f"Emulator remote on http://localhost:{PORT}  (device {DEVICE})")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
