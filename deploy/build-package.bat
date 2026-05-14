@echo off
REM Build the AI Shu Zi Ren integration package
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-package.ps1"
if errorlevel 1 (
  echo.
  echo Build failed. See messages above.
  pause
)
