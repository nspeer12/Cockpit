# Statement of Work — NEO Mobile Client

**Project:** Cockpit / NEO Mobile Client  
**Sponsor:** Nick Speer  
**Product owner:** Nick Speer  
**Prepared:** 2026-07-15  
**Status:** Proposed scope — ready for discovery and implementation

## 1. Executive summary

Build a private, mobile-first home for **NEO — Networked Executive Orchestrator**. The mobile client becomes Nick’s preferred day-to-day way to converse with Hermes/NEO, review what it is doing, receive important updates, and approve carefully scoped actions.

Telegram remains connected as a durable, low-friction **background and fallback channel**. It is not removed or silently disabled. The mobile app is the primary conversational experience; Telegram remains the route for urgent delivery, quick replies, and recovery if the app, phone connectivity, or push delivery is unavailable.

The result is not a remote terminal and not a mobile copy of the macOS Cockpit. It is a focused personal NEO client with a secure gateway to Hermes.

## 2. Current state and constraints

### Existing assets

- Cockpit has a native macOS command center and a Tailnet-private installable PWA.
- The PWA currently provides live **read-only** system status through `/api/stats`, `/api/events`, and `/health`.
- Hermes Gateway is running under launchd and Telegram is configured as its home channel.
- Hermes provides persistent memory, session storage, skills, MCP integrations, cron jobs, multi-platform messaging, voice support, and tool governance.
- The existing mobile PWA and Cockpit docs correctly prohibit remote execution until an authenticated, auditable authorization layer exists.

### Product constraints

- Do not make Cockpit, Hermes, or the mobile gateway public on the internet.
- Do not place provider credentials, Hermes configuration secrets, shell access, or unrestricted MCP/tool schemas on the phone.
- Preserve Hermes prompt-cache and session-role invariants; do not make the client mutate an existing conversation’s historical context.
- The Mac currently lacks a full iOS/Xcode build environment. The first usable client must therefore be web/PWA-compatible; native iOS can follow once the API and interaction model are proven.

## 3. Product vision

> **NEO Mobile is the private control and conversation surface for a personal agent that can observe, reason, communicate, and perform approved work—while making its state, uncertainty, and actions legible.**

### Core interaction principles

1. **Conversation first.** Opening the app lands in a fast, streaming NEO conversation—not a dashboard.
2. **State is visible.** The user can see whether NEO is thinking, waiting for input, executing, blocked, or has completed work.
3. **Honest agency.** NEO distinguishes “received,” “scheduled,” “running,” “needs approval,” “failed,” and “verified complete.”
4. **Private by default.** Tailnet transport plus separate device identity and scoped authorization; no public reverse proxy.
5. **Telegram is resilient fallback.** Notifications can carry the user back to the app, but Telegram continues to receive critical alerts and can always resume work.
6. **Mobile is intentional.** Compact, voice-friendly, responsive, and designed for one-handed use—not a shrunk macOS dashboard.

## 4. Recommended product shape

### Phase A — Gateway discovery plus native iOS foundation

Run the secure gateway discovery spike first, then begin a native SwiftUI iOS client immediately against the proven contracts. The existing Tailnet PWA remains a lightweight installable fallback and a fast contract-validation surface, but it is not the primary end-state client.

The first native vertical slice will include authenticated NEO chat, server-streamed responses, conversation history, agent run status, handoff to Telegram, and a safe approval inbox.

### Phase B — PWA companion and contract-parity route

Keep the installable PWA aligned with the same gateway contracts as a private cross-platform fallback, rapid iteration surface, and recovery client. Native iOS owns the primary mobile experience; the PWA remains useful when native installation, push, or device availability is constrained.

Android is deliberately deferred until the product/API is stable. The PWA remains the cross-platform route.

### Why this order

A native app without a stable agent gateway would be expensive UI work around an unsafe or changing backend. The gateway discovery spike establishes the contracts first; native iOS begins immediately afterward as the primary client. The PWA then stays aligned as a private fallback and contract-validation surface rather than a parallel backend.

## 5. Scope and feature sets

### 5.1 P0 — Secure mobile foundation

**Outcome:** The phone can securely identify itself and maintain a private, authenticated session with NEO.

