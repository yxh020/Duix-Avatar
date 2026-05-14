@echo off
REM AI Shu Zi Ren - one-click launcher entry
REM This BAT is intentionally ASCII-only. The PS1 below carries all logic and Chinese text.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start-duix.ps1"
if errorlevel 1 (
  echo.
  echo Script exited with errors. See messages above.
  pause
)
