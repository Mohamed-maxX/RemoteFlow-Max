"""
RemoteFlow Max - Server-Driven Live UI & OTA File Watcher Manager
Monitors live_ui_config.json and RemoteFlowMax.apk for instant WebSocket hot-reload broadcasting.
"""

import os
import sys
import json
import time
import hashlib
import logging
import threading
from typing import Dict, Any, Optional, Callable

logger = logging.getLogger("RemoteFlow.LiveUI")


class LiveUIManager:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            with cls._lock:
                if not cls._instance:
                    cls._instance = super(LiveUIManager, cls).__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self, workspace_dir: Optional[str] = None):
        if getattr(self, "_initialized", False):
            return

        self.workspace_dir = workspace_dir or self._resolve_workspace()
        self.config_path = os.path.join(self.workspace_dir, "live_ui_config.json")
        self.apk_path = os.path.join(self.workspace_dir, "RemoteFlowMax.apk")

        self._file_lock = threading.RLock()
        self._watcher_thread: Optional[threading.Thread] = None
        self._running = False
        self._on_ui_update_cb: Optional[Callable[[dict], None]] = None
        self._on_apk_update_cb: Optional[Callable[[dict], None]] = None

        self._last_ui_mtime = 0.0
        self._last_apk_mtime = 0.0
        self._last_apk_hash = ""

        self._cached_config: Dict[str, Any] = {}
        self.load_config()
        self._initialized = True

    @staticmethod
    def _resolve_workspace() -> str:
        if getattr(sys, 'frozen', False):
            return os.path.dirname(sys.executable)
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        if os.path.exists(os.path.join(base, "RemoteFlowMax.apk")) or os.path.exists(os.path.join(base, "config.json")):
            return base
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    def load_config(self) -> Dict[str, Any]:
        with self._file_lock:
            if os.path.exists(self.config_path):
                try:
                    with open(self.config_path, "r", encoding="utf-8") as f:
                        self._cached_config = json.load(f)
                    self._last_ui_mtime = os.path.getmtime(self.config_path)
                    return self._cached_config
                except Exception as e:
                    logger.warning(f"[LiveUI] Error reading {self.config_path}: {e}")
            return self._cached_config

    def save_config(self, new_config: dict) -> bool:
        with self._file_lock:
            try:
                new_config["last_updated"] = time.strftime("%Y-%m-%d %H:%M:%S")
                temp_p = self.config_path + ".tmp"
                with open(temp_p, "w", encoding="utf-8") as f:
                    json.dump(new_config, f, indent=2, ensure_ascii=False)
                if os.path.exists(self.config_path):
                    os.replace(temp_p, self.config_path)
                else:
                    os.rename(temp_p, self.config_path)
                self._cached_config = new_config
                self._last_ui_mtime = os.path.getmtime(self.config_path)
                return True
            except Exception as e:
                logger.error(f"[LiveUI] Failed writing live config: {e}")
                return False

    def get_apk_metadata(self) -> Dict[str, Any]:
        if os.path.exists(self.apk_path):
            size = os.path.getsize(self.apk_path)
            mtime = int(os.path.getmtime(self.apk_path) * 1000)
            return {
                "available": True,
                "path": self.apk_path,
                "size": size,
                "size_mb": round(size / (1024 * 1024), 2),
                "timestamp": mtime,
                "hash": self._calc_apk_hash_quick()
            }
        return {"available": False, "size": 0, "timestamp": 0, "hash": ""}

    def _calc_apk_hash_quick(self) -> str:
        try:
            if not os.path.exists(self.apk_path):
                return ""
            h = hashlib.md5()
            with open(self.apk_path, "rb") as f:
                # Read head and tail 64KB for instant check
                h.update(f.read(65536))
                f.seek(max(0, os.path.getsize(self.apk_path) - 65536))
                h.update(f.read(65536))
            return h.hexdigest()
        except Exception:
            return ""

    def start_watcher(
        self,
        on_ui_update: Optional[Callable[[dict], None]] = None,
        on_apk_update: Optional[Callable[[dict], None]] = None
    ):
        self._on_ui_update_cb = on_ui_update
        self._on_apk_update_cb = on_apk_update

        if os.path.exists(self.config_path):
            self._last_ui_mtime = os.path.getmtime(self.config_path)
        if os.path.exists(self.apk_path):
            self._last_apk_mtime = os.path.getmtime(self.apk_path)
            self._last_apk_hash = self._calc_apk_hash_quick()

        self._running = True
        self._watcher_thread = threading.Thread(
            target=self._watch_loop,
            daemon=True,
            name="LiveUIFileWatcher"
        )
        self._watcher_thread.start()
        logger.info(f"[LiveUI] Watcher active on {self.config_path} & {self.apk_path}")

    def _watch_loop(self):
        while self._running:
            time.sleep(1.0)
            try:
                # 1. Check live_ui_config.json
                if os.path.exists(self.config_path):
                    curr_mtime = os.path.getmtime(self.config_path)
                    if curr_mtime > self._last_ui_mtime + 0.1:
                        time.sleep(0.1)  # Buffer write flush
                        self._last_ui_mtime = os.path.getmtime(self.config_path)
                        conf = self.load_config()
                        logger.info(f"[LiveUI] Detected modification in {self.config_path}. Broadcasting...")
                        if self._on_ui_update_cb:
                            self._on_ui_update_cb(conf)

                # 2. Check RemoteFlowMax.apk
                if os.path.exists(self.apk_path):
                    curr_apk_mtime = os.path.getmtime(self.apk_path)
                    if curr_apk_mtime > self._last_apk_mtime + 0.5:
                        time.sleep(0.5)  # Buffer file copy
                        curr_hash = self._calc_apk_hash_quick()
                        if curr_hash != self._last_apk_hash:
                            self._last_apk_mtime = os.path.getmtime(self.apk_path)
                            self._last_apk_hash = curr_hash
                            meta = self.get_apk_metadata()
                            logger.info(f"[LiveUI] Detected new APK build ({meta['size_mb']} MB). Broadcasting OTA event...")
                            if self._on_apk_update_cb:
                                self._on_apk_update_cb(meta)

            except Exception as e:
                logger.debug(f"[LiveUI] Watcher cycle exception: {e}")

    def stop_watcher(self):
        self._running = False


# Global singleton instance
live_ui_manager = LiveUIManager()