| Capability | Scope |
|---|---|
| Tailnet-only transport | Tailscale Serve/private DNS remains the only transport exposure. |
| Device pairing | New device is paired through a short-lived, single-use QR/deep-link or code approved from Cockpit/Telegram. |
| Mobile auth session | Short-lived access token plus rotating refresh token, bound to an individual device record. |
| Authorization | Server-enforced scopes: `chat`, `status:read`, `runs:read`, `approvals:respond`, and later narrowly named action scopes. |
| Audit trail | Append-only records for pairing, login, message submission, approvals, action dispatch, and failures. |
| Revocation | Revoke one phone/device without changing Hermes or provider credentials. |
| Health | Gateway and client surface clear offline, expired-session, and degraded-service states. |

**Not in P0:** public login, shared household accounts, arbitrary multi-user roles, or direct browser-to-Hermes credentials.

### 5.2 P1 — NEO conversation as the primary experience

**Outcome:** Nick can use the installed mobile app as the default place to talk to NEO.

| Capability | Scope |
|---|---|
| Streaming chat | Message send, token streaming, cancellation, retry, rich markdown, code blocks, images/files when Hermes returns them. |
| Conversation list | Recent mobile conversations, names, timestamps, unread/completion state, and explicit new conversation. |
| Run timeline | Per-message lifecycle: received → thinking → tool/approval wait → executing → result. Tool output is summarized; dangerous raw logs remain server-side. |
| NEO identity | NEO icon, voice/personality, calm status language, and the same `NEOIdentity` behavior as Cockpit. |
| Voice | Push-to-talk speech-to-text and spoken responses where the browser/device supports it; native-quality voice is a Phase B target. |
| Handoffs | “Continue in Telegram” and “Open in NEO Mobile” generate a compact handoff summary and link—not a fragile attempt to merge two live transcripts. |
| Search | Search the user’s mobile conversation history; session search requests are executed server-side under the mobile scope. |
| Offline behavior | Cache shell and most recent non-sensitive metadata; never present cached metrics, agent status, or a queued action as live/complete. |

### 5.3 P2 — Notifications and background continuity

**Outcome:** Important work reaches Nick even when the app is not open.

| Capability | Scope |
|---|---|
| Notification policy | High-priority: approval required, task failed, task verified complete, security/device event. Lower-priority summaries are batched. |
| Telegram fallback | Critical notifications deliver to both the mobile notification route and Telegram until measured reliability permits a policy change. |
| Deep links | A notification opens the exact conversation, approval, scheduled brief, or run timeline. |
| Native push | APNs device-token registration and server notification delivery in the native iOS phase. |
| PWA push | Evaluate installed iOS PWA web push as a convenience path; it is not the sole critical-alert guarantee. |
| Quiet hours | Per-device quiet hours and escalation policy; never suppress a security/device-revocation alert. |

### 5.4 P3 — Safe remote operations

**Outcome:** NEO can request and perform bounded, auditable operations from the phone.

Initial allowed operations:

- acknowledge or dismiss an alert
- approve/deny a pending Hermes action
- trigger an already-defined cron job
- refresh a project/network/system scan
- wake a known Tailnet machine
- start a named, pre-scoped agent task
- create/reply to a Hermes task or schedule a reminder

The app must **not** expose arbitrary shell commands, arbitrary tool invocation, unfiltered MCP access, provider/model credential management, or direct camera/microphone feeds.

Every action requires:

1. server-side scope check
2. server-side action allowlist and schema validation
3. idempotency key
4. explicit confirmation for any consequential action
5. audit record with result state
6. in-app result plus Telegram fallback for failures/critical completion

### 5.5 P4 — Personal operating system integrations

After the core conversation/action loop is trusted, integrate Hermes capabilities as mobile-native workflows:

| Integration | Mobile experience | Boundary |
|---|---|---|
| Hermes memory | “What do you remember?” and preference correction UI | Memory changes are reviewed, attributed, and server-side. |
| Skills | Show loaded/relevant skills and explain why they are used | Do not expose arbitrary skill-file editing initially. |
| Cron | View, pause/resume, and approve named scheduled jobs | New/edited jobs require confirmation and scope checks. |
| MCP tools | Display which integration acted and its result | Gateway chooses/filters tools; the app never receives global tool credentials. |
| Cockpit status | Live system/model/network cards and incident state | Same read-only status contract as today, expanded only behind policy. |
| Projects/GitHub | Project health, PR/issue summaries, verified action links | GitHub writes remain server-side and approval-gated. |
| Calendar/reminders | NEO-created reminders and briefings | Explicit scoped integration and audit record. |
| Voice / Shortcuts | “Ask NEO” intent, quick capture, Siri Shortcut entry point | Native iOS phase; confirmation rules remain server-side. |
| Ambient awareness | High-level, privacy-preserving events only | No default remote camera/mic streaming; each new sensor surface needs separate consent. |

