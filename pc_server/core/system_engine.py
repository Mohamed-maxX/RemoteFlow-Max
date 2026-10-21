"""
RemoteFlow Max - System Telemetry, Power & Performance Engine
Provides real-time hardware telemetry streaming, instant RAM flush, Keep-Awake (Caffeine),
remote power actions, and Boss Key panic sequence.
"""

import sys
import time
import os
import subprocess
import socket
import logging
import psutil
from typing import Dict, Any, Optional

logger = logging.getLogger("RemoteFlow.SystemEngine")

IS_WINDOWS = sys.platform == "win32"

if IS_WINDOWS:
    import ctypes
    kernel32 = ctypes.windll.kernel32
    user32 = ctypes.windll.user32
    psapi = getattr(ctypes.windll, "psapi", None)
    powrprof = getattr(ctypes.windll, "PowrProf", None)
else:
    kernel32 = None
    user32 = None
    psapi = None
    powrprof = None

# Thread Execution State Flags (Caffeine / Keep-Awake)
ES_CONTINUOUS = 0x80000000
ES_SYSTEM_REQUIRED = 0x00000001
ES_DISPLAY_REQUIRED = 0x00000002

# Power Scheme GUIDs
POWER_SCHEMES = {
    "balanced": "381b4222-f694-41f0-9685-ff5bb260df2e",
    "high_performance": "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
    "power_saver": "a1841308-3541-4fab-bc81-f71556f20b4a",
}

