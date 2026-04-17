# Local Testing Plan — Screenshot + Preview Workflow

Context handoff for the desktop session. CI-based iteration on `screenshots.yml` has stalled because we can't see what's happening during a run — the goal of moving local is **visibility**, not speed. A local hang we can attach a debugger to beats a CI hang we can only watch time out. WSL2 has `/dev/kvm`, which makes both Android (native) and iOS (macOS-in-KVM via QEMU/OpenCore) viable without leaving Linux. No manual-screenshot compromise, no `--local` config split (scripts stay environment-neutral).

## Findings

### Current regression

Last known-good state: commit `23aad55` (`updated notes`, 2026-04-17 03:13 UTC). Run `24545788565` was cancelled at run-level but **all 6 jobs succeeded individually** (both Android profiles, both iOS devices, both preview jobs).

Commits since that have silently broken the workflow, in order:

- `35f1fa3` scroll better — `integration_test/test_helpers.dart`
- `5f8e86a` shake in preview — `integration_test/preview_test.dart`
- `ea9dd67` better deployment — reworked iOS screenshot path (added `tool/run_ios_screenshot_test.sh`, moved iOS to host-side screenshot server)
- `a9e9904` big cleanup — consolidated helpers into `openBoard()`
- `a0fd00c` fix timeout — added `dart:developer.log()` breadcrumbs, reworked iOS preview recorder

All post-regression runs: **0 jobs passed** (15 runs, 9 recent ones all 0/6).

We won't revert — too much forward progress is in those commits. We'll diagnose and fix forward once there's a local loop.

### Latest failure modes (run 24571367925, commit a0fd00c)

**Android pixel_7** (only job that got anywhere):
- `14:57:11` — driver connects, test begins
- `14:57:15` — `POST /screenshot/01_home` 200 ✓
- `14:57:23` — `POST /screenshot/02_thoughts` 200 ✓
- `14:57:23` — last EGL frame-stats line; all rendering output stops
- `15:20:41` — cancelled (23 min of silence)
- Hang is somewhere in the 4 lines between `02_thoughts` and `03_flashcards`: `tap(Back)` → `settle()` → `openBoard('Essentials')` → `takeScreenshot(03_flashcards)`. Either the app deadlocked or the emulator froze.
- The 2 captured PNGs uploaded as artifact `screenshots-android-pixel_7` (425 KB) even though the job was cancelled.

**iOS iPhone 16 Pro Max**:
- `14:57:30` — Xcode build done
- `15:20:58` — cancelled
- **Zero** driver output in between — no `VMServiceFlutterDriver: Isolate is paused` line, no test runner "+0" line, nothing. Either the driver never attached or stdout isn't flushing from `flutter drive` on macos-latest.

iPad and pixel_tablet show the same patterns (not reviewed line-by-line but status was identical).

### Diagnostic dead ends so far

- `dart:developer.log()` (added in `a0fd00c`) routes through the VM service `_Log` stream. It does **not** reach `flutter drive` stdout in CI — it appears in Android logcat and iOS unified-log, neither of which CI captures. Replacing with `print`/`debugPrint` was tried and reverted; not the right fix either since the screenshot server's POST log already tells us test progression.
- `gh run view --log` refuses in-progress runs (confirmed).
- `gh api /repos/{owner}/{repo}/actions/jobs/{id}/logs` — I asserted this doesn't stream live but never verified. Worth testing once, then stop speculating about GitHub internals either way.
- GitHub web UI streams live logs via an internal endpoint we don't control — not useful for scripted iteration.

## Plan

Build a local iteration loop in WSL2 that runs the same scripts CI runs, for both Android and iOS. One codepath, no env-specific forks.

### Android (WSL2, native via KVM) ✅ DONE

Scripts (in `local/` — separated from `tool/` which holds CI/shared scripts):
- `local/setup_wsl_android.sh` — idempotent installer (JDK 17, Android SDK, Flutter Linux SDK, AVDs)
- `local/boot_android_emulator.sh` — boots AVD, waits for boot, runs `tool/setup_android_status_bar.sh`
- `local/wsl_env.sh` — canonical env (JAVA_HOME / ANDROID_HOME / FLUTTER_HOME / PATH); sourced by setup, the `.bat`, and `~/.bashrc`
- `local/screenshot_test.bat` — single Windows entry point: setup + boot + `tool/run_screenshot_test.sh`, all in one WSL session

Prerequisites (user):
- Install WSL2 (`wsl --install`, reboot)
- Nested virtualization enabled in the WSL Settings app (System tab)

Workflow from Windows (cmd in repo root):
```
local\screenshot_test.bat              (defaults to pixel_7)
local\screenshot_test.bat pixel_tablet
```

### iOS (WSL2 via OSX-KVM)

