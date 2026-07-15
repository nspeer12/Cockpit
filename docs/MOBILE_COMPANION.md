# Cockpit Mobile Companion Strategy

## Decision
The first phone deliverable is an **installable PWA over Tailscale HTTPS**, not a parallel native iOS rewrite.

This gets Cockpit onto Nick's phone immediately, preserves private Tailnet-only access, needs no App Store or Xcode/iOS SDK installation, and reuses the live status API that the future native app will also consume. The phone companion is intentionally a quick read-only *glance surface*, not a compressed desktop dashboard.

## What exists now

- Responsive holographic dashboard optimized for a narrow phone screen.
- Install manifest and service worker, so supported browsers can install it as an app.
- Live updates over SSE, with polling fallback after a dropped stream.
- Read-only live CPU, memory, disk, active model, uptime, and Tailnet count.
- `/health` for supervision and `/api/stats` as the stable machine-readable contract.

## Phone installation

1. Start `python3 web/server.py` from the repository's `web/` directory (or run it from the project root as `python3 web/server.py`).
2. Bring up Tailscale and configure `tailscale serve --bg --https=443 http://127.0.0.1:8080`.
3. On the phone, join the same Tailnet and open the generated `https://<machine>.<tailnet>.ts.net` address.
4. In iPhone Safari use **Share → Add to Home Screen**. Android Chrome offers **Install app**.

The app works only while the phone can reach the Tailnet; cached UI resources remain available briefly offline, but metrics are intentionally never fabricated or stale-marked as live.

## Product scope by phase

### Phase 1 — Glance surface (implemented)
- system health and active model
- Tailnet-private installation
- no remote controls, credentials, ambient feeds, or LLM proxying

### Phase 2 — Safe remote operations
Add an authenticated Cockpit API gateway with:
- Tailscale identity verification or explicit device identity
- short-lived session tokens and role/scope checks
- append-only audit log
- action queue and idempotency keys
- server-side confirmation rules for destructive commands

Only then add low-risk actions: wake a known machine, refresh project scan, open a Hermes session, or acknowledge an alert.

### Phase 3 — Native iOS companion (when it earns its cost)
Create an iOS target only after Phase 2's API is stable. Build it with SwiftUI and share **API contracts, DTOs, formatting, and design tokens** with macOS; do not try to share RealityKit, AppKit, sysctl, camera capture, or the desktop view hierarchy.

Native iOS earns the investment for push notifications, widgets, background refresh, Face ID lock, Shortcuts, and a richer offline/cache model. This Mac currently has Command Line Tools only — no iPhone SDK/Xcode — so a native iOS target cannot be compiled or simulator-tested here today. The PWA avoids blocking on that tooling.

## Non-goals

- Public web exposure.
- Sending the Hermes API key or any model/provider credential to the phone/browser.
- Remote shell/tool execution from a browser before an explicit authorization and audit layer exists.
- Mirroring ambient camera or microphone data by default.

## Acceptance checks

```bash
python3 -m unittest discover -s web/tests -v
python3 web/server.py
curl -f http://127.0.0.1:8080/health
curl -f http://127.0.0.1:8080/manifest.webmanifest
```
