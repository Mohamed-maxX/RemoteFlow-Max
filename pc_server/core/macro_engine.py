"""
RemoteFlow Max - Virtual Stream Deck & Macro Engine
Executes customizable keystroke sequences, PowerShell scripts, app launchers, and URL injectors.
Loads and saves JSON-based deck configurations.
"""

import subprocess
import os
import webbrowser
import logging
import json
from typing import List, Dict, Any, Optional
from pc_server.core.input_engine import InputEngine

logger = logging.getLogger("RemoteFlow.MacroEngine")

DEFAULT_MACRO_DECKS = [
    {
        "id": "deck_obs",
        "name": "Streaming & OBS Deck",
        "buttons": [
            {"id": "b1", "label": "Stream Toggle", "icon": "live_tv", "type": "hotkey", "payload": {"keys": ["ctrl", "f9"]}, "color": "#FF5722"},
            {"id": "b2", "label": "Record Toggle", "icon": "fiber_manual_record", "type": "hotkey", "payload": {"keys": ["ctrl", "f10"]}, "color": "#E53935"},
            {"id": "b3", "label": "Discord Mute", "icon": "mic_off", "type": "hotkey", "payload": {"keys": ["ctrl", "shift", "m"]}, "color": "#7C4DFF"},
            {"id": "b4", "label": "Discord Deafen", "icon": "headset_off", "type": "hotkey", "payload": {"keys": ["ctrl", "shift", "d"]}, "color": "#536DFE"},
            {"id": "b5", "label": "Snipping Tool", "icon": "crop", "type": "hotkey", "payload": {"keys": ["win", "shift", "s"]}, "color": "#00E5FF"},
            {"id": "b6", "label": "Mute All", "icon": "volume_off", "type": "hotkey", "payload": {"keys": ["vol_mute"]}, "color": "#FF9100"},
        ]
    },
    {
        "id": "deck_dev",
        "name": "Developer & Scripts",
        "buttons": [
            {"id": "d1", "label": "Flush DNS", "icon": "dns", "type": "script", "payload": {"command": "ipconfig /flushdns"}, "color": "#00E5FF"},
            {"id": "d2", "label": "Clean Temp", "icon": "delete_sweep", "type": "script", "payload": {"command": 'powershell -Command "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue"'}, "color": "#FF5722"},
            {"id": "d3", "label": "PowerShell", "icon": "terminal", "type": "launch", "payload": {"path": "powershell.exe"}, "color": "#2979FF"},
            {"id": "d4", "label": "Task Manager", "icon": "insights", "type": "hotkey", "payload": {"keys": ["ctrl", "shift", "esc"]}, "color": "#00E676"},
            {"id": "d5", "label": "File Explorer", "icon": "folder_open", "type": "hotkey", "payload": {"keys": ["win", "e"]}, "color": "#FFD600"},
            {"id": "d6", "label": "Clipboard Hist", "icon": "content_paste", "type": "hotkey", "payload": {"keys": ["win", "v"]}, "color": "#7C4DFF"},
        ]
    },
    {
        "id": "deck_browser",
        "name": "Browser & Navigation",
        "buttons": [
            {"id": "br1", "label": "New Tab", "icon": "add_box", "type": "hotkey", "payload": {"keys": ["ctrl", "t"]}, "color": "#00E5FF"},
            {"id": "br2", "label": "Close Tab", "icon": "close", "type": "hotkey", "payload": {"keys": ["ctrl", "w"]}, "color": "#FF1744"},
            {"id": "br3", "label": "Reopen Tab", "icon": "restore", "type": "hotkey", "payload": {"keys": ["ctrl", "shift", "t"]}, "color": "#7C4DFF"},
            {"id": "br4", "label": "Reload (F5)", "icon": "refresh", "type": "hotkey", "payload": {"keys": ["f5"]}, "color": "#00E676"},
            {"id": "br5", "label": "Zoom In", "icon": "zoom_in", "type": "hotkey", "payload": {"keys": ["ctrl", "+"]}, "color": "#2979FF"},
            {"id": "br6", "label": "Zoom Out", "icon": "zoom_out", "type": "hotkey", "payload": {"keys": ["ctrl", "-"]}, "color": "#FF9100"},
        ]
    }
]

class MacroEngine:
    def __init__(self, input_engine: InputEngine):
        self.input_engine = input_engine
        self.decks = DEFAULT_MACRO_DECKS

    def get_decks(self) -> List[Dict[str, Any]]:
        """Returns all configured Macro / Stream Decks."""
        return self.decks

    def execute_macro(self, macro_type: str, payload: Dict[str, Any]) -> bool:
        """
        Executes action triggered by a Stream Deck macro button.
        macro_type: 'hotkey', 'script', 'launch', 'url', 'text'
        """
        m_type = macro_type.lower()
        try:
            if m_type == "hotkey":
                keys = payload.get("keys", [])
                if keys:
                    self.input_engine.send_hotkey(keys)
                    return True

            elif m_type == "script":
                command = payload.get("command", "")
                if command:
                    # Execute in background with hidden window on Windows
                    startupinfo = None
                    if os.name == "nt":
                        startupinfo = subprocess.STARTUPINFO()
                        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                    subprocess.Popen(command, shell=True, startupinfo=startupinfo)
                    logger.info(f"[Macro] Executed background script: {command}")
                    return True

            elif m_type == "launch":
                path = payload.get("path", "")
                if path:
                    os.startfile(path)
                    logger.info(f"[Macro] Launched app: {path}")
                    return True

            elif m_type == "url":
                url = payload.get("url", "")
                if url:
                    webbrowser.open(url)
                    logger.info(f"[Macro] Opened URL: {url}")
                    return True

            elif m_type == "text":
                text = payload.get("text", "")
                if text:
                    self.input_engine.type_text(text)
                    return True

        except Exception as e:
            logger.warning(f"[Macro] Execution error for type {macro_type}: {e}")
            return False

        return False
