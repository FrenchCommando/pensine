@echo off
REM Sets up OSX-KVM in WSL2 for local iOS testing.
REM Run once. After completion, use local\boot_macos.bat to start the VM.
cd /d "%~dp0\..\.."
"%SystemRoot%\System32\wsl.exe" bash -c "cd /mnt/c/Users/Martial/pensine && bash local/IOS/setup_osx_kvm.sh"
