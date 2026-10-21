@echo off
title RemoteFlow Max - Remove from Windows Startup
echo ======================================================================
echo          RemoteFlow Max - Remove from Windows Startup
echo ======================================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall_startup.ps1"
echo.
pause
