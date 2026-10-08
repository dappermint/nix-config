import json
import os
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import numpy as np
import serial

DEVICE = os.environ.get("WAVES_DEVICE", "/dev/ttyACM0")
CENTER_MHZ = int(os.environ.get("WAVES_CENTER_MHZ", "2442"))
LISTEN = os.environ.get("WAVES_LISTEN", "127.0.0.1:8090")
RATE_MHZ = 80  # the c6 firmware only exposes rate 0 (80 MS/s complex)
SAMPLES = 8192
NFFT = 512

frame = None
clients = 0
cond = threading.Condition()


def spectrum(raw, nfft=NFFT):
    iq = np.frombuffer(raw, dtype=np.int8).astype(np.float32)
    x = iq[0::2] + 1j * iq[1::2]
    x = x - x.mean()
    x = x[: len(x) // nfft * nfft].reshape(-1, nfft) * np.hanning(nfft)
    p = np.abs(np.fft.fftshift(np.fft.fft(x, axis=1), axes=1)) ** 2
    return 10 * np.log10(p.mean(axis=0) + 1e-9)


def command(s, text):
    s.write((text + "\r\n").encode())
    while True:
        line = s.readline()
        if not line:
            raise OSError(f"{text}: no reply")
        line = line.decode(errors="replace").strip()
        if line.startswith("ERR"):
            raise OSError(f"{text}: {line}")
        if line == "OK" or line.startswith("DATA"):
            return line


def capture(s):
    n = int(command(s, f"CAP16 {SAMPLES} 0").split()[1])
    raw = s.read(2 * n)
    if len(raw) != 2 * n:
        raise OSError(f"short read {len(raw)}/{2 * n}")
    return raw


def radio():
    global frame
    while True:
        try:
            with serial.Serial(DEVICE, 115200, timeout=3) as s:
                s.reset_input_buffer()
                command(s, f"FREQ {CENTER_MHZ}")
                print(f"radio: {DEVICE} tuned to {CENTER_MHZ} MHz", flush=True)
                while True:
                    with cond:
                        cond.wait_for(lambda: clients > 0)
                    db = spectrum(capture(s))
                    data = {"f0": CENTER_MHZ - RATE_MHZ / 2, "span": RATE_MHZ, "db": np.round(db, 1).tolist()}
                    with cond:
                        frame = json.dumps(data, separators=(",", ":")).encode()
                        cond.notify_all()
                    # ponytail: fixed ~10 fps cap so the weak host stays idle, make it an env knob if needed
                    time.sleep(0.1)
        except (OSError, ValueError, IndexError) as e:
            print(f"radio: {e}", file=sys.stderr, flush=True)
            time.sleep(2)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/events":
            return self.events()
        if self.path not in ("/", "/index.html"):
            return self.send_error(404)
        body = PAGE.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def events(self):
        global clients
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        with cond:
            clients += 1
            cond.notify_all()
        last = None
        try:
            while True:
                with cond:
                    cond.wait_for(lambda: frame is not last, timeout=15)
                    cur = frame
                if cur is last:
                    self.wfile.write(b": ping\n\n")
                else:
                    self.wfile.write(b"data: " + cur + b"\n\n")
                    last = cur
                self.wfile.flush()
        except OSError:
            pass
        finally:
            with cond:
                clients -= 1

    def log_message(self, *args):
        pass


def selftest():
    t = np.arange(SAMPLES)
    tone = 100 * np.exp(2j * np.pi * (10 / RATE_MHZ) * t)
    raw = np.empty(2 * SAMPLES, np.int8)
    raw[0::2] = tone.real.astype(np.int8)
    raw[1::2] = tone.imag.astype(np.int8)
    db = spectrum(raw.tobytes())
    mhz = CENTER_MHZ - RATE_MHZ / 2 + db.argmax() * RATE_MHZ / NFFT
    assert abs(mhz - (CENTER_MHZ + 10)) < 0.5, mhz
    print(f"selftest ok: +10 MHz tone lands at {mhz:.2f} MHz")


PAGE = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>waves</title>
<style>
body{margin:0;background:#0b0b10;color:#ccc;font:13px ui-monospace,monospace}
header{display:flex;gap:1.5em;padding:6px 10px;align-items:baseline}
#st{color:#888}
canvas{display:block;width:100%}
</style>
<header><b>waves</b><span id="st">connecting</span><span id="pk"></span></header>
<canvas id="sp" height="240" role="img" aria-label="live 2.4 GHz spectrum"></canvas>
<canvas id="wf" height="420" role="img" aria-label="spectrum waterfall"></canvas>
<script>
const $=id=>document.getElementById(id),sp=$('sp'),wf=$('wf'),a=sp.getContext('2d'),b=wf.getContext('2d');
const stops=[[0,0,0],[0,0,140],[0,160,220],[240,220,0],[230,40,0],[255,255,255]];
const pal=[...Array(256)].map((_,i)=>{const x=i/255*(stops.length-1),k=Math.min(Math.floor(x),stops.length-2),f=x-k;return stops[k].map((c,j)=>c+(stops[k+1][j]-c)*f)});
let lo=null,hi=null,peak=null,frames=0;
const fit=()=>{sp.width=sp.clientWidth;wf.width=wf.clientWidth};addEventListener('resize',fit);fit();
setInterval(()=>{$('st').textContent=frames?`live ${frames} fps`:'waiting for frames';frames=0},1000);
function draw(d){
  const n=d.db.length,W=sp.width,H=sp.height,mn=Math.min(...d.db),mx=Math.max(...d.db);
  lo=lo===null?mn:lo*0.95+mn*0.05;hi=hi===null?mx:hi*0.95+mx*0.05;
  const r=Math.max(hi-lo,1),X=f=>(f-d.f0)/d.span*W,Y=v=>H-16-(v-lo)/r*(H-28);
  a.clearRect(0,0,W,H);a.font='11px monospace';a.strokeStyle='#222';a.fillStyle='#666';
  for(let f=Math.ceil(d.f0/10)*10;f<=d.f0+d.span;f+=10){a.beginPath();a.moveTo(X(f),12);a.lineTo(X(f),H-16);a.stroke();a.fillText(f,X(f)-14,H-3)}
  a.fillStyle='#8a8';for(const [c,f] of [[1,2412],[6,2437],[11,2462]])a.fillText('ch'+c,X(f)-10,10);
  peak=peak&&peak.length===n?peak.map((p,i)=>Math.max(p-0.2,d.db[i])):d.db.slice();
  const line=(v,c)=>{a.strokeStyle=c;a.beginPath();v.forEach((y,i)=>a[i?'lineTo':'moveTo'](i/(n-1)*W,Y(y)));a.stroke()};
  line(peak,'#a55');line(d.db,'#6cf');
  const k=d.db.indexOf(mx);$('pk').textContent=`peak ${(d.f0+k*d.span/n).toFixed(1)} MHz`;
  b.drawImage(wf,0,1);const row=b.createImageData(wf.width,1);
  for(let x=0;x<wf.width;x++){const v=d.db[Math.floor(x*n/wf.width)],c=pal[Math.max(0,Math.min(255,Math.round((v-lo)/r*255)))];row.data.set([c[0],c[1],c[2],255],x*4)}
  b.putImageData(row,0,0);frames++;
}
const es=new EventSource('events');
es.onmessage=e=>draw(JSON.parse(e.data));
es.onerror=()=>{$('st').textContent='reconnecting'};
</script>
</html>
"""

if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]:
        selftest()
        sys.exit()
    threading.Thread(target=radio, daemon=True).start()
    host, port = LISTEN.rsplit(":", 1)
    server = ThreadingHTTPServer((host, int(port)), Handler)
    server.daemon_threads = True
    server.serve_forever()
