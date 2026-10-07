#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
curl -fsS http://127.0.0.1:8000/health >/dev/null
# Fresh isolated client cache per run; do not delete the developer's guest session.
smoke_dir="$(mktemp -d "$SPIN_TOOLING_DIR/client-smoke.XXXXXX")"
export XDG_DATA_HOME="$smoke_dir"
godot --headless --path "$SPIN_ROOT/client" --script res://tests/transport.gd
godot --headless --path "$SPIN_ROOT/client" --script res://tests/smoke.gd
godot --headless --path "$SPIN_ROOT/client" --script res://tests/smoke.gd -- --restore
