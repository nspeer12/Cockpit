#!/usr/bin/env python3
"""Cockpit Web Dashboard — serves live system stats behind Tailscale HTTPS."""
import http.server
import json
import os
import platform
import socket
import subprocess
import sys
import time
import urllib.parse

PORT = 8080
HOST = "0.0.0.0"

def get_uptime():
    try:
        import struct
        with open('/proc/uptime') as f:  # Linux
            return float(f.readline().split()[0])
    except FileNotFoundError:
        pass
    # macOS
    r = subprocess.run(['sysctl', '-n', 'kern.boottime'], capture_output=True, text=True)
    if r.returncode == 0:
        import re
        m = re.search(r'sec\s*=\s*(\d+)', r.stdout)
        if m:
            return time.time() - int(m.group(1))
    return 0

def get_memory():
    try:
        r = subprocess.run(['sysctl', '-n', 'hw.memsize'], capture_output=True, text=True)
        total = int(r.stdout.strip()) if r.returncode == 0 else 0
    except Exception:
        total = 0

    try:
        r = subprocess.run(['vm_stat'], capture_output=True, text=True)
        pages = {}
        for line in r.stdout.split('\n'):
            if ':' in line:
                key, val = line.split(':')
                try:
                    pages[key.strip()] = int(val.strip().rstrip('.'))
                except ValueError:
                    pass
        page_size = 16384  # Apple Silicon default
        used = ((pages.get('Pages active', 0) + pages.get('Pages wired down', 0) +
                 pages.get('Pages occupied by compressor', 0)) * page_size)
        return int(used), total
    except Exception:
        return 0, total

def get_disk():
    s = os.statvfs(os.path.expanduser('~'))
    total = s.f_frsize * s.f_blocks
    free = s.f_frsize * s.f_bavail
    return total - free, total

def get_cpu():
    try:
        r = subprocess.run(['sysctl', '-n', 'hw.ncpu'], capture_output=True, text=True)
        cores = int(r.stdout.strip()) if r.returncode == 0 else 0
    except Exception:
        cores = 0
    # Load average
    try:
        r = subprocess.run(['sysctl', '-n', 'vm.loadavg'], capture_output=True, text=True)
        # Format: "{ 1.23 0.89 0.67 }"
        load = r.stdout.strip().strip('{}').split()
        load1 = float(load[0]) if load else 0
    except Exception:
        load1 = 0
    return cores, load1

def get_hermes_model():
    try:
        r = subprocess.run(['hermes', 'config', 'show'], capture_output=True, text=True, timeout=5)
        for line in r.stdout.split('\n'):
            if 'Model:' in line:
                return line.split('Model:')[1].strip()
    except Exception:
        pass
    return 'unknown'

def get_tailscale_status():
    try:
        r = subprocess.run(['tailscale', 'status'], capture_output=True, text=True, timeout=5)
        nodes = []
        for line in r.stdout.split('\n'):
            if line.strip() and not line.startswith('Warning'):
                nodes.append(line.strip())
        return nodes[1:] if len(nodes) > 1 else []
    except Exception:
        return []

