@echo off
REM Boots emulator and records Android preview walkthrough.
REM Usage:  local\preview_test.bat [pixel_7|pixel_tablet]
cd /d "%~dp0\.."
set AVD=%~1
if "%AVD%"=="" set AVD=pixel_7
"%SystemRoot%\System32\wsl.exe" bash -c "source local/wsl_env.sh && local/setup_wsl_android.sh && local/boot_android_emulator.sh %AVD% && tool/run_android_preview.sh"
