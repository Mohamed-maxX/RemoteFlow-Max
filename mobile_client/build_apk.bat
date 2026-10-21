@echo off
title Build RemoteFlow Max Android APK
echo ======================================================================
echo             RemoteFlow Max - Mobile Client APK Builder
echo ======================================================================
echo.

set TOOLS_DIR=%~dp0..\build_tools
if exist "%TOOLS_DIR%\flutter\bin\flutter.bat" (
    echo [INFO] Using portable build tools from: %TOOLS_DIR%
    set "JAVA_HOME=%TOOLS_DIR%\jdk\jdk-17.0.20.1+1"
    set "ANDROID_HOME=%TOOLS_DIR%\android-sdk"
    set "PATH=%TOOLS_DIR%\flutter\bin;%JAVA_HOME%\bin;%ANDROID_HOME%\cmdline-tools\latest\bin;%ANDROID_HOME%\platform-tools;%PATH%"
)

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter SDK was not found!
    echo.
    echo Please make sure build_tools\flutter exists or Flutter is in your PATH.
    pause
    exit /b 1
)

echo [1/3] Getting dependencies (flutter pub get)...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to fetch packages.
    pause
    exit /b 1
)

echo.
echo [2/3] Building Release APK (flutter build apk --release)...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] APK build failed.
    pause
    exit /b 1
)

set OUTPUT_DIR=%~dp0build\app\outputs\flutter-apk
set APK_FILE=%OUTPUT_DIR%\app-release.apk

if exist "%APK_FILE%" (
    echo.
    echo ======================================================================
    echo [SUCCESS] Android APK built successfully!
    echo Copying to root workspace as RemoteFlowMax.apk...
    copy /Y "%APK_FILE%" "%~dp0..\RemoteFlowMax.apk" >nul
    echo.
    echo APK Location: %~dp0..\RemoteFlowMax.apk
    echo.
    echo You can now send RemoteFlowMax.apk to your Android phone (via USB,
    echo Google Drive, WhatsApp, or through RemoteFlow Max File Drop) and install it!
    echo ======================================================================
) else (
    echo [WARNING] Build finished but could not locate app-release.apk at:
    echo %APK_FILE%
)

pause
