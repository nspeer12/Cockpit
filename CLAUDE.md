# Cockpit — Hermes Holographic Command Interface

Tony Stark / JARVIS inspired macOS SwiftUI app. Dark holographic dashboard for monitoring Hermes AI agent ecosystem.

## Build & Run
```bash
cd ~/Desktop/Hermes-Projects/Cockpit
swift build
swift run
```
Or: `open Package.swift` → Xcode

## Architecture
- **SwiftUI** (macOS 15+, Sequoia) — Swift 6, SPM, no external deps
- **RealityKit** — 3D holocore background (HolographicView.swift)
- **Canvas API** — procedural grid, scanning lines, animated overlays
- **AppKit** — NSStatusBar menu bar extra (live Ollama status)
- **sysctl + Process** — real system metrics (CPU, memory, disk, uptime)
- **URLSession** — HTTP health checks to Ollama/LM Studio endpoints
- **hermes CLI** — NodeView reads live hermes config/cron/profile data

## Project Structure
```
Sources/Cockpit/
├── App/CockpitApp.swift           # @main + AppDelegate (menu bar)
├── Views/
│   ├── ContentView.swift          # Tab shell (6 tabs) + JARVIS overlay
│   ├── OverviewView.swift         # Holo hex-core dashboard with metric cards
│   ├── InferencePanelView.swift   # Local/remote model inference panel
│   ├── ProjectsView.swift         # ~/Desktop/Hermes-Projects scanner
│   ├── NetworkView.swift          # Ping scan + Apple networkQuality tests
│   ├── NodeView.swift             # Live hermes config/cron/agent data
│   ├── RemoteModelsStatusView.swift # Remote model health checks
│   ├── AmbientDashboardView.swift # Camera + mic ambient awareness
│   ├── JarvisOverlay.swift        # JARVIS voice assistant overlay
│   ├── JarvisButton.swift         # JARVIS toggle button
│   ├── CameraFeedView.swift       # Live camera feed
│   ├── CameraPreviewView.swift    # Camera preview
│   ├── AudioLevelMeterView.swift  # Audio level visualization
│   ├── MicLevelMeterView.swift    # Mic level meter
│   └── Common/GlassButtonStyle.swift
├── 3D/HolographicView.swift       # RealityKit scene + 3D grid
├── Models/                        # Data models
├── Services/
│   ├── SystemInfoService.swift    # sysctl-based CPU/memory/disk/uptime
│   ├── InferenceService.swift     # Route to Ollama, LM Studio, xAI
│   ├── NetworkQualityService.swift # macOS networkQuality wrapper
│   ├── ProjectScanner.swift       # Directory scanner with git status
│   ├── MLXService.swift           # MLX local inference
│   ├── AmbientAwarenessManager.swift # Camera + mic manager
│   └── JarvisController.swift     # Voice assistant controller
└── Resources/
```

## Current State (June 25, 2026)
- **6,378 lines** of Swift across ~22 files
- 7 files modified (1,939 additions, 119 deletions since last commit)
- 10+ files untracked (never committed)
- Only 1 commit in repo: "Initial Cockpit structure"
- **Builds clean** — `swift build` succeeds

## 6 Tabs
| Tab | Cmd | Description |
|-----|-----|-------------|
| Overview | ⌘1 | Holographic hex-core dashboard, live sysctl metrics |
| Inference | ⌘2 | Local/remote model panel (Ollama, LM Studio, xAI) |
| Projects | ⌘3 | Hermes-Projects scanner with git status |
| Network | ⌘4 | Device ping scan + networkQuality speed tests |
| Node | ⌘5 | Live hermes CLI data (config, cron, profiles) |
| Ambient | — | Camera + mic ambient awareness (new) |

## Aesthetic Requirements (NON-NEGOTIABLE)
- **Dark theme** — #0a0a0f base, gradients to #0d1b2a, #1a1a2e
- **Neon cyan/blue/purple palette** — #00d4ff (cyan), #7b2ff7 (purple), #00ff88 (green accents)
- **Holographic grid** — Canvas-drawn with animated scanning line
- **Glassmorphism** — .ultraThinMaterial, .regularMaterial, blur effects
- **Glowing borders** — shadow with neon colors, thin 1-2px borders
- **Monospaced type** — SF Mono for data/metrics, SF Pro for UI labels
- **Tony Stark aesthetic** — angular, high-tech, holographic, animated

## Key Services
- **SystemInfoService** — Reads real data via sysctl: hostname, CPU cores/usage, physical memory, disk capacity, uptime
- **InferenceService** — URLSession to Ollama (localhost:11434), LM Studio (localhost:1234), xAI API
- **NetworkQualityService** — Runs macOS `networkQuality` CLI, parses JSON output
- **ProjectScanner** — Scans ~/Desktop/Hermes-Projects/, reads git status for each
- **JarvisController** — NSSpeechRecognizer + AVSpeechSynthesizer for voice commands

## Tech Constraints
- macOS 15+ ONLY (Sequoia features available)
- Swift 6 concurrency (strict sendable checking)
- No external Swift package dependencies
- `hermes` CLI must be on PATH for NodeView
- `XAI_API_KEY` in env for xAI routing
- `networkQuality` is built-in macOS tool

## User's Vision
- "Portal to reality" — always-on, high-tech dashboard
- Camera + mic for ambient awareness
- Cross-platform (Mac native + web via cockpit-web)
- Tony Stark / JARVIS level of polish
- Deep Hermes agentic integration
- Dark holographic aesthetic with live animations