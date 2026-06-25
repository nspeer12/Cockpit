# Cockpit — Hermes Holographic Command Interface

Tony Stark / JARVIS inspired macOS SwiftUI application — dark holographic dashboard for monitoring and controlling the Hermes AI agent ecosystem.

## Architecture

```
Sources/Cockpit/
├── App/
│   └── CockpitApp.swift          # @main entry point
├── Views/
│   ├── ContentView.swift         # Tab shell + Overview dashboard
│   ├── ProjectsView.swift        # Hermes-Projects scanner (git status, modified dates)
│   ├── NetworkView.swift         # Network devices, ping scanning, speed tests
│   ├── NodeView.swift            # Hermes node status (live system data)
│   ├── RemoteModelsStatusView.swift  # Remote model health checks
│   └── Common/
│       └── GlassButtonStyle.swift
├── 3D/
│   └── HolographicView.swift     # RealityKit 3D scene + holographic background/grid
└── Services/
    ├── SystemInfoService.swift   # Real macOS: hostname, CPU, memory, disk, uptime
    ├── InferenceService.swift    # Routes to Ollama, LM Studio, xAI APIs
    ├── NetworkQualityService.swift  # Apple networkQuality benchmark wrapper
    └── ProjectScanner.swift      # ~/Desktop/Hermes-Projects directory scanner
```

## Tabs

| Tab | Description |
|-----|-------------|
| **Overview** | Live holographic dashboard — rotating hex core, scanning lines, CPU/memory/disk/model metric cards, host identity bar |
| **Projects** | Scans `~/Desktop/Hermes-Projects/`, shows git status and last-modified |
| **Network** | Known devices table with ping scanning, Apple networkQuality speed tests with history |
| **Node** | Real Hermes node identity, inference config, system resources, remote agents, cron jobs (all live from `hermes` CLI) |
| **Overview** | *(hidden)* Remote model health checks against MacBook Ollama + Cyberbeast LM Studio |

## Aesthetic

- Dark theme with gradient backgrounds
- Neon cyan/blue/purple color palette
- Canvas-drawn holographic grid with animated scanning line
- Rotating hex-core with angular gradient rings
- Glassmorphism cards (.ultraThinMaterial)
- Glowing borders, monospaced type, tracking

## Tech Stack

- **SwiftUI** (macOS 15+)
- **RealityKit** (3D holographic elements)
- **Canvas API** (holographic grid, procedural drawing)
- **AVFoundation** (planned: camera + mic ambient awareness)
- **Process + sysctl** (live system metrics: hostname, CPU, memory, disk, uptime)
- **URLSession** (HTTP health checks + inference API calls)
- **hermes CLI** (config, profile, cron in NodeView)

## Build & Run

```bash
cd ~/Desktop/Hermes-Projects/Cockpit
swift build
swift run
```

Or open in Xcode:

```bash
open Package.swift
```

## Environment

- Requires macOS 15+ (Sequoia)
- `hermes` CLI must be on PATH for NodeView live data
- `XAI_API_KEY` env var needed for xAI inference routing
- `networkQuality` CLI (built-in macOS) for speed tests
