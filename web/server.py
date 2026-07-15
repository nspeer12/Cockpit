#!/usr/bin/env python3
"""Cockpit companion server: read-only status API, SSE stream, and installable PWA.

Run locally with ``python3 web/server.py``. For phone access, expose only through
Tailscale HTTPS; do not publish this diagnostics server to the public internet.
"""
from __future__ import annotations

import http.server
import json
import mimetypes
import os
import platform
import re
import socket
import subprocess
import time
from pathlib import Path
from urllib.parse import unquote, urlparse

PORT = 8080
HOST = "0.0.0.0"
WEB_ROOT = Path(__file__).resolve().parent
STATIC_ROOT = WEB_ROOT / "static"


def run_command(*command: str, timeout: float = 5) -> str:
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, check=False)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def get_uptime() -> float:
    if Path("/proc/uptime").exists():
        try:
            return float(Path("/proc/uptime").read_text().split()[0])
        except (OSError, ValueError, IndexError):
            pass
    boot_time = run_command("sysctl", "-n", "kern.boottime")
    match = re.search(r"sec\s*=\s*(\d+)", boot_time)
    return max(0, time.time() - int(match.group(1))) if match else 0


def get_memory() -> tuple[int, int]:
    total_output = run_command("sysctl", "-n", "hw.memsize")
    total = int(total_output) if total_output.isdigit() else 0
    vm_stat = run_command("vm_stat")
    pages: dict[str, int] = {}
    for line in vm_stat.splitlines():
        if ":" not in line:
            continue
        name, value = line.split(":", 1)
        try:
            pages[name.strip()] = int(value.strip().rstrip("."))
        except ValueError:
            continue
    page_size_match = re.search(r"page size of (\d+) bytes", vm_stat)
    page_size = int(page_size_match.group(1)) if page_size_match else 16_384
    used_pages = sum(pages.get(name, 0) for name in (
        "Pages active", "Pages wired down", "Pages occupied by compressor",
    ))
    return used_pages * page_size, total


def get_disk() -> tuple[int, int]:
    stats = os.statvfs(Path.home())
    total = stats.f_frsize * stats.f_blocks
    return total - (stats.f_frsize * stats.f_bavail), total


def get_cpu() -> tuple[int, float]:
    cores_output = run_command("sysctl", "-n", "hw.ncpu")
    cores = int(cores_output) if cores_output.isdigit() else 0
    load_match = re.search(r"([0-9]+(?:\.[0-9]+)?)", run_command("sysctl", "-n", "vm.loadavg"))
    return cores, float(load_match.group(1)) if load_match else 0.0


def get_hermes_model() -> str:
    for line in run_command("hermes", "config", "show").splitlines():
        if "Model:" in line:
            return line.partition("Model:")[2].strip()
    return "unknown"


def get_tailscale_nodes() -> int:
    status = run_command("tailscale", "status")
    return max(0, len([line for line in status.splitlines() if line.strip() and not line.startswith("Warning")]) - 1)


def api_stats() -> dict[str, object]:
    cores, load = get_cpu()
    memory_used, memory_total = get_memory()
    disk_used, disk_total = get_disk()
    uptime_seconds = get_uptime()
    days, remainder = divmod(int(uptime_seconds), 86_400)
    hours, remainder = divmod(remainder, 3_600)
    minutes = remainder // 60
    return {
        "hostname": socket.gethostname(),
        "os": platform.platform(),
        "uptime": f"{days}d {hours}h {minutes}m",
        "uptime_sec": uptime_seconds,
        "cpu": {"cores": cores, "load": round(load, 2), "percent": round(load / cores * 100, 1) if cores else 0},
        "memory": {"used_gb": round(memory_used / 1e9, 1), "total_gb": round(memory_total / 1e9, 1), "percent": round(memory_used / memory_total * 100, 1) if memory_total else 0},
        "disk": {"used_gb": round(disk_used / 1e9, 1), "total_gb": round(disk_total / 1e9, 1), "percent": round(disk_used / disk_total * 100, 1) if disk_total else 0},
        "model": get_hermes_model(),
        "tailscale_nodes": get_tailscale_nodes(),
        "timestamp": time.time(),
    }


class CockpitHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802 - HTTP handler API
        path = urlparse(self.path).path
        if path == "/health":
            self.send_bytes(200, b"ok", "text/plain; charset=utf-8")
        elif path == "/api/stats":
            self.send_bytes(200, json.dumps(api_stats()).encode(), "application/json; charset=utf-8")
        elif path == "/api/events":
            self.stream_events()
        else:
            self.serve_static(path)

    def send_bytes(self, status: int, payload: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def serve_static(self, request_path: str) -> None:
        relative = "index.html" if request_path in {"", "/"} else unquote(request_path).lstrip("/")
        candidate = (STATIC_ROOT / relative).resolve()
        if STATIC_ROOT not in candidate.parents and candidate != STATIC_ROOT:
            self.send_error(404)
            return
        if not candidate.is_file():
            self.send_error(404)
            return
        content_type = {
            ".webmanifest": "application/manifest+json; charset=utf-8",
            ".js": "application/javascript; charset=utf-8",
        }.get(candidate.suffix, mimetypes.guess_type(candidate.name)[0] or "application/octet-stream")
        payload = candidate.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-cache" if candidate.name == "service-worker.js" else "public, max-age=300")
        self.end_headers()
        self.wfile.write(payload)

    def stream_events(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        try:
            while True:
                self.wfile.write(f"data: {json.dumps(api_stats())}\n\n".encode())
                self.wfile.flush()
                time.sleep(3)
        except (BrokenPipeError, ConnectionResetError):
            return

    def log_message(self, format: str, *args: object) -> None:
        _ = (format, args)


def create_server(host: str = HOST, port: int = PORT) -> http.server.ThreadingHTTPServer:
    return http.server.ThreadingHTTPServer((host, port), CockpitHandler)


if __name__ == "__main__":
    print(f"Cockpit companion PWA at http://{HOST}:{PORT}")
    create_server().serve_forever()
