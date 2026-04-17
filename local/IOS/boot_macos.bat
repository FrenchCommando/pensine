@echo off
REM Boots the macOS VM. Connect via VNC on localhost:5901.
REM SSH available on localhost:2222 after macOS is installed.
cd /d "%~dp0\.."
"%SystemRoot%\System32\wsl.exe" bash -c "cd /mnt/c/Users/Martial/pensine && bash local/boot_macos.sh"
