#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SPIN_ROOT"
command -v python3 >/dev/null
command -v docker >/dev/null
command -v godot >/dev/null
godot --version | rg '^4\.6\.3\.' >/dev/null
if [[ ! -x .venv/bin/python ]]; then python3 -m venv .venv; fi
.venv/bin/pip install --disable-pip-version-check -r backend/requirements.lock
printf 'Python dependencies and Godot version checked. Run scripts/start.sh.\n'
