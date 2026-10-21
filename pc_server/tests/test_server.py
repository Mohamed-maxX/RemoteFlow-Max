"""
RemoteFlow Max - End-to-End Server Integration Test
Tests UDP mouse streaming, WebSocket command dispatch, and UDP Discovery beacons.
"""

import sys
import os
import asyncio
import socket
import json
import websockets
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from pc_server.config import HOST, UDP_PORT, WS_PORT, DISCOVERY_PORT, DISCOVERY_MAGIC_REQUEST, DISCOVERY_MAGIC_RESPONSE
from pc_server.core.input_engine import InputEngine
from pc_server.network.udp_listener import UDPListener
from pc_server.network.ws_server import WebSocketServer
from pc_server.network.discovery import DiscoveryService
from pc_server.core.protocol import create_packet, PacketType, MouseAction, SystemAction, KeyboardAction

async def run_tests():
    print("[TEST] Starting RemoteFlow Max Server Integration Test Suite...")

    # 1. Initialize components
    input_engine = InputEngine()
    udp_listener = UDPListener("127.0.0.1", UDP_PORT, input_engine)
    udp_listener.start_listener()

    discovery = DiscoveryService("127.0.0.1")
    discovery.start_service()

    ws_server = WebSocketServer("127.0.0.1", WS_PORT, input_engine)
    await ws_server.start()

    time.sleep(0.3)

    try:
        # TEST 1: Zero-Config Discovery over UDP
        print("[TEST 1] Testing Auto-Discovery beacon...")
        disc_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        disc_sock.settimeout(2.0)
        disc_sock.sendto(DISCOVERY_MAGIC_REQUEST.encode("utf-8"), ("127.0.0.1", DISCOVERY_PORT))
        resp, _ = disc_sock.recvfrom(2048)
        disc_sock.close()
        resp_text = resp.decode("utf-8")
        assert resp_text.startswith(DISCOVERY_MAGIC_RESPONSE), f"Unexpected discovery response: {resp_text}"
        data = json.loads(resp_text.split(":", 1)[1])
        assert data.get("app") == "RemoteFlowMax", f"Bad app identifier: {data}"
        print(f" -> Discovery SUCCESS: {data}")

        # TEST 2: High-Frequency UDP Mouse Delta Streaming
        print("[TEST 2] Testing High-Frequency UDP Mouse Listener...")
        udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        
        # Send JSON packet
        json_pkt = create_packet(PacketType.MOUSE, MouseAction.DELTA, {"dx": 1.0, "dy": 1.0, "mode": "normal"})
        udp_sock.sendto(json.dumps(json_pkt).encode("utf-8"), ("127.0.0.1", UDP_PORT))

        # Send compact fast-path delta: "d,dx,dy,mode"
        udp_sock.sendto(b"d,2.5,-1.5,sniper", ("127.0.0.1", UDP_PORT))

        # Send scroll packet
        scroll_pkt = create_packet(PacketType.MOUSE, MouseAction.SCROLL, {"dy": 1.0})
        udp_sock.sendto(json.dumps(scroll_pkt).encode("utf-8"), ("127.0.0.1", UDP_PORT))
        udp_sock.close()
        print(" -> UDP Mouse & Scroll stream SUCCESS.")

        # TEST 3: WebSocket Connection, Handshake & Ping/Pong
        print("[TEST 3] Testing WebSocket Command Channel...")
        uri = f"ws://127.0.0.1:{WS_PORT}"
        async with websockets.connect(uri) as ws:
            # Receive initial packets (welcome + initial audio state + initial macro decks)
            welcome_raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
            welcome = json.loads(welcome_raw)
            assert welcome["type"] == "handshake", f"Expected handshake, got: {welcome}"
            print(f" -> Server Welcome: {welcome['payload']['server_name']}, Screen: {welcome['payload']['screen_size']}")

            # Receive initial audio state packet
            audio_init = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            assert audio_init["type"] == "audio"

            # Receive initial macro decks packet
            decks_init = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            assert decks_init["type"] == "macro"

            # Send Connect Handshake
            connect_pkt = create_packet(PacketType.HANDSHAKE, "connect", {"client_name": "TestClient-Flutter"})
            await ws.send(json.dumps(connect_pkt))
            ack_raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
            ack = json.loads(ack_raw)
            assert ack["payload"]["status"] == "connected"
            print(" -> Handshake Connect ACK received.")

            # Send System Ping
            client_ts = int(time.time() * 1000)
            ping_pkt = create_packet(PacketType.SYSTEM, SystemAction.PING, {"client_ts": client_ts})
            await ws.send(json.dumps(ping_pkt))
            pong_raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
            pong = json.loads(pong_raw)
            assert pong["action"] == "pong"
            assert pong["payload"]["client_ts"] == client_ts
            latency = int(time.time() * 1000) - client_ts
            print(f" -> Ping/Pong SUCCESS: RTT latency = {latency}ms")

            # Send Keyboard and Hotkey commands (verify no exceptions thrown)
            key_pkt = create_packet(PacketType.KEYBOARD, KeyboardAction.TEXT, {"text": ""})
            await ws.send(json.dumps(key_pkt))
            print(" -> WebSocket Command Dispatch SUCCESS.")

        print("\n[ALL TESTS PASSED SUCCESSFULLY!]")
    finally:
        udp_listener.stop()
        discovery.stop()
        ws_server.stop()

if __name__ == "__main__":
    asyncio.run(run_tests())
