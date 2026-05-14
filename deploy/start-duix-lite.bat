@echo off
REM Pure-ASCII launcher. Calls start-duix-lite.ps1 in the same folder.
REM All real logic + Chinese output live in the .ps1 (UTF-8 BOM).
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-duix-lite.ps1"
if errorlevel 1 (
  echo.
  echo Script exited with errors. See messages above.
  pause
)
