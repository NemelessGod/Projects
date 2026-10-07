#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ ! -f "$ANDROID_HOME/system-images/android-35/default/x86_64/package.xml" ]]; then
  "$ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
    emulator 'system-images;android-35;default;x86_64'
fi
if [[ ! -f "$ANDROID_AVD_HOME/spin-test.ini" ]]; then
  mkdir -p "$ANDROID_AVD_HOME"
  echo no | "$ANDROID_HOME/cmdline-tools/19.0/bin/avdmanager" create avd \
    -n spin-test -k 'system-images;android-35;default;x86_64' --device pixel_5
  # Small portrait display reduces software rendering cost; real-device QA remains necessary.
  python - <<'PY'
import os, re
from pathlib import Path
p = Path(os.environ['ANDROID_AVD_HOME']) / 'spin-test.avd/config.ini'
s = p.read_text()
for key, value in [('hw.lcd.width','540'),('hw.lcd.height','960'),('hw.lcd.density','220')]:
    s = re.sub(rf'^{re.escape(key)}\s*=.*$', f'{key}={value}', s, flags=re.M)
p.write_text(s)
PY
fi
accel=off
if [[ -r /dev/kvm && -w /dev/kvm ]]; then accel=on; fi
# ANGLE supports the uniform limits Godot needs; old swiftshader GLES mode does not.
# Foreground: leave this in a managed process session. May need sandbox home-cache access.
exec "$ANDROID_HOME/emulator/emulator" -avd spin-test -no-window -no-audio \
  -no-boot-anim -gpu swangle -accel "$accel" -memory 2048 -cores 2 -no-snapshot \
  -camera-back none -camera-front none -no-metrics
