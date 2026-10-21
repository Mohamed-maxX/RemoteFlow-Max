@echo off
title RemoteFlow Max - Install to Windows Startup
echo ======================================================================
echo          RemoteFlow Max - Install to Windows Startup
echo ======================================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install_startup.ps1"
echo.
pause
