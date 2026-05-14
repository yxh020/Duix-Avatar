@echo off
REM AI Shu Zi Ren - environment diagnostic entry
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\diagnose-duix.ps1"
if errorlevel 1 (
  echo.
  echo Script exited with errors. See messages above.
  pause
)
