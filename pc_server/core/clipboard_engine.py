"""
RemoteFlow Max - Bidirectional Clipboard Sync Engine
Monitors host PC clipboard changes and pushes to connected mobile clients.
Injects text copied on mobile directly into the host PC clipboard.
"""

import threading
import time
import logging
import pyperclip
from typing import Optional, Callable

logger = logging.getLogger("RemoteFlow.Clipboard")

class ClipboardEngine:
    def __init__(self, on_clipboard_changed: Optional[Callable[[str], None]] = None):
        self.on_clipboard_changed = on_clipboard_changed
        self._last_content = ""
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self.enabled = True

    def start_monitoring(self):
        """Starts background clipboard polling thread."""
        try:
            self._last_content = pyperclip.paste() or ""
        except Exception:
            self._last_content = ""

        self._running = True
        self._thread = threading.Thread(target=self._monitor_loop, name="ClipboardMonitorThread", daemon=True)
        self._thread.start()
        logger.info("[Clipboard] Host clipboard monitor active.")

    def _monitor_loop(self):
        while self._running:
            if self.enabled:
                try:
                    current = pyperclip.paste()
                    if current and current != self._last_content:
                        self._last_content = current
                        logger.info(f"[Clipboard] Host clipboard changed ({len(current)} chars). Syncing...")
                        if self.on_clipboard_changed:
                            self.on_clipboard_changed(current)
                except Exception as e:
                    logger.debug(f"[Clipboard] Poll warning: {e}")
            time.sleep(0.5)

    def set_clipboard(self, text: str):
        """Sets host PC clipboard content from mobile."""
        if not text:
            return
        try:
            self._last_content = text  # Prevent echo loop
            pyperclip.copy(text)
            logger.info(f"[Clipboard] Updated host clipboard from mobile ({len(text)} chars).")
        except Exception as e:
            logger.warning(f"[Clipboard] Error setting clipboard: {e}")

    def get_clipboard(self) -> str:
        """Returns current host clipboard text."""
        try:
            return pyperclip.paste() or ""
        except Exception:
            return ""

    def stop(self):
        self._running = False
