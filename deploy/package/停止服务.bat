@echo off
REM AI Shu Zi Ren - stop service entry
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\stop-duix.ps1"
if errorlevel 1 (
  echo.
  echo Script exited with errors. See messages above.
  pause
)
