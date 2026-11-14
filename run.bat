@echo off
:: ===================================================================
::  OPLUS-TURBO: ONE-CLICK WINDOWS LAUNCHER
::  Automatically bypasses PowerShell Execution Policy safely
:: ===================================================================
title OPlus-Turbo: Safe ADB Performance & Battery Optimizer
cd /d "%~dp0"

echo ===================================================================
echo   Launching OPlus-Turbo...
echo ===================================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimize.ps1"

echo.
echo ===================================================================
echo   Finished. Press any key to close this window.
echo ===================================================================
pause >nul