## 6. Hermes integration architecture

```text
Mobile PWA / Native iOS
        │
        │ Tailnet HTTPS + device-bound mobile session
        ▼
Cockpit Mobile Gateway (new server-side BFF)
  ├── device pairing, tokens, scopes, rate limits, audit log
  ├── WebSocket/SSE response stream and notification router
  ├── conversation/run projection optimized for mobile
  ├── action-policy engine and approval queue
  └── Cockpit status adapter
        │
        ▼
Hermes Gateway / API-server integration
  ├── session lifecycle and message routing
  ├── persistent memory / skills / cron / MCP
  ├── tool-use and approval semantics
  └── Telegram platform adapter (fallback + parallel channel)
```

### Required integration decisions

- **Use Hermes’s gateway/API-server integration as the agent boundary**, after a discovery spike validates its authentication, session ownership, streaming, and cancellation semantics on the installed Hermes version. Do not bind the mobile client to the internal TUI WebSocket or scrape terminal output.
- **Create a purpose-built Cockpit Mobile Gateway/BFF.** It owns mobile identities, response projections, policy, deep links, and notification routing. It must not become a second agent runtime.
- **Treat Tailscale as transport privacy, not sufficient app authorization.** A Tailnet-connected device still needs an explicit mobile identity, revocation, and scoped access.
- **Preserve conversation isolation.** Mobile and Telegram may share durable Hermes memory, but each active channel conversation keeps its own session context. Handoffs use summarized, user-visible context rather than transcript mutation or simultaneous cross-channel writes.
- **Keep the model/tool loop server-side.** The mobile client submits intent and renders trusted run events; provider keys and tool schemas never leave the Mac Mini.

## 7. Deliverables

1. **Mobile gateway design and threat model** — endpoint contracts, token model, device lifecycle, action policy, data retention, and audit schema.
2. **Hermes API-server discovery spike** — verified compatibility report against the installed Hermes version, including streaming, session, cancellation, and approval behavior.
3. **NEO Mobile PWA v1** — installed app with pairing, chat, streaming, history, run timeline, Cockpit glance cards, and Telegram handoff.
4. **Notification policy and fallback implementation** — critical event routing to Telegram plus mobile route, deep links, quiet-hours behavior, and delivery audit.
5. **Safe approval/action inbox** — action cards, confirmation, idempotency, audit log, and initial allowlisted operations.
6. **Native iOS technical design** — SwiftUI application architecture, API client, APNs, Face ID, voice, widget/Shortcut roadmap; implementation begins only once a full Xcode/iOS CI path exists.
7. **Operational documentation** — deployment, device recovery/revocation, Tailnet configuration, monitoring, incident rollback, and user guide.

## 8. Work plan and milestones

### Milestone 0 — Discovery and contracts

- Inspect the installed Hermes API-server/gateway surfaces and validate a real mobile-safe message lifecycle.
- Define the mobile session model, device pairing, token rotation, audit events, and data-retention policy.
- Create API contract tests before UI work.
- Decide whether the initial PWA uses SSE or WebSocket based on tested Hermes streaming/cancellation behavior.

**Exit criteria:** a local/Tailnet test client can pair, create a mobile-owned session, send a message, stream a verified response, cancel safely, and audit the lifecycle.

### Milestone 1 — Native iOS conversational vertical slice

- Install/enable Xcode and an iOS build/test path before beginning the client.
- Build pairing/login and protected native SwiftUI shell.
- Build mobile conversation, streaming renderer, run status, retry/cancel, conversation list, and app-install flow.
- Add real Cockpit status card and explicit offline/degraded UX.
- Add Telegram handoff and fallback deep links.

**Exit criteria:** Nick can use the native iOS app privately as a daily chat client, then continue the same work through an explicit handoff in Telegram if needed.

### Milestone 2 — Notification and continuity loop

- Implement notification event classification, delivery audit, and Telegram redundancy.
- Add notification deep links, quiet hours, and approval-expiry behavior.
- Validate behavior across foreground, background, disconnected Tailnet, expired token, and server restart conditions.

**Exit criteria:** critical work never relies on a single delivery path; app and Telegram tell a coherent, non-duplicative story.

### Milestone 3 — Scoped action and approval loop

- Implement policy engine, confirmation cards, idempotency, result receipts, and initial action allowlist.
- Add remote operations one at a time with end-to-end tests and failure recovery.

