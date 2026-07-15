# Cockpit Architecture

## Purpose
Cockpit is Nick's private **portal to reality**: a native macOS command center for local control and rich ambient awareness, plus a lightweight companion surface for checking the same system from a phone.

## Current, working topology

```text
Mac Mini
├── Cockpit macOS app (SwiftUI / RealityKit)
│   ├── live local metrics and project/network/Hermes views
│   ├── local inference and ambient camera/microphone features
│   └── JARVIS voice controls
└── Cockpit companion server (Python stdlib)
    ├── GET /api/stats        read-only JSON status contract
    ├── GET /api/events       server-sent live status stream
    ├── GET /health           health probe
    └── web/static/           installable responsive PWA shell
         └── exposed privately through Tailscale HTTPS
```

The companion server is deliberately **read-only**. It contains no credentials and does not proxy model inference, the Hermes execution surface, camera, or microphone. That is the right boundary while it is reachable from a phone.

## Repository layout

```text
Sources/Cockpit/      Native macOS executable
├── App/              app entry point / lifecycle
├── 3D/               RealityKit scene and holographic background
├── Models/            simple domain presentation models
├── Services/          macOS-only data and integrations
└── Views/             feature UI + shared holographic components
web/                  Cross-device companion
├── server.py          API, SSE, static-file server
├── static/            PWA assets; no embedded HTML in Python
└── tests/             Python stdlib server contract tests
Tests/                Swift Testing unit tests
scripts/              deterministic local checks and build helpers
docs/                 architecture and product decisions
```

## Structural assessment

The macOS app is a healthy prototype: it has already been separated from its original monolithic `ContentView` into reusable navigation, overview, service, model, and component files. It builds successfully and the existing Swift test suite passes using the project test wrapper.

The main structural debt is **feature ownership**, not an urgent file move:

1. `InferencePanelView.swift` (858 lines), `HolographicView.swift` (775), and `JarvisOverlay.swift` (503) should be split only when their next feature changes; mechanical extraction now would add churn without improving a user-facing outcome.
2. The code is macOS-only by design (`Package.swift` declares macOS 15) and combines hardware access with presentation. That is correct for the native cockpit but should never be copied directly into a phone target.
3. The former web dashboard duplicated HTML in `server.py` while a stale `web/index.html` existed separately. The PWA now has one canonical frontend in `web/static/`; Python owns only API/transport.
4. Project docs had fallen behind the implemented tabs and service layout. `README.md` is now the short entry point; this document is the durable architectural reference.

## Target structure — evolve, do not rewrite

When a native feature needs substantial work, move only that feature into this shape:

```text
Sources/Cockpit/
├── App/
├── Core/
│   ├── DesignSystem/          Glassmorphism components and theme tokens
│   ├── Models/
│   └── Services/              cross-feature abstractions
├── Features/
│   ├── Overview/
│   ├── Inference/
│   ├── Network/
│   ├── Node/
│   ├── Ambient/
│   └── Projects/
└── Platform/macOS/            AppKit, sysctl, camera/mic, RealityKit adapters
```

Keep `Services` behind small protocols when a UI needs deterministic testing. Keep all macOS-only imports in `Platform/macOS`; this creates an eventual route to a shared data model without pretending that the full desktop visual layer is portable.

## Security boundary

- Bind the server as needed for local/Tailnet routing, but publish it only with `tailscale serve --https`.
- Do not expose port 8080 directly to the public internet or add `--https` forwarding from a public reverse proxy.
- Keep phone features read-only until the server has explicit identity, authorization scopes, audit history, and confirmation semantics for actions.

## Verification

```bash
./scripts/test.sh
python3 -m unittest discover -s web/tests -v
swift build
```

`./scripts/test.sh` is required because the active Command Line Tools installation needs explicit Swift Testing framework paths.
