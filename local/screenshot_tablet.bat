@echo off
REM Boots pixel_tablet (10" tablet) emulator and runs screenshot test.
cd /d "%~dp0\.."
"%SystemRoot%\System32\wsl.exe" bash -c "source local/wsl_env.sh && local/setup_wsl_android.sh && local/boot_android_emulator.sh pixel_tablet && tool/run_screenshot_test.sh"
