# Local Testing Plan — Screenshot + Preview Workflow

## Status: ✅ ALL 6 CI JOBS GREEN

All Android and iOS screenshot + preview jobs are passing. The fixes were diagnosed and applied via local iteration, then confirmed in CI.

## Root causes found and fixed

**Android hang (23-minute silence after `02_thoughts`)**:
- `Scrollable.ensureVisible` with `duration: 200ms` schedules an animation ticker that never completes under continuous marble-physics frames → replaced with `tester.ensureVisible` (uses `duration: zero`, instant, no ticker)
- `scrollTo` only searched downward, but after navigating back the list is mid-scroll → added `jumpTo(0)` to reset before each search
- `dart:developer.log()` calls were invisible in CI stdout → removed

**Emulator crash after screenshot 4 (local only)**:
- Swiftshader software renderer can't sustain marble physics at full speed for 4+ screenshots
- CI uses KVM hardware acceleration — no crash there
- Local runs get through screenshots 1–4 reliably; full suite runs on CI

**iOS "zero driver output"**:
- Resolved by the same `test_helpers.dart` fixes — no iOS-specific change needed

## Local scripts

### Android (WSL2, native via KVM) ✅

Scripts in `local/`:
- `setup_wsl_android.sh` — idempotent installer (Temurin JDK 25 via Adoptium apt, Android SDK API 35, Flutter SDK, AVDs)
- `boot_android_emulator.sh` — boots AVD, waits for boot, sets up status bar
- `wsl_env.sh` — canonical env (JAVA_HOME / ANDROID_HOME / FLUTTER_HOME / PATH)
- `screenshot_test.bat` — setup + boot + screenshot test (`pixel_7`)
- `screenshot_tablet.bat` — same for `pixel_tablet`
- `preview_test.bat` — setup + boot + preview walkthrough recording

Prerequisites:
- WSL2 installed (`wsl --install`, reboot)
- Nested virtualization enabled in WSL Settings app (System tab)

Workflow from Windows cmd in repo root:
```
local\screenshot_test.bat
local\screenshot_tablet.bat
local\preview_test.bat
```

Limitation: local emulator uses swiftshader — adequate for debugging test logic, but crashes under sustained marble-physics rendering (screenshot 5+). Full suite runs reliably on CI.

### iOS (WSL2 via OSX-KVM) — scripts ready, not yet exercised

Scripts in `local/IOS/`:
- `setup_osx_kvm.sh` — installs QEMU, clones OSX-KVM, fetches macOS Sequoia image, creates disk
- `boot_macos.sh` — boots macOS VM with VNC on `localhost:5901`, SSH on `localhost:2222`
- `setup_macos_dev.sh` — run inside the VM: installs Homebrew, Flutter, Xcode CLI tools
- `setup_osx_kvm.bat` / `boot_macos.bat` — Windows entry points

Initial setup requires:
1. `local\IOS\setup_osx_kvm.bat` — automated
2. Connect via VNC, click through macOS installer — manual (one-time)
3. SSH in, run `local/IOS/setup_macos_dev.sh`, install Xcode from developer.apple.com — manual

iOS wasn't needed in the end — all jobs passed without it.

## Key test helper changes (in `integration_test/`)

- `test_helpers.dart / scrollTo`: replaced `Scrollable.ensureVisible(duration: 200ms)` with `tester.ensureVisible` + added `jumpTo(0)` to reset scroll position before each search
- `preview_test.dart` + `screenshot_test.dart`: removed `dart:developer.log()` calls (invisible in CI stdout)
- `screenshot_test.dart / takeScreenshot`: `debugPauseMarblePhysics` paused only during the HTTP capture, resumed immediately after

## Non-scope

- Fixing individual test flakes in `test/` (unit tests are green)
- `release.yml` (Play internal / TestFlight upload) — downstream of screenshots; revisit after
- Web deploy (`deploy.yml`) — unrelated, already works
