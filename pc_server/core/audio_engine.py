"""
RemoteFlow Max - Windows Core Audio Management Engine
Provides per-app volume mixing, master volume control, global microphone kill-switch,
and media transport integration.
"""

import sys
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import List, Dict, Any, Optional

logger = logging.getLogger("RemoteFlow.AudioEngine")

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    try:
        import ctypes
        from ctypes import cast, POINTER
        import comtypes
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume, ISimpleAudioVolume
    except Exception as e:
        logger.warning(f"Failed to import pycaw / comtypes: {e}")
        IS_WINDOWS = False

# Win32 Virtual Key Codes for Media Transport
VK_MEDIA_NEXT_TRACK = 0xB0
VK_MEDIA_PREV_TRACK = 0xB1
VK_MEDIA_STOP = 0xB2
VK_MEDIA_PLAY_PAUSE = 0xB3
VK_VOLUME_MUTE = 0xAD
VK_VOLUME_DOWN = 0xAE
VK_VOLUME_UP = 0xAF

class AudioEngine:
    def __init__(self):
        self._initialized = IS_WINDOWS
        # Dedicated worker thread for isolated, non-blocking Windows Core Audio COM operations
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="AudioWorker")

    def _ensure_com_initialized(self):
        """Initializes COM for the calling thread if needed."""
        try:
            comtypes.CoInitialize()
        except Exception:
            try:
                ctypes.windll.ole32.CoInitialize(None)
            except Exception:
                pass

    def get_master_volume_info(self) -> Dict[str, Any]:
        """Returns master volume level (0.0 to 1.0) and mute status."""
        if not self._initialized:
            return {"volume": 0.5, "muted": False, "device_name": "Mock Output"}

        self._ensure_com_initialized()
        try:
            speakers = AudioUtilities.GetSpeakers()
            if not speakers or not speakers.EndpointVolume:
                return {"volume": 0.5, "muted": False, "device_name": "Default Audio"}

            vol = speakers.EndpointVolume
            scalar = float(vol.GetMasterVolumeLevelScalar())
            is_muted = bool(vol.GetMute())
            device_name = getattr(speakers, "FriendlyName", "Speakers")

            return {
                "volume": round(scalar, 3),
                "muted": is_muted,
                "device_name": device_name
            }
        except Exception as e:
            logger.warning(f"Error fetching master volume: {e}")
            return {"volume": 0.5, "muted": False, "device_name": "Default Audio"}

    def set_master_volume(self, level: float):
        """Sets master volume level (0.0 to 1.0)."""
        if not self._initialized:
            return
        self._ensure_com_initialized()
        try:
            speakers = AudioUtilities.GetSpeakers()
            if speakers and speakers.EndpointVolume:
                clamped = max(0.0, min(1.0, float(level)))
                speakers.EndpointVolume.SetMasterVolumeLevelScalar(clamped, None)
        except Exception as e:
            logger.warning(f"Error setting master volume: {e}")

    def toggle_master_mute(self) -> bool:
        """Toggles master volume mute and returns new state."""
        if not self._initialized:
            return False
        self._ensure_com_initialized()
        try:
            speakers = AudioUtilities.GetSpeakers()
            if speakers and speakers.EndpointVolume:
                current = bool(speakers.EndpointVolume.GetMute())
                new_state = not current
                speakers.EndpointVolume.SetMute(int(new_state), None)
                return new_state
        except Exception as e:
            logger.warning(f"Error toggling master mute: {e}")
        return False

    def get_microphone_info(self) -> Dict[str, Any]:
        """Returns default microphone mute status."""
        if not self._initialized:
            return {"muted": False, "device_name": "Mock Microphone"}

        self._ensure_com_initialized()
        try:
            mic = AudioUtilities.GetMicrophone()
            if not mic:
                return {"muted": False, "device_name": "Microphone"}

            # Activate IAudioEndpointVolume interface
            interface = mic.Activate(IAudioEndpointVolume._iid_, 7, None)
            vol = cast(interface, POINTER(IAudioEndpointVolume))
            is_muted = bool(vol.GetMute())
            scalar = float(vol.GetMasterVolumeLevelScalar())
            return {
                "muted": is_muted,
                "volume": round(scalar, 3),
                "device_name": "Default Microphone"
            }
        except Exception as e:
            logger.warning(f"Error fetching mic info: {e}")
            return {"muted": False, "device_name": "Microphone"}

    def set_microphone_mute(self, mute_state: bool) -> bool:
        """Sets microphone hardware mute state."""
        if not self._initialized:
            return mute_state
        self._ensure_com_initialized()
        try:
            mic = AudioUtilities.GetMicrophone()
            if mic:
                interface = mic.Activate(IAudioEndpointVolume._iid_, 7, None)
                vol = cast(interface, POINTER(IAudioEndpointVolume))
                vol.SetMute(int(mute_state), None)
                return mute_state
        except Exception as e:
            logger.warning(f"Error setting mic mute: {e}")
        return False

    def toggle_microphone_mute(self) -> bool:
        """Toggles microphone mute state."""
        info = self.get_microphone_info()
        new_state = not info.get("muted", False)
        return self.set_microphone_mute(new_state)

    def get_app_sessions(self) -> List[Dict[str, Any]]:
        """
        Enumerates all active Windows audio sessions (per-app volume sliders).
        Returns list of {name, pid, volume, muted, display_name}.
        """
        if not self._initialized:
            return []

        self._ensure_com_initialized()
        sessions_list = []
        try:
            sessions = AudioUtilities.GetAllSessions()
            for s in sessions:
                try:
                    vol = s.SimpleAudioVolume
                    if not vol:
                        continue

                    volume_level = float(vol.GetMasterVolume())
                    is_muted = bool(vol.GetMute())

                    name = "System Sounds"
                    pid = 0
                    if s.Process:
                        name = s.Process.name()
                        pid = s.Process.pid

                    # Friendly app label (strip .exe)
                    clean_name = name.replace(".exe", "").capitalize()
                    if clean_name == "Chrome":
                        clean_name = "Google Chrome"
                    elif clean_name == "Spotify":
                        clean_name = "Spotify"
                    elif clean_name == "Discord":
                        clean_name = "Discord"

                    sessions_list.append({
                        "name": clean_name,
                        "raw_name": name,
                        "pid": pid,
                        "volume": round(volume_level, 3),
                        "muted": is_muted
                    })
                except Exception:
                    continue
        except Exception as e:
            logger.warning(f"Error enumerating audio sessions: {e}")

        return sessions_list

    def set_app_volume(self, pid: int, raw_name: Optional[str], level: float):
        """Sets volume for specific application by PID or name."""
        if not self._initialized:
            return
        self._ensure_com_initialized()
        try:
            clamped = max(0.0, min(1.0, float(level)))
            sessions = AudioUtilities.GetAllSessions()
            for s in sessions:
                if (s.Process and s.Process.pid == pid) or (raw_name and s.Process and s.Process.name().lower() == raw_name.lower()):
                    s.SimpleAudioVolume.SetMasterVolume(clamped, None)
                    break
        except Exception as e:
            logger.warning(f"Error setting app volume for PID {pid}: {e}")

    def toggle_app_mute(self, pid: int, raw_name: Optional[str]) -> bool:
        """Toggles mute for specific application."""
        if not self._initialized:
            return False
        self._ensure_com_initialized()
        try:
            sessions = AudioUtilities.GetAllSessions()
            for s in sessions:
                if (s.Process and s.Process.pid == pid) or (raw_name and s.Process and s.Process.name().lower() == raw_name.lower()):
                    current = bool(s.SimpleAudioVolume.GetMute())
                    new_state = not current
                    s.SimpleAudioVolume.SetMute(int(new_state), None)
                    return new_state
        except Exception as e:
            logger.warning(f"Error toggling app mute: {e}")
        return False

    def media_action(self, action: str):
        """Dispatches global Windows media keys."""
        if not IS_WINDOWS:
            return

        act = action.lower()
        vk = None
        if act in ("play_pause", "play", "pause"):
            vk = VK_MEDIA_PLAY_PAUSE
        elif act in ("next", "next_track"):
            vk = VK_MEDIA_NEXT_TRACK
        elif act in ("prev", "prev_track", "previous"):
            vk = VK_MEDIA_PREV_TRACK
        elif act in ("stop",):
            vk = VK_MEDIA_STOP
        elif act in ("vol_up", "volume_up"):
            vk = VK_VOLUME_UP
        elif act in ("vol_down", "volume_down"):
            vk = VK_VOLUME_DOWN
        elif act in ("mute", "toggle_mute", "master_mute"):
            vk = VK_VOLUME_MUTE

        if vk is not None:
            user32 = ctypes.windll.user32
            user32.keybd_event(vk, 0, 0, 0)
            user32.keybd_event(vk, 0, 2, 0)  # KEYEVENTF_KEYUP

    # -------------------------------------------------------------
    # Async Thread-Safe Wrappers (Guarantees Core Audio never blocks WS loop)
    # -------------------------------------------------------------
    async def get_state_async(self) -> Dict[str, Any]:
        """Runs complete audio state capture inside the dedicated COM worker thread."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._executor, self._get_state_sync)

    def _get_state_sync(self) -> Dict[str, Any]:
        self._ensure_com_initialized()
        master = self.get_master_volume_info()
        mic = self.get_microphone_info()
        sessions = self.get_app_sessions()
        return {
            "master": master,
            "mic": mic,
            "sessions": sessions
        }

    async def set_master_volume_async(self, level: float):
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(self._executor, lambda: self.set_master_volume(level))

    async def toggle_master_mute_async(self) -> bool:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._executor, self.toggle_master_mute)

    async def toggle_microphone_mute_async(self) -> bool:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._executor, self.toggle_microphone_mute)

    async def set_app_volume_async(self, pid: int, raw_name: Optional[str], level: float):
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(self._executor, lambda: self.set_app_volume(pid, raw_name, level))

    async def toggle_app_mute_async(self, pid: int, raw_name: Optional[str]) -> bool:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(self._executor, lambda: self.toggle_app_mute(pid, raw_name))

    async def media_action_async(self, action: str):
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(self._executor, lambda: self.media_action(action))
