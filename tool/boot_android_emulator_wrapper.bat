@echo off
REM Boots an Android emulator in WSL2 from Windows.
REM Usage:  tool\boot_android_emulator.bat pixel_7
if "%~1"=="" (
    echo ERROR: AVD name required (e.g. pixel_7, pixel_tablet)
    exit /b 1
)
wsl bash tool/boot_android_emulator.sh %1
