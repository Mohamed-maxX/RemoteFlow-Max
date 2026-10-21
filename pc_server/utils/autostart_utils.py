"""
RemoteFlow Max - Windows Auto-Start Manager
Controls launching RemoteFlow Max automatically with Windows via registry HKCU\\...\\Run.
"""

import sys
import os
import winreg
import logging

logger = logging.getLogger("RemoteFlow.AutoStart")

REG_SUBKEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
APP_NAME = "RemoteFlowMax"

def get_target_executable_path() -> str:
    """Returns absolute path to the official executable or python runner."""
    if getattr(sys, "frozen", False):
        return sys.executable
    # Check if compiled exe exists in parent or current directory
    exe_candidate = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "RemoteFlowMax.exe")
    if os.path.exists(exe_candidate):
        return exe_candidate
    return sys.executable

def is_autostart_enabled() -> bool:
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_SUBKEY, 0, winreg.KEY_READ)
        try:
            val, _ = winreg.QueryValueEx(key, APP_NAME)
            winreg.CloseKey(key)
            return bool(val)
        except FileNotFoundError:
            winreg.CloseKey(key)
            return False
    except Exception as e:
        logger.warning(f"Error checking autostart status: {e}")
        return False

def set_autostart(enable: bool, app_path: str = None) -> bool:
    target_path = app_path or get_target_executable_path()
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_SUBKEY, 0, winreg.KEY_SET_VALUE)
        if enable:
            quoted_path = f'"{target_path}"'
            winreg.SetValueEx(key, APP_NAME, 0, winreg.REG_SZ, quoted_path)
            logger.info(f"Enabled Windows autostart: {quoted_path}")
        else:
            try:
                winreg.DeleteValue(key, APP_NAME)
                logger.info("Disabled Windows autostart.")
            except FileNotFoundError:
                pass
        winreg.CloseKey(key)
        return True
    except Exception as e:
        logger.error(f"Failed to update autostart setting: {e}")
        return False