def api_stats():
    cores, load1 = get_cpu()
    mem_used, mem_total = get_memory()
    disk_used, disk_total = get_disk()
    uptime_sec = get_uptime()

    days = int(uptime_sec // 86400)
    hours = int((uptime_sec % 86400) // 3600)
    mins = int((uptime_sec % 3600) // 60)

    return {
        'hostname': socket.gethostname(),
        'os': platform.platform(),
        'uptime': f'{days}d {hours}h {mins}m',
        'uptime_sec': uptime_sec,
        'cpu': {'cores': cores, 'load': round(load1, 2), 'percent': round((load1 / cores * 100) if cores else 0, 1)},
        'memory': {'used_gb': round(mem_used / 1e9, 1), 'total_gb': round(mem_total / 1e9, 1), 'percent': round(mem_used / mem_total * 100, 1) if mem_total else 0},
        'disk': {'used_gb': round(disk_used / 1e9, 1), 'total_gb': round(disk_total / 1e9, 1), 'percent': round(disk_used / disk_total * 100, 1) if disk_total else 0},
        'model': get_hermes_model(),
        'tailscale_nodes': len(get_tailscale_status()),
        'timestamp': time.time(),
    }

HTML_DASHBOARD = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>COCKPIT — Hermes Command Interface</title>
<style>
:root {
  --bg: #060610;
  --surface: rgba(255,255,255,0.03);
  --border: rgba(0,255,255,0.12);
  --cyan: #00e5ff;
  --purple: #b388ff;
  --green: #69f0ae;
  --orange: #ffab40;
  --red: #ff5252;
  --text: #e0e0e0;
  --dim: rgba(255,255,255,0.35);
  --font: 'SF Mono', 'JetBrains Mono', 'Fira Code', monospace;
}
* { margin:0; padding:0; box-sizing:border-box; }
body {
  background: var(--bg);
  color: var(--text);
  font-family: var(--font);
  min-height: 100vh;
  overflow-x: hidden;
}
.bg-grid {
  position: fixed; inset:0; pointer-events:none; z-index:0;
  background-image:
    linear-gradient(rgba(0,255,255,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,255,255,0.03) 1px, transparent 1px);
  background-size: 40px 40px;
}
.scanline {
  position: fixed; top:0; left:0; right:0; height:2px; z-index:1; pointer-events:none;
  background: linear-gradient(90deg, transparent, rgba(0,255,255,0.15), rgba(0,255,255,0.3), rgba(0,255,255,0.15), transparent);
  animation: scan 3s linear infinite;
  box-shadow: 0 0 20px rgba(0,255,255,0.2);
}
@keyframes scan { 0% { top:-2px; } 100% { top:100%; } }
.container { position:relative; z-index:2; max-width:900px; margin:0 auto; padding:30px 20px; }
.hero {
  display:flex; align-items:center; gap:30px; margin-bottom:40px; padding-bottom:30px;
  border-bottom:1px solid var(--border);
}
.hex-core {
  width:80px; height:80px; position:relative;
  animation: rotate 10s linear infinite;
}
.hex-core::before {
  content:''; position:absolute; inset:5px;
  border:2px solid var(--cyan); border-radius:50%;
  clip-path: polygon(50% 0%, 100% 25%, 100% 75%, 50% 100%, 0% 75%, 0% 25%);
}
.hex-core::after {
  content:''; position:absolute; inset:0;
  border:1px solid var(--purple); border-radius:50%;
  animation: pulse 2s ease-in-out infinite;
}
@keyframes rotate { to { transform:rotate(360deg); } }
@keyframes pulse { 0%,100% { transform:scale(1); opacity:0.3; } 50% { transform:scale(1.3); opacity:0.8; } }

.hero h1 {
  font-size:42px; font-weight:900; letter-spacing:-1px;
  background: linear-gradient(135deg, var(--cyan), #448aff, var(--purple));
  -webkit-background-clip:text; -webkit-text-fill-color:transparent;
}
.hero .sub { color:var(--dim); font-size:13px; letter-spacing:3px; text-transform:uppercase; margin-top:4px; }

.metrics { display:grid; grid-template-columns:repeat(auto-fit, minmax(190px,1fr)); gap:16px; margin-bottom:30px; }
.card {
  background:var(--surface); border:1px solid var(--border); border-radius:12px;
  padding:18px; backdrop-filter:blur(12px); -webkit-backdrop-filter:blur(12px);
  transition: border-color 0.3s;
}
.card:hover { border-color:rgba(0,255,255,0.3); }
.card .label { font-size:11px; color:var(--dim); letter-spacing:1.5px; text-transform:uppercase; margin-bottom:8px; }
.card .value { font-size:22px; font-weight:700; }
.card .sub { font-size:11px; color:var(--dim); margin-top:4px; }
.card.cpu .value { color: var(--cyan); }
.card.mem .value { color: var(--purple); }
.card.disk .value { color: var(--orange); }
.card.model .value { color: var(--green); font-size:14px; }

.status-bar {
  display:flex; justify-content:space-between; align-items:center;
  padding:14px 20px; background:var(--surface); border:1px solid var(--border);
  border-radius:10px; font-size:12px; color:var(--dim);
}
.status-dot { width:8px; height:8px; background:var(--green); border-radius:50%;
  box-shadow: 0 0 8px var(--green); margin-right:8px; display:inline-block; }
.status-dot.off { background:var(--red); box-shadow: 0 0 8px var(--red); }

.footer { text-align:center; margin-top:30px; color:var(--dim); font-size:11px; }
.refresh { color:var(--dim); font-size:10px; text-align:right; margin-bottom:16px; }
</style>
</head>
<body>
<div class="bg-grid"></div>
<div class="scanline"></div>
<div class="container">
  <div class="hero">
    <div class="hex-core"></div>
    <div>
      <h1>COCKPIT</h1>
      <div class="sub">Hermes Command Interface</div>
    </div>
  </div>

  <div class="refresh"><span id="last-refresh">—</span> · <span id="conn-status" style="color:var(--cyan)">SSE</span></div>

  <div class="metrics">
    <div class="card cpu">
      <div class="label">CPU</div>
      <div class="value" id="cpu-val">—</div>
      <div class="sub" id="cpu-sub"></div>
    </div>
    <div class="card mem">
      <div class="label">MEMORY</div>
      <div class="value" id="mem-val">—</div>
      <div class="sub" id="mem-sub"></div>
    </div>
    <div class="card disk">
      <div class="label">DISK</div>
      <div class="value" id="disk-val">—</div>
      <div class="sub" id="disk-sub"></div>
    </div>
    <div class="card model">
      <div class="label">ACTIVE MODEL</div>
      <div class="value" id="model-val">—</div>
      <div class="sub" id="model-sub"></div>
    </div>
  </div>

  <div class="status-bar">
    <span><span class="status-dot" id="dot"></span><span id="hostname">—</span></span>
    <span id="uptime">—</span>
    <span id="ts-nodes">—</span>
    <span>ALL SYSTEMS NOMINAL</span>
  </div>

  <div class="footer">
    Tailscale HTTPS · nicks-mac-mini.sparrow-iguana.ts.net · Cockpit v1.0
  </div>
</div>

<script>
function updateDashboard(s) {
  document.getElementById('cpu-val').textContent = s.cpu.load.toFixed(1) + ' / ' + s.cpu.cores;
  document.getElementById('cpu-sub').textContent = s.cpu.percent.toFixed(1) + '% · ' + s.cpu.cores + ' cores';
  document.getElementById('mem-val').textContent = s.memory.used_gb.toFixed(1) + ' GB';
  document.getElementById('mem-sub').textContent = 'of ' + s.memory.total_gb.toFixed(0) + ' GB · ' + s.memory.percent.toFixed(1) + '%';
  document.getElementById('disk-val').textContent = s.disk.used_gb.toFixed(1) + ' GB';
  document.getElementById('disk-sub').textContent = 'of ' + s.disk.total_gb.toFixed(0) + ' GB · ' + s.disk.percent.toFixed(1) + '%';
  document.getElementById('model-val').textContent = s.model || '—';
  document.getElementById('model-sub').textContent = s.os.split('-')[0] || '';
  document.getElementById('hostname').textContent = s.hostname;
  document.getElementById('uptime').textContent = 'UPTIME ' + s.uptime;
  document.getElementById('ts-nodes').textContent = s.tailscale_nodes + ' Tailnet nodes';
  document.getElementById('last-refresh').textContent = new Date().toLocaleTimeString();
}

// SSE — real-time push
const evtSource = new EventSource('/api/events');
evtSource.onmessage = function(e) {
  try {
    updateDashboard(JSON.parse(e.data));
  } catch(_) {}
};
evtSource.onerror = function() {
  document.getElementById('conn-status').textContent = 'FALLBACK';
  document.getElementById('conn-status').style.color = 'var(--orange)';
  // Fallback to polling
  evtSource.close();
  setInterval(async function() {
    try {
      const r = await fetch('/api/stats');
      const s = await r.json();
      updateDashboard(s);
    } catch(_) {}
  }, 3000);
};
</script>
</body>
</html>'''

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path == '/api/stats':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(api_stats()).encode())
        elif path == '/api/events':
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Connection', 'keep-alive')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                while True:
                    data = json.dumps(api_stats())
                    self.wfile.write(f'data: {data}\n\n'.encode())
                    self.wfile.flush()
                    time.sleep(3)
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(HTML_DASHBOARD.encode())

    def log_message(self, format, *args):
        pass  # silence logs

if __name__ == '__main__':
    print(f'Cockpit web dashboard on http://{HOST}:{PORT}')
    http.server.HTTPServer((HOST, PORT), Handler).serve_forever()
