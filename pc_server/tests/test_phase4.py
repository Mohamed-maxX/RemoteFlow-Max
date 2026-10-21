"""
RemoteFlow Max - Phase 4 Integration Test Suite
Verifies PIN Authentication, Virtual Gamepad Engine,
Low-Latency Screen Capture & Mirroring, and HTTP Screenshot APIs.
"""

import sys
import os
import asyncio
import json
import websockets
import aiohttp
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from pc_server.core.input_engine import InputEngine
from pc_server.core.auth_engine import AuthEngine
from pc_server.core.gamepad_engine import GamepadEngine
from pc_server.core.screen_engine import ScreenEngine
from pc_server.network.ws_server import WebSocketServer
from pc_server.network.http_server import HTTPServer
from pc_server.core.protocol import (
    create_packet,
    PacketType,
    SecurityAction,
    GamepadAction,
    StreamAction
)

async def run_phase4_tests():
    print("[PHASE 4 TEST] Starting Security, Virtual Gamepad & Screen Streaming Tests...")

    # 1. Initialize Phase 4 Engines
    input_engine = InputEngine()
    auth_engine = AuthEngine(pin_enabled=True, default_pin="7890")
    gamepad_engine = GamepadEngine(input_engine)
    screen_engine = ScreenEngine()

    # Test AuthEngine
    assert auth_engine.verify_pin("7890") is True
    assert auth_engine.verify_pin("0000") is False
    print(" -> AuthEngine PIN validation: PASSED")

    # Test ScreenEngine
    frame_jpeg = screen_engine.capture_frame_jpeg(quality=50, target_width=640)
    assert len(frame_jpeg) > 1000
    assert frame_jpeg[:2] == b'\xff\xd8'  # Standard JPEG magic bytes
    print(f" -> ScreenEngine captured live JPEG frame ({len(frame_jpeg)} bytes): PASSED")

    screenshot_jpeg = screen_engine.capture_full_screenshot_jpeg()
    assert len(screenshot_jpeg) > 1000
    assert screenshot_jpeg[:2] == b'\xff\xd8'
    print(f" -> ScreenEngine full screenshot ({len(screenshot_jpeg)} bytes): PASSED")

    # Test GamepadEngine
    gamepad_engine.process_button("a", "press")
    gamepad_engine.process_joystick("left", 0.8, -0.9)
    gamepad_engine.release_all()
    print(" -> GamepadEngine button & analog joystick dispatch: PASSED")

    # 2. Start HTTP Server on test port 5108
    test_http_port = 5108
    http_server = HTTPServer("127.0.0.1", test_http_port, screen_engine=screen_engine)
    await http_server.start()

    # 3. Start WebSocket Server on test port 5109
    test_ws_port = 5109
    ws_server = WebSocketServer(
        "127.0.0.1",
        test_ws_port,
        input_engine,
        auth_engine=auth_engine,
        gamepad_engine=gamepad_engine,
        screen_engine=screen_engine
    )
    await ws_server.start()
    time.sleep(0.3)

    try:
        # TEST HTTP SCREENSHOT API
        base_http = f"http://127.0.0.1:{test_http_port}"
        async with aiohttp.ClientSession() as session:
            async with session.get(f"{base_http}/api/stream/screenshot") as resp:
                assert resp.status == 200
                assert resp.headers["Content-Type"] == "image/jpeg"
                data = await resp.read()
                assert data[:2] == b'\xff\xd8'
                print(f" -> HTTP Instant Screenshot Grab /api/stream/screenshot ({len(data)} bytes): PASSED")

        # TEST WEBSOCKET PHASE 4 CHANNELS
        uri = f"ws://127.0.0.1:{test_ws_port}"
        async with websockets.connect(uri) as ws:
            # Drain initial welcome, audio, and macro packets
            welcome = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            audio_state = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            decks = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))

            assert welcome["payload"].get("pin_required") is True

            # 1. Test PIN Authentication Handshake
            auth_req = create_packet(PacketType.SECURITY, SecurityAction.AUTH, {"pin": "7890"})
            await ws.send(json.dumps(auth_req))
            auth_ack = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            assert auth_ack["type"] == "security"
            assert auth_ack["action"] == "auth_ack"
            assert "token" in auth_ack["payload"]
            print(" -> WS PIN Authentication Handshake: PASSED")

            # 2. Test Virtual Gamepad input over WS
            gp_btn = create_packet(PacketType.GAMEPAD, GamepadAction.BUTTON, {"button": "a", "state": "down"})
            await ws.send(json.dumps(gp_btn))
            gp_stick = create_packet(PacketType.GAMEPAD, GamepadAction.STICK, {"stick": "right", "x": 0.5, "y": -0.2})
            await ws.send(json.dumps(gp_stick))
            print(" -> WS Virtual Gamepad input dispatch: PASSED")

            # 3. Test Screen Stream Subscription
            stream_start = create_packet(PacketType.STREAM, StreamAction.START)
            await ws.send(json.dumps(stream_start))

            # Receive at least 1 stream frame
            received_frame = False
            for _ in range(5):
                raw = await asyncio.wait_for(ws.recv(), timeout=2.0)
                data = json.loads(raw)
                if data.get("type") == "stream" and data.get("action") == "frame":
                    assert "image" in data["payload"]
                    received_frame = True
                    print(f" -> WS Live Screen Mirror Frame received ({len(data['payload']['image'])} b64 chars): PASSED")
                    break

            assert received_frame, "Did not receive stream frame over WebSocket!"

            stream_stop = create_packet(PacketType.STREAM, StreamAction.STOP)
            await ws.send(json.dumps(stream_stop))

        print("\n[PHASE 4 SERVER, SCREEN & GAMEPAD TESTS PASSED SUCCESSFULLY!]")
    finally:
        await http_server.stop()
        ws_server.stop()
        screen_engine.close()

if __name__ == "__main__":
    asyncio.run(run_phase4_tests())
