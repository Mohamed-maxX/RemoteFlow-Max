"""
RemoteFlow Max - Core Network Protocol Specification
Defines standard packet structures, actions, and validation routines.
"""

import json
import time
from typing import Any, Dict, Optional

class PacketType:
    MOUSE = "mouse"
    KEYBOARD = "keyboard"
    SYSTEM = "system"
    HANDSHAKE = "handshake"
    AUDIO = "audio"
    MEDIA = "media"
    POWER = "power"
    CLIPBOARD = "clipboard"
    MACRO = "macro"
    PRESENTATION = "presentation"
    STREAM = "stream"
    GAMEPAD = "gamepad"
    SECURITY = "security"

class AudioAction:
    GET_STATE = "get_state"
    STATE = "state"
    SET_MASTER_VOLUME = "set_master_volume"
    TOGGLE_MASTER_MUTE = "toggle_master_mute"
    TOGGLE_MIC_MUTE = "toggle_mic_mute"
    SET_APP_VOLUME = "set_app_volume"
    TOGGLE_APP_MUTE = "toggle_app_mute"

class MediaAction:
    PLAY_PAUSE = "play_pause"
    NEXT = "next"
    PREV = "prev"
    STOP = "stop"

class PowerAction:
    LOCK = "lock"
    SLEEP = "sleep"
    SHUTDOWN = "shutdown"
    RESTART = "restart"
    CANCEL_SHUTDOWN = "cancel_shutdown"
    CAFFEINE = "caffeine"
    RAM_FLUSH = "ram_flush"
    BOSS_KEY = "boss_key"
    SET_PROFILE = "set_profile"
    WOL = "wol"

class ClipboardAction:
    SYNC = "sync"
    SET = "set"
    GET = "get"

class MacroAction:
    EXECUTE = "execute"
    GET_DECKS = "get_decks"
    DECKS = "decks"

class PresentationAction:
    ACTION = "action"
    TELEPROMPTER = "teleprompter"

class StreamAction:
    FRAME = "frame"
    START = "start"
    STOP = "stop"
    SCREENSHOT = "screenshot"

class GamepadAction:
    BUTTON = "button"
    STICK = "stick"

class SecurityAction:
    AUTH = "auth"
    AUTH_ACK = "auth_ack"
    AUTH_FAIL = "auth_fail"




class MouseAction:
    DELTA = "delta"
    CLICK = "click"
    DOWN = "down"
    UP = "up"
    SCROLL = "scroll"
    JOG = "jog"

class KeyboardAction:
    TEXT = "text"
    KEY = "key"
    HOTKEY = "hotkey"

class SystemAction:
    PING = "ping"
    PONG = "pong"
    TELEMETRY = "telemetry"
    SET_SENSITIVITY = "set_sensitivity"

class HandshakeAction:
    CONNECT = "connect"
    ACK = "ack"
    DISCONNECT = "disconnect"

def create_packet(packet_type: str, action: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Build a standard RemoteFlow Max JSON packet envelope."""
    return {
        "type": packet_type,
        "action": action,
        "payload": payload or {},
        "timestamp": int(time.time() * 1000)
    }

def serialize_packet(packet: Dict[str, Any]) -> str:
    """Serialize packet dictionary to JSON string."""
    return json.dumps(packet, separators=(',', ':'))

def parse_packet(raw_data: bytes | str) -> Optional[Dict[str, Any]]:
    """
    Parse and validate incoming packet bytes or JSON string.
    Returns None if malformed without throwing exceptions.
    """
    try:
        if isinstance(raw_data, (bytes, bytearray)):
            text = raw_data.decode("utf-8", errors="ignore").strip()
        else:
            text = raw_data.strip()

        if not text:
            return None

        # Check for fast-path compact delta: "d,dx,dy,mode"
        if text.startswith("d,"):
            parts = text.split(",")
            if len(parts) >= 3:
                dx = float(parts[1])
                dy = float(parts[2])
                mode = parts[3] if len(parts) > 3 else "normal"
                return {
                    "type": PacketType.MOUSE,
                    "action": MouseAction.DELTA,
                    "payload": {"dx": dx, "dy": dy, "mode": mode},
                    "timestamp": int(time.time() * 1000)
                }

        # Check for fast-path compact scroll: "s,dx,dy"
        if text.startswith("s,"):
            parts = text.split(",")
            if len(parts) >= 3:
                dx = float(parts[1])
                dy = float(parts[2])
                return {
                    "type": PacketType.MOUSE,
                    "action": MouseAction.SCROLL,
                    "payload": {"dx": dx, "dy": dy},
                    "timestamp": int(time.time() * 1000)
                }

        data = json.loads(text)
        if isinstance(data, dict) and "type" in data and "action" in data:
            if "payload" not in data:
                data["payload"] = {}
            if "timestamp" not in data:
                data["timestamp"] = int(time.time() * 1000)
            return data
    except Exception:
        pass
    return None