**Exit criteria:** an allowed phone-originated action is authenticated, reviewed if needed, executed once, logged, and verifiably reported.

### Milestone 4 — Native iOS decision and implementation

- Install/enable Xcode and an iOS build/test path.
- Reuse stable gateway contracts for SwiftUI iOS app.
- Add APNs, Face ID, native voice, widgets, and Shortcuts.

**Exit criteria:** native app passes device/simulator tests and equals or exceeds the PWA conversation flow without weakening privacy or action controls.

## 9. Acceptance criteria

### Conversation

- A paired mobile device can create a distinct mobile Hermes session and receive token-streamed NEO replies.
- The client renders explicit state for queued, running, approval-required, failed, cancelled, and verified-complete work.
- A failed/restarted stream reconnects safely without sending the user’s message twice.
- Telegram fallback can be invoked deliberately with a clear handoff summary.

### Security

- All mobile API routes require device-bound authentication and server-side authorization scopes.
- Revoking a device invalidates active and refresh tokens promptly.
- The phone never receives provider keys, raw Hermes config, arbitrary command execution, or unfiltered MCP credentials.
- Every mobile-originated action and approval has an audit record and idempotency behavior.
- No service is publicly exposed beyond the Tailnet.

### Reliability

- Gateway restart, Tailnet loss, expired session, and offline state have clear recovery UX.
- Critical completion/failure/approval events have Telegram fallback until native push reliability is measured.
- Status data displays capture time and does not mislabel cached data as live.

### Quality

- Mobile API contracts, auth, session lifecycle, stream recovery, action policy, and notification routing have automated tests.
- PWA runs through install and responsive-device checks.
- Native work begins only with an executable iOS build/test path.

## 10. Exclusions for this SOW

- Public SaaS/multi-tenant product launch.
- App Store submission, billing, subscriptions, or consumer account management.
- Unrestricted remote shell, terminal, file-system, or arbitrary MCP-tool access.
- Always-on remote audio/video surveillance.
- Replacing or disabling Telegram.
- Android-native implementation in the first release.

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Hermes API-server behavior differs from current documentation/version | Make the first milestone an executable integration spike; freeze a tested adapter contract before UI implementation. |
| Mobile background delivery is inconsistent | Keep Telegram critical fallback; add APNs only in native phase; record delivery outcomes. |
| Phone UI becomes an unsafe remote-control panel | Server-owned scopes, allowlists, confirmation, idempotency, audit, and incremental actions only. |
| Cross-channel history becomes confusing | Separate live sessions; share durable memory; provide explicit summaries/handoffs instead of silent transcript merging. |
| Tailscale-only UX is inconvenient | Preserve Telegram access; make pairing/deep links simple; evaluate broader access only after an explicit security decision. |
| Native iOS work stalls without Xcode/CI | Deliver the PWA first and treat Xcode setup as a milestone prerequisite. |

## 12. Decisions requested

The recommended defaults are shown in **bold**.

1. **Decided: begin native iOS immediately after the gateway-discovery milestone.** The PWA remains a private fallback and API-contract parity surface.
2. Should the app be **single-user, Nick-only**, or should family/team device support be part of the first design?
3. For mobile lock, is **Face ID/passcode required at launch**, or only required before approvals/actions?
4. Should Telegram receive **only critical fallback events**, or remain mirrored for all NEO responses during the first release?
5. Which first remote actions have the highest value: approval/deny, task/cron control, wake machine, project/GitHub actions, reminders, or smart-home control?

## 13. Hermes documentation consulted

This SOW is grounded in the current Hermes documentation and installed runtime:

- [Messaging Gateway](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/) — multi-platform gateway, Telegram capabilities, voice/files/streaming support.
- [Persistent Memory](https://hermes-agent.nousresearch.com/docs/user-guide/features/memory) — bounded cross-session memory and user-profile behavior.
- [MCP](https://hermes-agent.nousresearch.com/docs/user-guide/features/mcp) — external integrations, tool discovery, and per-server filtering.
- [Scheduled Tasks](https://hermes-agent.nousresearch.com/docs/user-guide/features/cron) — durable jobs, delivery targets, model pinning, and no-agent mode.

Runtime discovery on 2026-07-15 confirmed Hermes Agent `v0.18.2`, a running launchd-supervised gateway, configured Telegram, and enabled core web/browser/file/terminal/vision/skills/memory/delegation/cron/computer-use toolsets. The gateway launchd definition is currently reported as stale relative to the installed Hermes version; remediation is a Milestone 0 operational prerequisite.
