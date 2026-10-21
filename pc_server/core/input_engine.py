"""
RemoteFlow Max - High-Performance Input Synthesis Engine
Combines direct Win32 SendInput/mouse_event for microsecond-level mouse delta dispatch
with pynput keyboard controller for robust Unicode and system key combinations.
"""

import sys
import time
import logging
from typing import List, Optional
from pc_server.core.acceleration import MouseAccelerationEngine

logger = logging.getLogger("RemoteFlow.InputEngine")

# Win32 Mouse Constants
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_HWHEEL = 0x1000

# Setup Win32 APIs if running on Windows
IS_WINDOWS = sys.platform == "win32"
user32 = None

if IS_WINDOWS:
    try:
        import ctypes
        user32 = ctypes.windll.user32
        # Ensure process is DPI-Aware so coordinates are 1:1 on HiDPI displays
        try:
            # DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
            user32.SetProcessDpiAwarenessContext(ctypes.c_void_p(-4))
        except Exception:
            try:
                user32.SetProcessDPIAware()
            except Exception:
                pass
    except Exception as e:
        logger.warning(f"Win32 direct API initialization failed: {e}")

# Import pynput as fallback and for keyboard controls
try:
    from pynput.keyboard import Controller as KeyboardController, Key
    from pynput.mouse import Controller as PynputMouseController, Button
    _pynput_mouse = PynputMouseController()
    _keyboard = KeyboardController()
except Exception as e:
    logger.error(f"Failed to initialize pynput: {e}")
    _pynput_mouse = None
    _keyboard = None

# Key map for special PC keys
SPECIAL_KEYS_MAP = {
    "enter": Key.enter if _keyboard else None,
    "return": Key.enter if _keyboard else None,
    "esc": Key.esc if _keyboard else None,
    "escape": Key.esc if _keyboard else None,
    "tab": Key.tab if _keyboard else None,
    "space": Key.space if _keyboard else None,
    "backspace": Key.backspace if _keyboard else None,
    "delete": Key.delete if _keyboard else None,
    "del": Key.delete if _keyboard else None,
    "up": Key.up if _keyboard else None,
    "down": Key.down if _keyboard else None,
    "left": Key.left if _keyboard else None,
    "right": Key.right if _keyboard else None,
    "home": Key.home if _keyboard else None,
    "end": Key.end if _keyboard else None,
    "page_up": Key.page_up if _keyboard else None,
    "page_down": Key.page_down if _keyboard else None,
    "ctrl": Key.ctrl if _keyboard else None,
    "control": Key.ctrl if _keyboard else None,
    "alt": Key.alt if _keyboard else None,
    "shift": Key.shift if _keyboard else None,
    "win": Key.cmd if _keyboard else None,
    "cmd": Key.cmd if _keyboard else None,
    "windows": Key.cmd if _keyboard else None,
    "caps_lock": Key.caps_lock if _keyboard else None,
    "f1": Key.f1 if _keyboard else None,
    "f2": Key.f2 if _keyboard else None,
    "f3": Key.f3 if _keyboard else None,
    "f4": Key.f4 if _keyboard else None,
    "f5": Key.f5 if _keyboard else None,
    "f6": Key.f6 if _keyboard else None,
    "f7": Key.f7 if _keyboard else None,
    "f8": Key.f8 if _keyboard else None,
    "f9": Key.f9 if _keyboard else None,
    "f10": Key.f10 if _keyboard else None,
    "f11": Key.f11 if _keyboard else None,
    "f12": Key.f12 if _keyboard else None,
}


