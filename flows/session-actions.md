# Session Lifecycle & Action Flow

How a session request travels through the wired-together stack: fingerprint generation, stealth injection, proxy acquisition, isolation, and live CDP actions.

## Session Creation

```mermaid
sequenceDiagram
    participant C as Client (CLI/SDK/MCP)
    participant API as API Server (cmd/server)
    participant SS as session.Service
    participant FP as fingerprint.Store/Generator
    participant PX as proxy.Pool
    participant BM as browser.Manager
    participant ISO as isolation (netns + cgroup)
    participant CR as Chromium
    participant MON as cdp.SessionMonitor

    C->>API: POST /v1/sessions {stealth, proxy, profile_id, record}
    API->>API: validate + load profile prefs (persistence.ProfileManager)
    API->>SS: Create(params)
    SS->>FP: load by fingerprint_id or Generate(locale, timezone)
    SS->>PX: Get(type, country, sticky) — if proxy requested
    SS->>BM: Launch(SessionConfig + stealth flags + fingerprint)
    BM->>ISO: allocate subnet, create namespace, cgroup
    BM->>CR: exec chromium (flags, TZ env, proxy)
    BM-->>SS: Session{id, cdp_endpoint}
    SS->>MON: Start — inject stealth scripts on every page,<br/>stream events to recorder (if record=true)
    Note over SS,MON: monitor failure at stealth ≥ standard<br/>destroys the session (fail closed)
    SS-->>API: session
    API-->>C: 201 {data: {id, cdp_endpoint, token}}
```

## Page Actions

```mermaid
sequenceDiagram
    participant C as Client
    participant API as API Server
    participant CMD as cdp.Commander
    participant CR as Chromium (CDP)

    C->>API: POST /v1/sessions/{id}/click {selector}
    API->>API: runtime.CDP(id) → resolve endpoint (404 if gone)
    API->>CMD: Click(endpoint, selector)
    CMD->>CR: GET /json/list → pick page target
    CMD->>CR: dial page WebSocket
    CMD->>CR: Runtime.evaluate (querySelector + click)
    CR-->>CMD: result | exceptionDetails
    CMD-->>API: ok | error
    API-->>C: 200 {data} | 502 {error}
```

Same pipeline serves `/navigate` (Page.navigate + lifecycle event wait), `/execute`, `/type`, `/extract`, `/wait`, `/scroll`, `/screenshot` (Page.captureScreenshot), and `/cookies` (Network.getAllCookies / setCookies).

## Session Destroy

```mermaid
flowchart LR
    A[DELETE /v1/sessions/:id] --> B[stop SessionMonitor]
    B --> C[stop recording / flush HAR]
    C --> D[release proxy lease]
    D --> E[runtime.Destroy]
    E --> F[kill Chromium process]
    F --> G[teardown netns + cgroup + subnet]
```
