@echo off
title Soulframe - Check Last Session
REM ---------------------------------------------------------------------------
REM  Double-click to check whether the "items don't save" bug happened in your
REM  most recent play session. This reads the log once and tells you the result,
REM  then waits for you to close it. (Use "Watch Soulframe.bat" to catch the bug
REM  live while you play.)
REM ---------------------------------------------------------------------------

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sf-inventory-guard.ps1" -Scan

echo.
pause
