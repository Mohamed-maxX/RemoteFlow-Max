"""
RemoteFlow Max - Virtual Gamepad Engine
Translates mobile virtual D-Pad, ABXY, triggers, and dual analog joysticks into PC gaming inputs.
"""

import logging
from typing import Dict, Any, List
from pc_server.core.input_engine import InputEngine

logger = logging.getLogger("RemoteFlow.GamepadEngine")

# Standard gaming key mappings
DEFAULT_GAMEPAD_BINDINGS = {
    "a": "space",        # Jump
    "b": "c",            # Crouch
    "x": "r",            # Reload
    "y": "f",            # Interact
    "dpad_up": "up",
    "dpad_down": "down",
    "dpad_left": "left",
    "dpad_right": "right",
    "lb": "q",
    "rb": "e",
    "start": "esc",
    "select": "tab",
}

class GamepadEngine:
    def __init__(self, input_engine: InputEngine):
        self.input_engine = input_engine
        self.bindings = DEFAULT_GAMEPAD_BINDINGS.copy()
        self._held_keys = set()

    def process_button(self, button: str, state: str):
        """
        Processes gamepad button press/release.
        state: 'down', 'up', 'press'
        """
        btn = button.lower()
        if btn == "lt":  # Left trigger = Aim
            self.input_engine.click("right", "down" if state == "down" else "up")
            return
        elif btn == "rt":  # Right trigger = Fire
            self.input_engine.click("left", "down" if state == "down" else "up")
            return

        mapped_key = self.bindings.get(btn)
        if not mapped_key:
            return

        if state == "down":
            self.input_engine.send_key(mapped_key, "down")
            self._held_keys.add(mapped_key)
        elif state == "up":
            self.input_engine.send_key(mapped_key, "up")
            self._held_keys.discard(mapped_key)
        else:
            self.input_engine.send_key(mapped_key, "press")

    def process_joystick(self, stick: str, x: float, y: float):
        """
        Processes analog thumbstick (x, y between -1.0 and 1.0).
        stick: 'left' (WASD movement) or 'right' (Camera look)
        """
        if stick == "right":
            # Right stick -> Camera look (mouse delta dispatch)
            sensitivity = 12.0
            dx = x * sensitivity
            dy = y * sensitivity
            self.input_engine.move_delta(dx, dy, mode="fast")
        elif stick == "left":
            # Left stick -> WASD continuous keys
            deadzone = 0.25
            # W/S
            if y < -deadzone:
                self.input_engine.send_key("w", "down")
            elif y > deadzone:
                self.input_engine.send_key("s", "down")

            # A/D
            if x < -deadzone:
                self.input_engine.send_key("a", "down")
            elif x > deadzone:
                self.input_engine.send_key("d", "down")

    def release_all(self):
        """Releases all held keys."""
        for k in list(self._held_keys):
            try:
                self.input_engine.send_key(k, "up")
            except Exception:
                pass
        self._held_keys.clear()
