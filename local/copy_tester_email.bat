@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0copy_tester_email.ps1"
timeout /t 3 /nobreak >nul
