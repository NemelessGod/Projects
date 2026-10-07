#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
cd "$SPIN_ROOT"
mkdir -p build
# Debug only. Production signing / HTTPS configuration require a release task.
godot --headless --path client --export-debug 'Android Debug' "$SPIN_ROOT/build/spin-kingdom-debug.apk"
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify "$SPIN_ROOT/build/spin-kingdom-debug.apk"
