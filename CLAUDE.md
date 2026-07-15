# Cockpit — Hermes Holographic Command Interface

## Purpose
Cockpit is a private Hermes command interface with a native macOS control surface and an installable, read-only mobile companion PWA served privately over Tailscale.

## Build and test

```bash
cd ~/Desktop/Hermes-Projects/Cockpit
swift build
./scripts/test.sh
```

`./scripts/test.sh` runs both Swift Testing and Python PWA/server contract tests. The wrapper adds the Swift Testing paths required by the active Command Line Tools installation.

## Architecture

- `Sources/Cockpit/` — macOS 15+ SwiftUI executable; RealityKit, AppKit, AVFoundation, `sysctl`, and Hermes integration remain intentionally platform-local.
- `web/server.py` — read-only JSON/SSE transport and static PWA server.
- `web/static/` — mobile companion frontend; it is the canonical web UI (do not embed duplicate HTML in Python).
- `docs/ARCHITECTURE.md` — boundaries and target structure.
- `docs/MOBILE_COMPANION.md` — mobile product decision and security rules.

## Security

The companion is private and read-only. Expose it only through `tailscale serve --https`; never put it behind a public proxy. Do not add tool execution, ambient feeds, or credentials to the browser without a dedicated authorization, audit, and confirmation layer.

## Product constraints

- Preserve the dark cyan/purple holographic aesthetic.
- Use real local data rather than mocked metrics.
- Gemma 4 is the sole active Cockpit model direction; do not restore multi-model rotation logic.
- Xcode/iPhone SDK is not present on this Mac. The PWA is the immediate phone surface; a native SwiftUI iOS companion follows only once a stable authenticated gateway exists.
