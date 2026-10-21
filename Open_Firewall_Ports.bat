@echo off
title RemoteFlow Max - Windows Firewall Configuration
echo ======================================================================
echo          RemoteFlow Max - Opening Firewall Ports (TCP & UDP)
echo ======================================================================
echo.

:: Check for administrative rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ELEVATION REQUIRED] Requesting Administrator Privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~dpnx0\"\"' -Verb RunAs"
    exit /b
)

echo [1/3] Allowing TCP Ports 5055, 5056, 5057, 5058...
netsh advfirewall firewall delete rule name="RemoteFlow Max TCP" >nul 2>&1
netsh advfirewall firewall add rule name="RemoteFlow Max TCP" dir=in action=allow protocol=TCP localport=5055,5056,5057,5058

echo [2/3] Allowing UDP Ports 5055, 5056, 5057, 5058...
netsh advfirewall firewall delete rule name="RemoteFlow Max UDP" >nul 2>&1
netsh advfirewall firewall add rule name="RemoteFlow Max UDP" dir=in action=allow protocol=UDP localport=5055,5056,5057,5058

echo [3/3] Allowing RemoteFlowMax.exe executable directly...
netsh advfirewall firewall delete rule name="RemoteFlow Max App" >nul 2>&1
netsh advfirewall firewall add rule name="RemoteFlow Max App" dir=in action=allow program="%~dp0RemoteFlowMax.exe" enable=yes

echo.
echo ======================================================================
echo [SUCCESS] All firewall rules applied successfully!
echo RemoteFlow Max is now accessible to all mobile devices on your Wi-Fi.
echo ======================================================================
echo.
pause
