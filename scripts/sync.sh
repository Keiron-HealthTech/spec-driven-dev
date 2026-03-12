#!/usr/bin/env bash
# Wrapper: delegates to the canonical sync script in skills/skill-sync/assets/
# This file exists at plugin root for easy access via ${CLAUDE_PLUGIN_ROOT}/scripts/sync.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$PLUGIN_ROOT}"
exec bash "${PLUGIN_ROOT}/skills/skill-sync/assets/sync.sh" "$@"
