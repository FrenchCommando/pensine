@echo off
REM Sets up WSL2 Android (idempotent), boots emulator, runs screenshot test, exits.
REM Usage:  local\screenshot_test.bat [pixel_7|pixel_tablet]
cd /d "%~dp0\.."
set AVD=%~1
if "%AVD%"=="" set AVD=pixel_7
"%SystemRoot%\System32\wsl.exe" bash -c "source local/wsl_env.sh && local/setup_wsl_android.sh && local/boot_android_emulator.sh %AVD% && tool/run_screenshot_test.sh"
