"""
RemoteFlow Max - Central Persistent Configuration Manager (config.json)
Provides thread-safe load/save of host settings, autostart state,
trusted devices (pairing persistence), network ports, and GUI preferences.
"""

import os
import sys
import json
import time
import logging
import threading
from typing import Any, Dict, List, Optional

logger = logging.getLogger("RemoteFlow.ConfigManager")

DEFAULT_CONFIG: Dict[str, Any] = {
    "version": "2.0.0",
    "autostart_with_windows": False,
    "trusted_devices": [],
    "ports": {
        "udp_port": 5055,
        "ws_port": 5056,
        "discovery_port": 5057,
        "http_port": 5058
    },
    "gui_settings": {
        "theme": "Dark",
        "minimize_to_tray_on_close": True,
        "window_geometry": "900x670"
    },
    "auth": {
        "pin_enabled": False,
        "saved_pin": ""
    }
}


class ConfigManager:
    _instance = None
    _lock = threading.Lock()

    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            with cls._lock:
                if not cls._instance:
                    cls._instance = super(ConfigManager, cls).__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self, config_path: Optional[str] = None):
        if getattr(self, "_initialized", False):
            return

        self._file_lock = threading.RLock()
        self.config_path = config_path or self._resolve_config_path()
        self.config_data: Dict[str, Any] = {}
        self.load()
        self._initialized = True

    @staticmethod
    def _resolve_config_path() -> str:
        """Determines location of config.json next to executable or workspace root."""
        if getattr(sys, "frozen", False):
            base_dir = os.path.dirname(sys.executable)
        else:
            base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            # Fallback check
            if not os.path.exists(base_dir) or not os.path.isdir(base_dir):
                base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

        return os.path.join(base_dir, "config.json")

    def load(self) -> Dict[str, Any]:
        """Loads configuration from config.json, or creates it with defaults if missing."""
        with self._file_lock:
            if os.path.exists(self.config_path):
                try:
                    with open(self.config_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    # Merge with defaults for any missing keys
                    self.config_data = self._merge_defaults(data, DEFAULT_CONFIG)
                    logger.info(f"[Config] Loaded configuration from {self.config_path}")
                    return self.config_data
                except Exception as e:
                    logger.error(f"[Config] Error reading {self.config_path}: {e}. Creating new default.")

            # Create default config file
            self.config_data = dict(DEFAULT_CONFIG)
            self.save()
            logger.info(f"[Config] Initialized default configuration at {self.config_path}")
            return self.config_data

    def _merge_defaults(self, data: dict, defaults: dict) -> dict:
        merged = dict(defaults)
        for k, v in data.items():
            if isinstance(v, dict) and k in merged and isinstance(merged[k], dict):
                merged[k] = self._merge_defaults(v, merged[k])
            else:
                merged[k] = v
        return merged

    def save(self) -> bool:
        """Atomically saves in-memory configuration to config.json."""
        with self._file_lock:
            try:
                temp_path = self.config_path + ".tmp"
                with open(temp_path, "w", encoding="utf-8") as f:
                    json.dump(self.config_data, f, indent=2, ensure_ascii=False)
                if os.path.exists(self.config_path):
                    os.replace(temp_path, self.config_path)
                else:
                    os.rename(temp_path, self.config_path)
                return True
            except Exception as e:
                logger.error(f"[Config] Failed to save config.json: {e}")
                return False

    def get(self, key: str, default: Any = None) -> Any:
        with self._file_lock:
            return self.config_data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        with self._file_lock:
            self.config_data[key] = value
            self.save()

    # -------------------------------------------------------------
    # Trusted Devices Management
    # -------------------------------------------------------------
    def add_trusted_device(self, device_id: str, device_name: str, ip: str = "") -> None:
        """Adds or updates a trusted paired client device."""
        if not device_id:
            device_id = f"dev_{ip.replace('.', '_')}"

        with self._file_lock:
            devices: List[dict] = self.config_data.get("trusted_devices", [])
            found = False
            for dev in devices:
                if dev.get("device_id") == device_id or (ip and dev.get("ip") == ip):
                    dev["device_id"] = device_id
                    dev["device_name"] = device_name or dev.get("device_name", "Remote Client")
                    dev["ip"] = ip
                    dev["last_connected"] = time.strftime("%Y-%m-%d %H:%M:%S")
                    found = True
                    break

            if not found:
                devices.append({
                    "device_id": device_id,
                    "device_name": device_name or "Remote Client",
                    "ip": ip,
                    "first_paired": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "last_connected": time.strftime("%Y-%m-%d %H:%M:%S")
                })

            self.config_data["trusted_devices"] = devices
            self.save()
            logger.info(f"[Config] Trusted device recorded: {device_name} (ID: {device_id}, IP: {ip})")

    def is_trusted_device(self, device_id: str, ip: str = "") -> bool:
        """Checks if a device ID or IP has already been paired and trusted."""
        with self._file_lock:
            devices = self.config_data.get("trusted_devices", [])
            for dev in devices:
                if device_id and dev.get("device_id") == device_id:
                    return True
                if ip and dev.get("ip") == ip:
                    return True
            return False

    def remove_trusted_device(self, device_id: str) -> None:
        with self._file_lock:
            devices = [d for d in self.config_data.get("trusted_devices", []) if d.get("device_id") != device_id]
            self.config_data["trusted_devices"] = devices
            self.save()

    def get_trusted_devices(self) -> List[dict]:
        with self._file_lock:
            return list(self.config_data.get("trusted_devices", []))

    # -------------------------------------------------------------
    # Autostart Synchronization
    # -------------------------------------------------------------
    def sync_autostart_with_registry(self) -> None:
        try:
            from pc_server.utils.autostart_utils import is_autostart_enabled
            enabled = is_autostart_enabled()
            if self.config_data.get("autostart_with_windows") != enabled:
                self.config_data["autostart_with_windows"] = enabled
                self.save()
        except Exception:
            pass


# Global singleton instance
config_manager = ConfigManager()
