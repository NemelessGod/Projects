# Проверка первого вертикального среза

2026-10-07, Linux cloud, PostgreSQL 17, Godot 4.6.3, Android 10/API 29 x86_64 emulator (ANGLE/swangle, без KVM).

- 29 pytest unit/integration tests: PASS, настоящая изолированная PostgreSQL `_test` БД.
- Ruff/GDScript format/lint: PASS.
- Godot HTTP E2E: guest → spin → upgrade → потерянный ответ → replay → отдельный процесс restore: PASS.
- Unreachable-server transport: PASS, JSON parse errors отсутствуют.
- Android debug APK arm64/x86_64: export/signature PASS.
- Android UI: guest 300 coins/20 spins → spin (+36 coins/+1 spin, XP 2) → beacon upgrade (-120 coins, level 1, XP 17): PASS. Server state, committed operations and ledger verified; no direct API command substituted for these taps.
- Android restart: PASS, тот же гостевой ID, 216 coins, XP 17, beacon level 1; показан синхронизированный игровой экран. В обновлённой APK после reinstall -r данные также восстановлены, энергия 21 после законной регенерации.
- Linux debug: built/launched PASS.
- Windows x86_64 EXE: cross-export PASS; PowerShell script syntax parsed PASS. Actual Windows 10 runtime and Docker Desktop remain untested here.

Android evidence in ignored build/: android-before.json, android-spin.json, android-after.json, android-ledger.json, android-api29-relaunch.png, android-spin.png, android-upgrade.png. Evidence contains no authentication tokens. Software emulator startup may take minutes; Android 15 system apps showed ANRs, older API 29 selected for supported-platform interaction test. No physical-phone performance result is claimed.

UI follow-up: integer counters formatted without JSON float suffixes; original icon added. Immediate detachment of pressed upgrade buttons replaced with hidden/deferred deletion after native can_process message. Current APK UI retested: second spin +90 coins/+1 spin and XP 19; dock upgrade -140 coins, XP 34, beacon/dock level 1, 166 coins. Previous can_process error did not recur. Current APK SHA256: ab6475304e540d6ba51e6ff2b5a8bee3c69386a04de218c154fb592a6cff4bda.

Emulator limitation: some cold starts stall on the Android launch screen before native Godot initialization; force-stop/relaunch was required. Do not treat the software emulator as a phone startup/performance benchmark. A forced headless exit after 3 frames during pending HTTP requests emitted an ObjectDB cleanup warning; the awaited HTTP smoke/restart tests passed cleanly.

Versioned visual evidence: [initial spin](evidence/android-spin.png), [initial restart](evidence/android-restart.png), [updated APK restore](evidence/android-final-home.png), [updated APK upgrade](evidence/android-final-upgrade.png).
