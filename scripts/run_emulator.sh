#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
api="${SPIN_ANDROID_API:-29}"
case "$api" in 29|35) ;; *) echo "Use SPIN_ANDROID_API=29 or 35" >&2; exit 1 ;; esac
export SPIN_AVD_NAME="spin-test-api$api"
image="system-images;android-$api;default;x86_64"
if [[ ! -f "$ANDROID_HOME/system-images/android-$api/default/x86_64/package.xml" ]]; then
  "$ANDROID_HOME/cmdline-tools/19.0/bin/sdkmanager" --sdk_root="$ANDROID_HOME" \
    emulator "$image"
fi
if [[ ! -f "$ANDROID_AVD_HOME/$SPIN_AVD_NAME.ini" ]]; then
  mkdir -p "$ANDROID_AVD_HOME"
  echo no | "$ANDROID_HOME/cmdline-tools/19.0/bin/avdmanager" create avd \
    -n "$SPIN_AVD_NAME" -k "$image" --device pixel_5
  # Small portrait display reduces software rendering cost; real-device QA remains necessary.
  python - <<'PY'
import os, re
from pathlib import Path
p = Path(os.environ['ANDROID_AVD_HOME']) / (os.environ['SPIN_AVD_NAME'] + '.avd') / 'config.ini'
s = p.read_text()
for key, value in [('hw.lcd.width','540'),('hw.lcd.height','960'),('hw.lcd.density','220')]:
    s = re.sub(rf'^{re.escape(key)}\s*=.*$', f'{key}={value}', s, flags=re.M)
p.write_text(s)
PY
fi
# An interrupted cloud process can leave a PID lock pointing to an exited/zombie VM.
# Remove only proven stale runtime locks, preserving the guest account and disk images.
python - <<'PYLOCK'
import os
from pathlib import Path
avd = Path(os.environ['ANDROID_AVD_HOME']) / (os.environ['SPIN_AVD_NAME'] + '.avd')
lock = avd / 'hardware-qemu.ini.lock'
if lock.exists():
    pid = int(lock.read_text().rstrip(chr(0)).strip())
    stat = Path(f'/proc/{pid}/stat')
    if not stat.exists() or stat.read_text().rsplit(')', 1)[1].split()[0] == 'Z':
        lock.unlink()
        (avd / 'multiinstance.lock').unlink(missing_ok=True)
    else:
        raise SystemExit('This AVD has a running process. Reuse it; do not remove its lock.')
PYLOCK
accel=off
if [[ -r /dev/kvm && -w /dev/kvm ]]; then accel=on; fi
# ANGLE supports the uniform limits Godot needs; old swiftshader GLES mode does not.
# Foreground: leave this in a managed process session. May need sandbox home-cache access.
exec "$ANDROID_HOME/emulator/emulator" -avd "$SPIN_AVD_NAME" -no-window -no-audio \
  -no-boot-anim -gpu swangle -accel "$accel" -memory "${SPIN_EMULATOR_MEMORY:-4096}" -cores "${SPIN_EMULATOR_CORES:-4}" -no-snapshot \
  -camera-back none -camera-front none -no-metrics
