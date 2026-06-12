# CLI Browser Login Flow

How `meshbrow auth login` authenticates via the browser (device authorization flow), with `--key` as the manual fallback.

## Browser Flow (default)

```mermaid
sequenceDiagram
    participant CLI as meshbrow CLI
    participant API as API Server (cmd/server)
    participant CAS as userauth.CLIAuthService
    participant B as Browser
    participant WEB as Dashboard (apps/web)
    participant KS as database.APIKeyStore

    CLI->>API: POST /v1/cli/auth/start
    API->>CAS: Start()
    CAS-->>API: device_code, user_code (XXXX-XXXX),<br/>verification_url, expires_in (10m), interval (2s)
    API-->>CLI: 200 start response
    CLI->>B: open verification_url<br/>(meshbrow.dev/cli/authorize?code=XXXX-XXXX)
    CLI->>CLI: print user_code + URL, start polling

    loop every `interval` seconds until deadline
        CLI->>API: POST /v1/cli/auth/poll {device_code}
        API->>CAS: Poll(device_code)
        CAS-->>API: {status: pending}
        API-->>CLI: 200 {status: pending}
    end

    B->>WEB: GET /cli/authorize?code=XXXX-XXXX
    alt not signed in
        WEB->>B: redirect /login?callbackUrl=/cli/authorize?code=...
        B->>WEB: sign in, redirected back
    end
    B->>WEB: confirm code, click Authorize
    WEB->>API: POST /v1/cli/auth/approve {user_code}<br/>(Bearer session token)
    API->>CAS: Approve(userID, user_code)
    CAS->>KS: GenerateKey(userID, "CLI")
    KS-->>CAS: mb_live_... (stored hashed)
    CAS-->>API: approved
    API-->>WEB: 200 {status: approved}

    CLI->>API: POST /v1/cli/auth/poll {device_code}
    API->>CAS: Poll(device_code) — returns key once, deletes request
    API-->>CLI: 200 {status: approved, api_key}
    CLI->>API: GET /v1/auth/me (Bearer api_key)
    API-->>CLI: 200 {email}
    CLI->>CLI: save api_key to ~/.meshbrow.yaml
```

## Manual Flow

```mermaid
sequenceDiagram
    participant CLI as meshbrow CLI
    participant API as API Server

    CLI->>CLI: meshbrow auth login --key mb_live_...
    CLI->>API: GET /v1/auth/me (Bearer key)
    API-->>CLI: 200 {email} | 401 invalid
    CLI->>CLI: save key to ~/.meshbrow.yaml
```

## Security Properties

- **Device code** (64 hex chars) is the polling secret — only ever held by the CLI; never shown in the browser or URL.
- **User code** (`XXXX-XXXX`, unambiguous alphabet) is what travels through the browser; it cannot be used to retrieve the key, only to approve.
- Requests expire after **10 minutes** and approval is **single-use**; the API key is returned to the poller **exactly once**, then the request is deleted.
- Approval requires an authenticated dashboard session (`userauth.AuthMiddleware`).
- Pending requests are capped (1000) to bound memory; expired entries are swept on each start.
- The web login redirect only honors same-origin relative `callbackUrl` values (no open redirect).

## Error Scenarios

| Scenario | Behavior |
|----------|----------|
| User never approves | Poll returns `expired` after TTL; CLI exits with retry hint |
| Wrong code entered on web | `400 invalid or expired code` |
| Code approved twice | Second approve fails (single-use) |
| Key generation fails (DB down) | Request stays `pending`, user can retry approval |
| Server restart mid-flow | In-memory request lost; poll returns `expired`, CLI prompts re-run |
| Browser cannot be opened | CLI prints the URL for manual opening and keeps polling |
