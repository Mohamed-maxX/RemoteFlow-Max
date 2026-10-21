$startupFolder = [System.Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupFolder "RemoteFlowMax.lnk"

if (Test-Path $shortcutPath) {
    Remove-Item -Path $shortcutPath -Force
    Write-Host "[SUCCESS] RemoteFlow Max shortcut removed from Windows Startup." -ForegroundColor Green
} else {
    Write-Host "[INFO] RemoteFlow Max shortcut was not found in Startup folder." -ForegroundColor Yellow
}