class InputEngine:
    def __init__(self):
        self.accel = MouseAccelerationEngine()
        self.mouse_left_down = False
        self.mouse_right_down = False
        self.mouse_middle_down = False

    def get_screen_size(self) -> tuple[int, int]:
        if user32:
            return user32.GetSystemMetrics(0), user32.GetSystemMetrics(1)
        return (1920, 1080)

    def move_delta(self, raw_dx: float, raw_dy: float, mode: str = "normal"):
        """Ultra-low latency mouse displacement dispatch."""
        dx, dy = self.accel.process_delta(raw_dx, raw_dy, mode)
        if dx == 0 and dy == 0:
            return

        if user32:
            user32.mouse_event(MOUSEEVENTF_MOVE, dx, dy, 0, 0)
        elif _pynput_mouse:
            _pynput_mouse.move(dx, dy)

    def scroll(self, raw_dy: float, raw_dx: float = 0.0):
        """Dispatches vertical and horizontal scroll wheel events."""
        step_x, step_y = self.accel.process_scroll(raw_dy, raw_dx)
        if step_y != 0:
            if user32:
                user32.mouse_event(MOUSEEVENTF_WHEEL, 0, 0, step_y, 0)
            elif _pynput_mouse:
                _pynput_mouse.scroll(0, 1 if step_y > 0 else -1)

        if step_x != 0:
            if user32:
                user32.mouse_event(MOUSEEVENTF_HWHEEL, 0, 0, step_x, 0)
            elif _pynput_mouse:
                _pynput_mouse.scroll(1 if step_x > 0 else -1, 0)

    def click(self, button: str = "left", state: str = "click"):
        """
        Synthesizes mouse button events:
        state: 'click' (down then up), 'down', 'up', 'double'
        button: 'left', 'right', 'middle'
        """
        btn = button.lower()
        st = state.lower()

        if user32:
            if btn == "left":
                if st == "down":
                    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                    self.mouse_left_down = True
                elif st == "up":
                    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                    self.mouse_left_down = False
                elif st == "double":
                    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                    time.sleep(0.05)
                    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
                else:  # click
                    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
                    time.sleep(0.01)
                    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

            elif btn == "right":
                if st == "down":
                    user32.mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
                    self.mouse_right_down = True
                elif st == "up":
                    user32.mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)
                    self.mouse_right_down = False
                else:  # click
                    user32.mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0)
                    time.sleep(0.01)
                    user32.mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0)

            elif btn == "middle":
                if st == "down":
                    user32.mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0)
                    self.mouse_middle_down = True
                elif st == "up":
                    user32.mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0)
                    self.mouse_middle_down = False
                else:  # click
                    user32.mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0)
                    time.sleep(0.01)
                    user32.mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0)

        elif _pynput_mouse:
            target_btn = Button.left if btn == "left" else (Button.right if btn == "right" else Button.middle)
            if st == "down":
                _pynput_mouse.press(target_btn)
            elif st == "up":
                _pynput_mouse.release(target_btn)
            elif st == "double":
                _pynput_mouse.click(target_btn, 2)
            else:
                _pynput_mouse.click(target_btn, 1)

    def release_all_mouse_buttons(self):
        """Failsafe to ensure no mouse buttons remain held down if connection drops."""
        if self.mouse_left_down:
            self.click("left", "up")
        if self.mouse_right_down:
            self.click("right", "up")
        if self.mouse_middle_down:
            self.click("middle", "up")
        self.accel.reset_accumulator()

    def type_text(self, text: str):
        """Types Unicode text directly into the active host window."""
        if not _keyboard or not text:
            return
        _keyboard.type(text)

    def send_key(self, key_str: str, state: str = "press"):
        """
        Sends single key event (press, down, up).
        key_str can be character or named key ('enter', 'f5', 'esc', etc.).
        """
        if not _keyboard or not key_str:
            return

        key_lower = key_str.lower()
        key_obj = SPECIAL_KEYS_MAP.get(key_lower, key_str)

        try:
            if state == "down":
                _keyboard.press(key_obj)
            elif state == "up":
                _keyboard.release(key_obj)
            else:
                _keyboard.press(key_obj)
                time.sleep(0.01)
                _keyboard.release(key_obj)
        except Exception as e:
            logger.warning(f"Error sending key {key_str}: {e}")

    def send_hotkey(self, keys: List[str]):
        """
        Presses keys in sequence, then releases in reverse order (e.g., ['ctrl', 'c']).
        """
        if not _keyboard or not keys:
            return

        pressed = []
        try:
            for k in keys:
                key_obj = SPECIAL_KEYS_MAP.get(k.lower(), k)
                _keyboard.press(key_obj)
                pressed.append(key_obj)
            time.sleep(0.02)
        finally:
            for key_obj in reversed(pressed):
                try:
                    _keyboard.release(key_obj)
                except Exception:
                    pass
