@echo off
title Soulframe Inventory Guard
REM ---------------------------------------------------------------------------
REM  Double-click this file to start watching Soulframe for the "items don't
REM  save" bug. Keep this window open while you play. If a red warning appears,
REM  log out and back in. To stop watching, just close this window.
REM
REM  This just runs the PowerShell script next to it (sf-inventory-guard.ps1).
REM  Keep both files together in the same folder.
REM ---------------------------------------------------------------------------

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sf-inventory-guard.ps1"

echo.
echo The watcher has stopped. You can close this window.
pause >nul
