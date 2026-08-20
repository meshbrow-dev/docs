#!/bin/bash
set -euo pipefail

# Only self-configure in Claude Code on the web / remote sessions. Locally this
# repo is expected to be checked out inside meshbrow-dev/workspace at apps/docs-site/,
# which already provides .claude/skills and .claude/agents at the workspace root.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
WORKSPACE_CLONE="$(mktemp -d)"
trap 'rm -rf "$WORKSPACE_CLONE"' EXIT

git clone --depth 1 https://github.com/meshbrow-dev/workspace "$WORKSPACE_CLONE"

rm -rf "$REPO_ROOT/.claude/skills" "$REPO_ROOT/.claude/agents"
cp -r "$WORKSPACE_CLONE/.claude/skills" "$REPO_ROOT/.claude/skills"
cp -r "$WORKSPACE_CLONE/.claude/agents" "$REPO_ROOT/.claude/agents"

# Shared skills/agents are written with paths relative to their location inside
# the meshbrow-dev/workspace monorepo layout (this repo lives at apps/docs-site/
# there). Strip that prefix so paths resolve correctly from this repo's own root.
find "$REPO_ROOT/.claude/skills" "$REPO_ROOT/.claude/agents" -type f -name '*.md' -print0 \
  | xargs -0 sed -i "s#apps/docs-site/##g"

# Mintlify docs site — no local dependency install needed to edit .mdx content.
echo "No install step (Mintlify docs site)."
