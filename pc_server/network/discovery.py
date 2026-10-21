"""
RemoteFlow Max - Zero-Config Local Network Discovery Service
Listens for discovery broadcasts from mobile clients and responds with server endpoint parameters.
Also broadcasts periodic beacon pulses over the subnet.
"""

import socket
import threading
import time
import json
import logging
from typing import Optional
from pc_server.config import (
    DISCOVERY_PORT,
    WS_PORT,
    UDP_PORT,
    HTTP_PORT,
    DISCOVERY_MAGIC_REQUEST,
    DISCOVERY_MAGIC_RESPONSE,
    BEACON_INTERVAL_SECONDS,
    SERVER_NAME
)
from pc_server.utils.net_utils import get_primary_local_ip

logger = logging.getLogger("RemoteFlow.Discovery")

class DiscoveryService(threading.Thread):
    def __init__(self, primary_ip: Optional[str] = None):
        super().__init__(name="DiscoveryServiceThread", daemon=True)
        self.primary_ip = primary_ip or get_primary_local_ip()
        self.running = False
        self.sock: Optional[socket.socket] = None

    def _build_payload(self) -> bytes:
        data = {
            "app": "RemoteFlowMax",
            "ip": self.primary_ip,
            "ws_port": WS_PORT,
            "udp_port": UDP_PORT,
            "http_port": HTTP_PORT,
            "name": SERVER_NAME
        }
        return f"{DISCOVERY_MAGIC_RESPONSE}:{json.dumps(data)}".encode("utf-8")

    def start_service(self):
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            self.sock.bind(("", DISCOVERY_PORT))
            self.sock.settimeout(1.0)
            self.running = True
            logger.info(f"[Discovery] Beacon service active on UDP port {DISCOVERY_PORT}")
            self.start()
        except Exception as e:
            logger.warning(f"[Discovery] Could not bind discovery socket: {e}")

    def run(self):
        last_beacon = 0.0
        payload = self._build_payload()

        while self.running:
            now = time.time()
            # Send periodic beacon pulse to broadcast
            if now - last_beacon >= BEACON_INTERVAL_SECONDS:
                try:
                    self.sock.sendto(payload, ("255.255.255.255", DISCOVERY_PORT))
                    last_beacon = now
                except Exception:
                    pass

            # Listen for discovery requests
            try:
                data, addr = self.sock.recvfrom(1024)
                if not data:
                    continue

                msg = data.decode("utf-8", errors="ignore").strip()
                if msg.startswith(DISCOVERY_MAGIC_REQUEST):
                    logger.debug(f"[Discovery] Received probe from {addr[0]}, replying...")
                    self.sock.sendto(payload, addr)
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    logger.debug(f"[Discovery] Error in loop: {e}")

    def stop(self):
        self.running = False
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
