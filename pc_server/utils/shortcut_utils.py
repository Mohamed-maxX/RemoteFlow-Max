"""
RemoteFlow Max - Windows Shortcut Generator
Ensures desktop and start menu shortcuts exist for quick launching.
"""

import os
import sys
import subprocess
import logging

logger = logging.getLogger("RemoteFlow.Shortcuts")

def create_windows_shortcuts(target_exe: str, icon_path: str, work_dir: str):
    """Creates Desktop and Start Menu shortcuts pointing to RemoteFlowMax.exe."""
    ps_script = f"""
    $WshShell = New-Object -comObject WScript.Shell
    $DesktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop", "RemoteFlow Max Server.lnk")
    $StartPath = [System.IO.Path]::Combine($env:APPDATA, "Microsoft\\Windows\\Start Menu\\Programs", "RemoteFlow Max Server.lnk")
    
    $Target = "{target_exe}"
    $Icon = "{icon_path},0"
    $WorkDir = "{work_dir}"

    $Shortcut1 = $WshShell.CreateShortcut($DesktopPath)
    $Shortcut1.TargetPath = $Target
    $Shortcut1.WorkingDirectory = $WorkDir
    $Shortcut1.IconLocation = $Icon
    $Shortcut1.Description = "RemoteFlow Max - PC Host Control Center"
    $Shortcut1.Save()

    $Shortcut2 = $WshShell.CreateShortcut($StartPath)
    $Shortcut2.TargetPath = $Target
    $Shortcut2.WorkingDirectory = $WorkDir
    $Shortcut2.IconLocation = $Icon
    $Shortcut2.Description = "RemoteFlow Max - PC Host Control Center"
    $Shortcut2.Save()
    """
    try:
        subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_script], check=True, timeout=5)
        logger.info("Desktop and Start Menu shortcuts confirmed.")
        return True
    except Exception as e:
        logger.warning(f"Could not create shortcuts: {e}")
        return False