class SystemEngine:
    def __init__(self):
        self.caffeine_active = False
        self._last_net_io = psutil.net_io_counters()
        self._last_net_time = time.time()
        self._boot_time = psutil.boot_time()

    def get_telemetry(self) -> Dict[str, Any]:
        """Gathers real-time performance and system health metrics."""
        now = time.time()
        elapsed_net = max(0.1, now - self._last_net_time)

        # CPU
        cpu_pct = psutil.cpu_percent(interval=None)
        per_core = psutil.cpu_percent(interval=None, percpu=True)

        # RAM
        vmem = psutil.virtual_memory()
        ram_total_gb = round(vmem.total / (1024 ** 3), 1)
        ram_used_gb = round(vmem.used / (1024 ** 3), 1)
        ram_pct = vmem.percent

        # Disk (Primary Drive)
        try:
            primary_drive = "C:\\" if IS_WINDOWS else "/"
            disk = psutil.disk_usage(primary_drive)
            disk_total_gb = round(disk.total / (1024 ** 3), 1)
            disk_used_gb = round(disk.used / (1024 ** 3), 1)
            disk_pct = disk.percent
        except Exception:
            disk_total_gb, disk_used_gb, disk_pct = 0, 0, 0

        # Network Bandwidth (Upload/Download in KB/s)
        try:
            curr_net_io = psutil.net_io_counters()
            bytes_sent_delta = curr_net_io.bytes_sent - self._last_net_io.bytes_sent
            bytes_recv_delta = curr_net_io.bytes_recv - self._last_net_io.bytes_recv
            upload_kbps = round((bytes_sent_delta / elapsed_net) / 1024.0, 1)
            download_kbps = round((bytes_recv_delta / elapsed_net) / 1024.0, 1)

            self._last_net_io = curr_net_io
            self._last_net_time = now
        except Exception:
            upload_kbps, download_kbps = 0.0, 0.0

        # Battery (if available)
        battery_pct = None
        is_charging = False
        try:
            batt = psutil.sensors_battery()
            if batt:
                battery_pct = batt.percent
                is_charging = batt.power_plugged
        except Exception:
            pass

        uptime_sec = int(now - self._boot_time)

        return {
            "cpu_percent": cpu_pct,
            "cpu_cores": per_core,
            "ram_percent": ram_pct,
            "ram_used_gb": ram_used_gb,
            "ram_total_gb": ram_total_gb,
            "disk_percent": disk_pct,
            "disk_used_gb": disk_used_gb,
            "disk_total_gb": disk_total_gb,
            "upload_kbps": upload_kbps,
            "download_kbps": download_kbps,
            "battery_percent": battery_pct,
            "is_charging": is_charging,
            "uptime_seconds": uptime_sec,
            "caffeine": self.caffeine_active,
            "timestamp": int(now * 1000)
        }

    def set_caffeine(self, enable: bool) -> bool:
        """Toggles Windows thread execution state to prevent sleep/screensaver."""
        if not IS_WINDOWS or not kernel32:
            self.caffeine_active = enable
            return self.caffeine_active

        try:
            if enable:
                kernel32.SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)
                self.caffeine_active = True
                logger.info("[System] Keep-Awake / Caffeine ENABLED.")
            else:
                kernel32.SetThreadExecutionState(ES_CONTINUOUS)
                self.caffeine_active = False
                logger.info("[System] Keep-Awake / Caffeine DISABLED.")
        except Exception as e:
            logger.warning(f"Error toggling caffeine: {e}")

        return self.caffeine_active

    def flush_ram(self) -> Dict[str, Any]:
        """
        Instant RAM Flush: Trims working sets of running processes via EmptyWorkingSet.
        """
        initial_pct = psutil.virtual_memory().percent
        initial_used_mb = psutil.virtual_memory().used / (1024 * 1024)

        trimmed_count = 0
        if IS_WINDOWS and kernel32 and psapi:
            PROCESS_SET_QUOTA = 0x0100
            PROCESS_QUERY_INFORMATION = 0x0400

            for proc in psutil.process_iter(['pid']):
                try:
                    pid = proc.info['pid']
                    if pid <= 4:
                        continue
                    h_proc = kernel32.OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_INFORMATION, False, pid)
                    if h_proc:
                        if psapi.EmptyWorkingSet(h_proc):
                            trimmed_count += 1
                        kernel32.CloseHandle(h_proc)
                except Exception:
                    pass

        new_vmem = psutil.virtual_memory()
        new_pct = new_vmem.percent
        new_used_mb = new_vmem.used / (1024 * 1024)
        freed_mb = max(0, round(initial_used_mb - new_used_mb, 1))

        logger.info(f"[System] RAM Flush: Trimmed {trimmed_count} processes. Freed: {freed_mb}MB ({initial_pct}% -> {new_pct}%)")

        return {
            "initial_percent": initial_pct,
            "new_percent": new_pct,
            "freed_mb": freed_mb,
            "processes_trimmed": trimmed_count
        }

    def lock_workstation(self):
        """Locks workstation (equivalent to Win + L)."""
        if IS_WINDOWS and user32:
            user32.LockWorkStation()
            logger.info("[System] Workstation Locked.")

    def sleep_system(self):
        """Puts PC to sleep."""
        if IS_WINDOWS and powrprof:
            powrprof.SetSuspendState(0, 1, 0)
            logger.info("[System] System sleep triggered.")

    def shutdown_system(self, timer_seconds: int = 0):
        """Schedules or triggers immediate system shutdown."""
        if IS_WINDOWS:
            cmd = f"shutdown /s /t {int(timer_seconds)}"
            subprocess.run(cmd, shell=True)
            logger.info(f"[System] Shutdown scheduled in {timer_seconds}s.")

    def restart_system(self, timer_seconds: int = 0):
        """Schedules or triggers immediate system restart."""
        if IS_WINDOWS:
            cmd = f"shutdown /r /t {int(timer_seconds)}"
            subprocess.run(cmd, shell=True)
            logger.info(f"[System] Restart scheduled in {timer_seconds}s.")

    def cancel_shutdown(self):
        """Cancels any pending shutdown timer."""
        if IS_WINDOWS:
            subprocess.run("shutdown /a", shell=True)
            logger.info("[System] Pending shutdown aborted.")

    def set_power_profile(self, profile: str) -> bool:
        """Switches Windows power scheme (balanced, high_performance, power_saver)."""
        if not IS_WINDOWS:
            return False

        guid = POWER_SCHEMES.get(profile.lower())
        if not guid:
            return False

        try:
            subprocess.run(f"powercfg /setactive {guid}", shell=True, check=True)
            logger.info(f"[System] Switched to power scheme: {profile}")
            return True
        except Exception as e:
            logger.warning(f"Error setting power profile: {e}")
            return False

    def boss_key(self, audio_engine=None):
        """
        Boss Key / Panic Sequence:
        1. Minimizes all open windows (Win + D)
        2. Mutes Master Volume
        3. Mutes Hardware Microphone
        """
        if IS_WINDOWS and user32:
            # Win + D
            user32.keybd_event(0x5B, 0, 0, 0)  # Win down
            user32.keybd_event(0x44, 0, 0, 0)  # D down
            time.sleep(0.01)
            user32.keybd_event(0x44, 0, 2, 0)  # D up
            user32.keybd_event(0x5B, 0, 2, 0)  # Win up

        if audio_engine:
            audio_engine.set_master_volume(0.0)
            audio_engine.set_microphone_mute(True)

        logger.info("[System] Boss Key Panic triggered! Windows minimized, audio & mic muted.")

    @staticmethod
    def send_wake_on_lan(mac_address: str, broadcast_ip: str = "255.255.255.255", port: int = 9):
        """Broadcasts magic packet to wake target PC on local network."""
        clean_mac = mac_address.replace(":", "").replace("-", "").replace(".", "")
        if len(clean_mac) != 12:
            raise ValueError("Invalid MAC address length")

        mac_bytes = bytes.fromhex(clean_mac)
        magic_packet = b'\xFF' * 6 + (mac_bytes * 16)

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic_packet, (broadcast_ip, port))
        sock.close()
        logger.info(f"[System] Wake-on-LAN magic packet sent to {mac_address}")
