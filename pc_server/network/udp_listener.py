"""
RemoteFlow Max - High-Frequency UDP Listener
Dedicated low-overhead socket loop for real-time trackpad deltas, gestures, and jog wheel.
"""

import socket
import threading
import logging
import time
from typing import Optional
from pc_server.core.protocol import parse_packet, PacketType, MouseAction
from pc_server.core.input_engine import InputEngine

logger = logging.getLogger("RemoteFlow.UDPListener")

class UDPListener(threading.Thread):
    def __init__(self, host: str, port: int, input_engine: InputEngine):
        super().__init__(name="UDPListenerThread", daemon=True)
        self.host = host
        self.port = port
        self.input_engine = input_engine
        self.sock: Optional[socket.socket] = None
        self.running = False
        
        # Telemetry stats
        self.packet_count = 0
        self.last_stat_time = time.time()
        self.packets_per_sec = 0.0

    def start_listener(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Increase receive buffer to avoid dropping packets during rapid finger swipes
        try:
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65536)
        except Exception:
            pass
        self.sock.bind((self.host, self.port))
        self.sock.settimeout(0.5)
        self.running = True
        logger.info(f"[UDP] Listening for high-frequency input on {self.host}:{self.port}")
        self.start()

    def run(self):
        while self.running:
            try:
                data, addr = self.sock.recvfrom(2048)
                if not data:
                    continue

                self.packet_count += 1
                pkt = parse_packet(data)
                if not pkt:
                    continue

                p_type = pkt.get("type")
                action = pkt.get("action")
                payload = pkt.get("payload", {})

                if p_type == PacketType.MOUSE:
                    if action == MouseAction.DELTA:
                        dx = float(payload.get("dx", 0.0))
                        dy = float(payload.get("dy", 0.0))
                        mode = payload.get("mode", "normal")
                        self.input_engine.move_delta(dx, dy, mode)

                    elif action == MouseAction.SCROLL:
                        dy = float(payload.get("dy", 0.0))
                        dx = float(payload.get("dx", 0.0))
                        self.input_engine.scroll(dy, dx)

                    elif action == MouseAction.CLICK:
                        btn = payload.get("button", "left")
                        state = payload.get("state", "click")
                        self.input_engine.click(btn, state)

                    elif action == MouseAction.DOWN:
                        btn = payload.get("button", "left")
                        self.input_engine.click(btn, "down")

                    elif action == MouseAction.UP:
                        btn = payload.get("button", "left")
                        self.input_engine.click(btn, "up")

                    elif action == MouseAction.JOG:
                        delta = float(payload.get("delta", 0.0))
                        self.input_engine.scroll(delta)

                # Periodic stat measurement (every 2 seconds)
                now = time.time()
                elapsed = now - self.last_stat_time
                if elapsed >= 2.0:
                    self.packets_per_sec = self.packet_count / elapsed
                    self.packet_count = 0
                    self.last_stat_time = now

            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    logger.debug(f"[UDP] Socket read warning: {e}")

        logger.info("[UDP] Listener thread stopped.")

    def stop(self):
        self.running = False
        if self.sock:
            try:
                self.sock.close()
            except Exception:
                pass
