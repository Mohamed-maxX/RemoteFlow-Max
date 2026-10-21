$startupFolder = [System.Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder "RemoteFlowMax.lnk"
$targetScript = Join-Path (Split-Path $PSScriptRoot -Parent) "Start_Silent.vbs"
$workingDir = Split-Path $PSScriptRoot -Parent

$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetScript
$shortcut.WorkingDirectory = $workingDir
$shortcut.Description = "RemoteFlow Max Silent Background Server"
$shortcut.Save()

if (Test-Path $shortcutPath) {
    Write-Host "[SUCCESS] RemoteFlow Max shortcut installed to Windows Startup:" -ForegroundColor Green
    Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
    Write-Host "Target:   $targetScript" -ForegroundColor Cyan
    Write-Host "`nRemoteFlow Max will now start automatically whenever Windows logs in." -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Could not create startup shortcut." -ForegroundColor Red
}
