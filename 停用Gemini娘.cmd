@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-GeminiNiang.ps1" -UnregisterPlugin
pause
