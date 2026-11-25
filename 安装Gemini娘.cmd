@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Install-GeminiNiang.ps1" -DownloadCli -RegisterPlugin -ManualCopyFallback -StartWidget
pause