- QEMU + OpenCore + macOS 14 or 15 VM image (OSX-KVM project is the reference setup)
- VM sizing: 6 vCPU, 6 GB RAM, 80 GB disk (adjust based on desktop's specs)
- Inside the VM: Xcode (download ~15 GB), Command Line Tools, iOS Simulator runtime (matches the simulator SDK CI's macos-latest uses)
- Network: VM needs loopback access to the host-side `screenshot_server.py` over 127.0.0.1 — verify the OSX-KVM networking mode (user mode / vmnet) supports that before committing to a mode
- `tool/boot_ios_simulator.sh` already works script-side; the only difference vs CI is we're running it inside the VM

Caveats (visibility matters, time doesn't):
- KVM for iOS works — `/dev/kvm` is available in WSL2, so QEMU runs macOS with full CPU virtualization. No GPU passthrough means Xcode / simulator render slowly, but that is irrelevant: the reason for local is that we can see what's happening, attach the VM service, step through hangs. Iteration speed is already a solved problem the moment we stop staring at a 40-minute opaque CI run.
- Apple EULA on non-Apple hardware is a grey area for development use. User's call.
- Simulator behavior in KVM may diverge from Apple Silicon `macos-latest` runners on edge cases. If we hit a CI-only bug later, we address it then.

### Iteration plan

Once the env is up, fix the 4 CI jobs in this order (each verified locally, then pushed and confirmed in CI):

1. **Android pixel_7 screenshots** — the one where we already know the hang window. Reproduce the hang locally with the VM service attached so we can see what the app is actually doing between `02_thoughts` and `03_flashcards`.
2. **Android pixel_tablet screenshots** — expect same fix as above.
3. **Android preview** — separate `preview_test.dart`, same helpers. May share root cause.
4. **iOS iPhone + iPad screenshots + preview** — the "zero driver output" hang. Local repro will show whether it's a launch/attach issue or a stdout-flushing issue in CI only. If CI-specific, we narrow from there.

## Scope decisions already made

- **No revert to `23aad55`** — user explicitly rejected; forward progress preserved.
- **No manual screenshots** — automation is the goal, not a fallback.
- **No `--local` flag / split config** — scripts are environment-neutral. CI and local run the same `run_screenshot_test.sh` / `run_ios_preview.sh`. Only the emulator/simulator boot step differs, and only because CI uses `reactivecircus/android-emulator-runner` as a wrapper.
- **iOS included in local scope** — OSX-KVM + Xcode in a VM, despite performance hit.
- **Stop guessing at GitHub Actions internals** — any question about `gh api` endpoints, log streaming, or runner behavior gets answered by one explicit test, not speculation.

## Reusable-skill scope

This work is scaffolding for every future Flutter project that needs CI-based integration tests. Extract the setup into a reusable form after this project's tests are green:

- `local/setup_wsl_android.sh` + `local/wsl_env.sh` — one-shot installer for the Android side of WSL2.
- Separate doc / repo for the OSX-KVM setup (it's heavier and more interesting to maintain outside a project repo).
- A short runbook: "boot Android emulator in WSL2 → run flutter drive → iterate" that someone else could follow in 30 minutes.

## Environment inventory (laptop — desktop will likely have more)

WSL2:
- Ubuntu 24.04, kernel 5.15, `/dev/kvm` present
- 8 vCPU, 7.7 GB RAM
- `python3`, `openssl`, `bash` present; `adb` and Java not installed
- `/mnt/c/Users/marti/flutter/bin/flutter` is the Windows flutter binary — not usable from Linux, we'll install a Linux flutter separately

Windows:
- Flutter SDK at `C:\Users\marti\flutter`
- Android SDK at `C:\Users\marti\AppData\Local\Android\Sdk` (platform-tools, emulator, system images, build-tools present)
- AVDs: `Pixel_9_Pro_XL_API_33`, `Pixel_9_Pro_XL_API_UpsideDownCakePrivacySandbox`, `Pixel_Tablet_API_UpsideDownCakePrivacySandbox`, `Small_Phone` — none match the CI profile names (`pixel_7`, `pixel_tablet`), so we create fresh ones in WSL2
- Git Bash, `gh` 2.90.0

Not on this machine: any macOS / Xcode (that's the OSX-KVM setup).

## Open questions (resolve once, stop speculating)

- Does `gh api /repos/{owner}/{repo}/actions/jobs/{id}/logs` return partial logs for in-progress jobs, or does it only 302 to a post-completion archive? Test with one curl.
- Does the Android hang between `02_thoughts` and `03_flashcards` reproduce on first try locally, or is it emulator-state-dependent?
- Does the iOS "no driver output" issue happen locally inside the VM too, or is it specific to GitHub's `macos-latest` stdout handling?

## Non-scope

- Fixing individual test flakes in `test/` (unit tests are green).
- `release.yml` (Play internal / TestFlight upload) — downstream of screenshots working; revisit after.
- Web deploy (`deploy.yml`) — unrelated, already works.
