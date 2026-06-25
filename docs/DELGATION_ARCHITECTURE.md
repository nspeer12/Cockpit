# Hermes Multi-Agent Delegation Architecture

## Node Roles

### Mac Mini (Orchestrator) — `Nicks-Mac-mini`
- **Role:** Primary orchestrator, always-on server, Cockpit host
- **Profile:** `default`
- **Model:** deepseek-v4-pro (OpenRouter) ← primary; grok-4.3 (xAI) ← high-stakes
- **Responsibilities:**
  - Cockpit dashboard (this app)
  - Kanban board dispatch and task routing
  - Persistent cron jobs (daily briefs, health checks, dispatcher)
  - Session management and memory storage
  - Web searches, API integrations, GitHub ops
  - Delegation: spawns workers on remote nodes for heavy inference

### MacBook Pro (Mobile Worker) — `macbook-pro-5`
- **Role:** Client-work machine, mobile inference node
- **Profile:** `macbook-pro` (to be configured)
- **Model:** Ollama (local) ← gemma3:27b, llama3.2, etc.
- **Responsibilities:**
  - Ollama model serving (port 11434)
  - Client/consulting project work
  - Light inference tasks delegated from Mac Mini
  - Mobile availability for on-the-go agent access
- **Access:** Tailscale (macbook-pro-5.sparrow-iguana.ts.net)

### Cyberbeast (Heavy Inference) — `cyberbeast`
- **Role:** Heavy compute node, LM Studio inference server
- **Profile:** `cyberbeast` (to be configured)
- **Model:** LM Studio (local) ← gemma-3-27b-it, etc.
- **Responsibilities:**
  - LM Studio model serving (port 1234)
  - Heavy/long-running inference tasks
  - Batch processing, data analysis, model experimentation
  - GPU-accelerated workloads
- **Access:** Tailscale (cyberbeast.sparrow-iguana.ts.net) + LAN (192.168.1.19)

## Task Routing Logic

```
Incoming Task
    │
    ├── Cockpit/SwiftUI dev
    
    │       → Mac Mini (default profile, direct execution)
    │
    ├── Heavy inference / batch / data-science
    │       → Cyberbeast (LM Studio)
    │       Fallback: Mac Mini (grok-4.3) if Cyberbeast unreachable
    │
    ├── Client/consulting work
    │       → MacBook Pro (ollama local)
    │       Fallback: Mac Mini if MacBook Pro offline
    │
    ├── Quick data tasks / code explanation / tool testing
    │       → Round-robin across available remote nodes
    │       Fallback: Mac Mini
    │
    └── Research / web / API calls
            → Mac Mini (default, has web search + API tools)
```

## Delegation Patterns

### Pattern 1: Fan-Out Research
```
Orchestrator creates N parallel research cards
    ├── T1 → Cyberbeast (docs analysis)
    ├── T2 → MacBook Pro (code search)
    └── T3 → Mac Mini (web research)
All feed into synthesis card on Mac Mini
```

### Pattern 2: Pipeline (Plan → Implement → Review)
```
T1: Plan      → Mac Mini (orchestrator, high-quality model)
T2: Implement → Cyberbeast (heavy coding)
T3: Review    → Mac Mini (grok-4.3 for critical review)
```

### Pattern 3: Fire-and-Forget Batch
```
T1: Batch process → Cyberbeast (LM Studio, long timeout)
Result stored to file, health check pings orchestrator
```

### Pattern 4: Local-First with Remote Fallback
```
Try MacBook Pro Ollama → if offline/unresponsive → Mac Mini direct
```

## Health Monitoring

- Cockpit RemoteModelsStatusView pings all endpoints every refresh
- Cron job `remote-models-health` runs every 6h
- NodeView shows live agent status from health checks
- Wake-on-LAN for Cyberbeast (planned) to auto-power-on when needed

## Configuration Reference

| Setting | Mac Mini | MacBook Pro | Cyberbeast |
|---------|----------|-------------|------------|
| Profile | default | macbook-pro | cyberbeast |
| Provider | openrouter | ollama | lmstudio |
| Model | deepseek-v4-pro | gemma3:27b | gemma-3-27b-it |
| Endpoint | api.openrouter.ai | localhost:11434 | localhost:1234 |
| Tailscale | nicks-mac-mini | macbook-pro-5 | cyberbeast |
