# Project state

Date: 2026-10-07. Repository: `/workspace/Projects`, current branch `work`; remote repository was empty at the start. Commits are local; no push or publication performed.

## Phase

PHASE 0–4 vertical slice implemented. Android debug APK built and signature verified; actual emulator launch/interaction validation is in progress. Do not create MILESTONE_1_COMPLETE.md until Android runtime checks pass.

## Implemented

Godot 4.6.3 portrait island/slot/profile UI, vector symbols and island, tutorial state, auto guest, authenticated HTTP, durable pending UUID command and retry, cached presentation only. PostgreSQL guest sessions, profile/wallet/energy/buildings, config revisions, operations, spin history, currency ledger. Server-time regeneration, server RNG, server upgrade prices, XP progression, two worlds and once-only final completion. Strict bounded config validation, compatible activation CLI. No developer currency-grant HTTP routes.

## Verified

29 backend tests pass against isolated PostgreSQL 17 `_test` DB (unit, replay/concurrency, authoritative validation, pricing/XP, worlds, expiry/ban and config boundaries). Ruff + GDScript formatting/lint pass. Godot headless real client E2E passes: guest -> spin -> upgrade -> ambiguous-response replay -> restart restore. Native Android debug export passes, arm64/x86_64 APK signature verified. Linux debug executable built and launched. Windows x86_64 EXE cross-exported successfully and PE header verified; PowerShell workflow syntax parsed with PowerShell 7.4.6. Windows 10 runtime/Docker Desktop execution is not verified in this Linux environment. Unreachable-server transport test passes without JSON parsing errors. Original SQL and custom-format backups saved under ignored `.local/backups`; data moved to bind-mounted `.local/postgres` and restored; health/profile rechecked.

## Remaining / known limitations

Android runtime check pending. The emulator's legacy GLES SwiftShader renderer cannot compile Godot shaders (uniform limit); ANGLE/swangle selected in scripts/run_emulator.sh. This is an emulator configuration issue, not a passed runtime check. No known failed backend behavior. Regeneration naturally changes energy between delayed restore tests; test permits valid capped regeneration. Original vector placeholders; no audio/provider integrations. Google auth/linking/token recovery, throttling/guest abuse protection, secure keystore storage, HTTPS deployment, production signing, analytics/privacy and physical-device performance tests are not implemented. Authentication expires after 90 days; client reports invalid session without silently replacing account. Losing first guest response may orphan an account. Future feature buttons describe their planned status.

## Run

Windows 10: `powershell -ExecutionPolicy Bypass -File scripts/windows.ps1 setup`, then `server`; another terminal `client -Godot "C:\Tools\Godot.exe"` and `test`. Docker Desktop Linux containers uses named volume and localhost port mapping (no host networking). See README.

`cd /workspace/Projects; scripts/setup.sh; scripts/start.sh` (foreground API). In another session: `scripts/test.sh`, `scripts/client_smoke.sh`; `source scripts/env.sh; godot --path client`. Android: `scripts/install_android.sh; scripts/build_android.sh`, then `adb install`, `adb reverse tcp:8000 tcp:8000`, launch package `com.starharbor.spinkingdom`. See README for configuration and release cautions.

## Important decisions

Godot scene workflow chosen over Flutter/Flame for 2D maps/animation; FastAPI/PostgreSQL monolith without paid managed dependency. Every gameplay operation locks the player row, binds key to action/payload and commits result/state/ledger atomically. Server-only clocks/randomness/rewards. Config activation preserves existing world/building identities and level counts. Do not reset developer state or use a worktree in cloud tasks; reuse checkout and ignore local data.

## Next task

Finish Android runtime validation and record milestone evidence. install_script/start_skill were saved in the cloud draft; review/save/publish by the user is still pending. Fresh-task restoration of local-only commits is unverified. Then PHASE 5: combat server action tickets and shield/attack/raid transactions, with concurrency and replay tests before UI expansion.
