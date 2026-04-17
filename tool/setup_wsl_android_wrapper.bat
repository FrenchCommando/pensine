@echo off
REM Runs the WSL2 Android setup script from Windows.
REM Usage:  tool\setup_wsl_android.bat

REM Enable nested virtualization for KVM (needed by the Android emulator).
set WSLCONFIG=%USERPROFILE%\.wslconfig
findstr /c:"nestedVirtualization" "%WSLCONFIG%" >nul 2>&1
if errorlevel 1 (
    echo Enabling nested virtualization in %WSLCONFIG%...
    echo [wsl2]>> "%WSLCONFIG%"
    echo nestedVirtualization=true>> "%WSLCONFIG%"
    echo Restarting WSL...
    wsl --shutdown
)

wsl bash tool/setup_wsl_android.sh
