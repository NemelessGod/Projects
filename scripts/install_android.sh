#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$SPIN_TOOLING_DIR" "$ANDROID_HOME/cmdline-tools"
TOOLS="$ANDROID_HOME/cmdline-tools/19.0"
if [[ ! -x "$TOOLS/bin/sdkmanager" ]]; then
  archive="$SPIN_TOOLING_DIR/android-tools-19.zip"
  curl --fail --location --silent --show-error \
    https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o "$archive"
  echo "5fdcc763663eefb86a5b8879697aa6088b041e70  $archive" | sha1sum -c -
  extract_dir="$(mktemp -d "$SPIN_TOOLING_DIR/cli19.XXXXXX")"
  unzip -q "$archive" -d "$extract_dir"
  mv "$extract_dir/cmdline-tools" "$TOOLS"
  rmdir "$extract_dir"
fi
if [[ ! -x "$ANDROID_HOME/build-tools/36.0.0/apksigner" ]]; then
  # Preserve sdkmanager's exit code; yes may receive expected SIGPIPE.
  set +o pipefail
  yes | "$TOOLS/bin/sdkmanager" --sdk_root="$ANDROID_HOME" --licenses > "$SPIN_TOOLING_DIR/licenses.log"
  sdk_status=${PIPESTATUS[1]}
  set -o pipefail
  (( sdk_status == 0 ))
  "$TOOLS/bin/sdkmanager" --sdk_root="$ANDROID_HOME" 'platform-tools' 'build-tools;36.0.0' 'platforms;android-36'
fi
TEMPLATES="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
if [[ ! -f "$TEMPLATES/android_debug.apk" ]]; then
  archive="$SPIN_TOOLING_DIR/Godot_v4.6.3-stable_export_templates.tpz"
  curl --fail --location --silent --show-error \
    https://github.com/godotengine/godot/releases/download/4.6.3-stable/SHA512-SUMS.txt \
    -o "$SPIN_TOOLING_DIR/godot-SHA512-SUMS.txt"
  curl --fail --location --silent --show-error \
    https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz \
    -o "$archive"
  (cd "$SPIN_TOOLING_DIR" && rg 'Godot_v4.6.3-stable_export_templates.tpz$' godot-SHA512-SUMS.txt | sha512sum -c -)
  extract_dir="$(mktemp -d "$SPIN_TOOLING_DIR/templates.XXXXXX")"
  unzip -q "$archive" 'templates/android_debug.apk' 'templates/android_release.apk' \
    'templates/linux_debug.x86_64' 'templates/linux_release.x86_64' 'templates/version.txt' -d "$extract_dir"
  mkdir -p "$TEMPLATES"
  cp "$extract_dir/templates/"* "$TEMPLATES/"
  rm -r "$extract_dir"
fi
# Editor settings are local, never committed. Discover Java without resetting HOME.
export SPIN_JAVA_ROOT="${SPIN_JAVA_ROOT:-$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java.home = //p')}"
godot --headless --editor --path "$SPIN_ROOT/client" --import --quit
python - <<'PY'
import os
import re
from pathlib import Path
p = Path(os.environ['XDG_CONFIG_HOME']) / 'godot/editor_settings-4.6.tres'
s = p.read_text()
for key, value in [('export/android/java_sdk_path', os.environ['SPIN_JAVA_ROOT']),
                   ('export/android/android_sdk_path', os.environ['ANDROID_HOME'])]:
    s = re.sub(rf'^{re.escape(key)} = .*$', f'{key} = "{value}"', s, flags=re.M)
p.write_text(s)
PY
printf 'Android SDK, verified templates and local export settings prepared.\n'
