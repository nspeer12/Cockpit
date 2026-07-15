# Cockpit — Hermes Command Interface

A private, high-tech **portal to reality** for the Hermes ecosystem. Cockpit has two complementary surfaces:

- **Native macOS cockpit** — the rich local command center: live hardware/network/project/Hermes data, local inference, JARVIS voice, and ambient camera/microphone awareness.
- **Mobile companion PWA** — a private, installable, read-only status dashboard for a phone over Tailscale HTTPS.

## Repository map

```text
Sources/Cockpit/  SwiftUI macOS 15+ app (Swift 6, no external packages)
Tests/            Swift Testing unit tests
web/
├── server.py     read-only status API + SSE transport
├── static/       responsive installable PWA assets
└── tests/        Python stdlib API/PWA contract tests
docs/             architecture and product decisions
scripts/          build and test wrappers
```

See [Architecture](docs/ARCHITECTURE.md) for boundaries and evolution rules, and [Mobile companion](docs/MOBILE_COMPANION.md) for the phone product decision.

## macOS app

```bash
cd ~/Desktop/Hermes-Projects/Cockpit
swift build
swift run Cockpit
```

The app requires macOS 15+, the `hermes` CLI for the Node view, and appropriate system permissions before camera/microphone/voice features can operate.

## Companion PWA

```bash
cd ~/Desktop/Hermes-Projects/Cockpit
python3 web/server.py
```

Local development: `http://127.0.0.1:8080`

Phone access: expose privately through Tailscale HTTPS, then install from Safari/Chrome. Do **not** make this diagnostic server public.

```bash
tailscale serve --bg --https=443 http://127.0.0.1:8080
```

The companion intentionally exposes only live read-only status: CPU, memory, disk, model, uptime, and Tailnet node count.

## Verification

```bash
./scripts/test.sh
python3 -m unittest discover -s web/tests -v
swift build
```

The Swift test wrapper is deliberate: the current macOS Command Line Tools layout requires explicit Swift Testing framework paths.
