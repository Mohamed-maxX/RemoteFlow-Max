"""
RemoteFlow Max - PC Host Daemon Configuration
"""

import os
from pc_server.utils.config_manager import config_manager

# Network Ports (dynamically loaded from config.json with fallback defaults)
_ports = config_manager.get("ports", {})
HOST = "0.0.0.0"
UDP_PORT = _ports.get("udp_port", 5055)          # High-frequency low-overhead UDP listener (Trackpad, jog wheel)
WS_PORT = _ports.get("ws_port", 5056)            # Reliable bidirectional WebSocket server (Commands, keyboard, telemetry)
DISCOVERY_PORT = _ports.get("discovery_port", 5057) # UDP zero-config discovery beacon
HTTP_PORT = _ports.get("http_port", 5058)        # HTTP File transfer, uploads, and remote file browser API

# Network Protocols & Magic Strings
DISCOVERY_MAGIC_REQUEST = "REMOTEFLOW_DISCOVERY_REQ"
DISCOVERY_MAGIC_RESPONSE = "REMOTEFLOW_DISCOVERY_ACK"
BEACON_INTERVAL_SECONDS = 2.5

# Input Acceleration Defaults
DEFAULT_SENSITIVITY = 1.0
SNIPER_MULTIPLIER = 0.25
FAST_MULTIPLIER = 2.0
ACCELERATION_POWER = 1.25
ACCELERATION_COEFFICIENT = 0.04
SCROLL_MULTIPLIER = 24.0

# Server Metadata
SERVER_NAME = "RemoteFlow Max PC"
SERVER_VERSION = "1.0.0-phase1"
AUTH_ENABLED = False     # Prepared for Phase 4 PIN/Token pairing
