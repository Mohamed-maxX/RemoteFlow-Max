"""
RemoteFlow Max - Presentation Remote & Auto-Scroll Teleprompter Engine
Provides dedicated slide deck navigation and constant-speed programmatic teleprompter scrolling.
"""

import threading
import time
import logging
from typing import Optional
from pc_server.core.input_engine import InputEngine

logger = logging.getLogger("RemoteFlow.PresentationEngine")

class PresentationEngine:
    def __init__(self, input_engine: InputEngine):
        self.input_engine = input_engine
        
        # Teleprompter State
        self.teleprompter_active = False
        self.teleprompter_speed = 2.0  # units per tick
        self._teleprompter_thread: Optional[threading.Thread] = None

    def slide_action(self, action: str):
        """
        Dispatches presentation slide commands for PowerPoint, Keynote, Google Slides.
        action: 'next', 'prev', 'start', 'start_current', 'blackout', 'whiteout', 'exit'
        """
        act = action.lower()
        if act == "next":
            self.input_engine.send_key("right")
        elif act in ("prev", "previous"):
            self.input_engine.send_key("left")
        elif act == "start":
            self.input_engine.send_key("f5")
        elif act == "start_current":
            self.input_engine.send_hotkey(["shift", "f5"])
        elif act in ("blackout", "black"):
            self.input_engine.send_key("b")
        elif act in ("whiteout", "white"):
            self.input_engine.send_key("w")
        elif act in ("exit", "stop"):
            self.input_engine.send_key("esc")
        logger.debug(f"[Presentation] Dispatched slide action: {action}")

    def toggle_teleprompter(self, enable: Optional[bool] = None, speed: Optional[float] = None) -> bool:
        """Toggles or sets teleprompter continuous auto-scroll state."""
        if speed is not None:
            self.teleprompter_speed = max(0.5, min(15.0, float(speed)))

        if enable is not None:
            self.teleprompter_active = enable
        else:
            self.teleprompter_active = not self.teleprompter_active

        if self.teleprompter_active:
            if not self._teleprompter_thread or not self._teleprompter_thread.is_alive():
                self._teleprompter_thread = threading.Thread(
                    target=self._teleprompter_loop,
                    name="TeleprompterLoopThread",
                    daemon=True
                )
                self._teleprompter_thread.start()
                logger.info(f"[Teleprompter] Auto-scroll started (Speed: {self.teleprompter_speed})")
        else:
            logger.info("[Teleprompter] Auto-scroll stopped.")

        return self.teleprompter_active

    def _teleprompter_loop(self):
        while self.teleprompter_active:
            # Emit smooth downward scroll ticks
            # Negative dy scrolls down on Windows
            self.input_engine.scroll(-self.teleprompter_speed)
            time.sleep(0.08)  # ~12.5 ticks/second for fluid scrolling
