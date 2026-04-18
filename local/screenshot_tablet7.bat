@echo off
REM Boots nexus_7 (7" tablet) emulator and runs screenshot test.
cd /d "%~dp0\.."
"%SystemRoot%\System32\wsl.exe" bash -c "source local/wsl_env.sh && local/setup_wsl_android.sh && local/boot_android_emulator.sh nexus_7 && tool/run_screenshot_test.sh"
