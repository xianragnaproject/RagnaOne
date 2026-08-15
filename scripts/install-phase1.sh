#!/usr/bin/env bash
# Install Phase 1 macros + config into a local OpenKore tree.
# Also appends Phase 2 when present (same as install-phase2.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/scripts/install-phase2.sh"
