@echo off
title Stop RemoteFlow Max Server
echo ======================================================================
echo                  RemoteFlow Max - Stop Server
echo ======================================================================
echo Stopping RemoteFlow Max background process...
taskkill /F /T /IM RemoteFlowMax.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] RemoteFlow Max server stopped successfully.
) else (
    echo [INFO] RemoteFlow Max server was not running.
)
echo.
ping 127.0.0.1 -n 2 >nul
