# Meshbrow Docs (docs)

You are working in `meshbrow-dev/docs` — a Mintlify documentation site. This repo is not yet listed in `meshbrow-dev/workspace`'s own CLAUDE.md app table; it is assumed to live at `apps/docs-site/` there — verify and correct this hook's path-prefix assumption if the team places it elsewhere (e.g. if it replaces `apps/docs/`).

**Note:** `meshbrow-dev/meshbrow-docs` is a separate, near-duplicate Mintlify site with slightly older content. Confirm with the team which of the two is authoritative before treating this as the sole docs source.

See `.claude/skills/documentation/SKILL.md` for writing standards and diagram conventions.

## Shared Claude Code Config

`.claude/skills/` and `.claude/agents/` in this repo are **synced automatically** from `meshbrow-dev/workspace` by the `SessionStart` hook (`.claude/hooks/session-start.sh`) whenever this repo is opened directly (e.g. Claude Code on the web) rather than checked out inside the workspace repo. Don't hand-edit files under `.claude/skills/` or `.claude/agents/` here — edit them in `meshbrow-dev/workspace` instead, they'll be overwritten on the next session start.

## Critical Rules (ALL code changes)

### NEVER
- Return raw error messages to API clients — use structured error responses
- Log sensitive fields: apiKey, proxyCredentials, fingerprint configs
- Call Docker/Chromium directly — always go through the `Runtime` interface
- Skip input validation on API handlers
- Use `any` type in Go — always define concrete types
- Commit secrets, .env files, or proxy provider credentials
- Ship without tests for the changed code
- Ship without updating relevant docs
- Expose fingerprint internals in API responses (detection vectors)
- Store proxy passwords unencrypted
- Allow cross-session network traffic (namespace leak = critical bug)
- Ship implementation without running tests and confirming they pass
- Consider a feature "done" with less than 80% test coverage on changed code

### ALWAYS
- Use structured logging (slog in Go, structured JSON)
- Validate at system boundaries (API handlers, webhook receivers)
- Use context.Context for cancellation and deadlines
- Write tests alongside implementation (same commit or immediately after)
- Run tests after implementation and confirm they pass before marking complete
- Target ≥ 80% coverage on all changed/new code
- Use conventional commits: feat:, fix:, docs:, refactor:, test:, chore:
- Add OpenTelemetry spans for cross-service calls
- Use database transactions for multi-row operations
- Clean up network namespaces on session destroy
- Rotate proxy credentials when sessions end
- Verify anti-detection on every Chromium update

### Implementation Workflow (MANDATORY for every feature)

```
1. Implement the feature code
2. Write tests (unit tests minimum, integration tests where applicable)
3. Run tests locally — ALL must pass
4. Verify coverage ≥ 80% on changed files
5. Fix any failing tests before proceeding
6. Commit implementation + tests together
```

The final todo item in any task list MUST be "Run tests and verify passing".
