"""
RemoteFlow Max - Phase 3 Integration Test Suite
Verifies Shared Clipboard Sync, Virtual Stream Deck Macro Engine,
Presentation Remote & Teleprompter, and HTTP File Explorer & Upload API.
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
from pc_server.core.clipboard_engine import ClipboardEngine
from pc_server.core.macro_engine import MacroEngine
from pc_server.core.presentation_engine import PresentationEngine
from pc_server.network.ws_server import WebSocketServer
from pc_server.network.http_server import HTTPServer
from pc_server.core.protocol import (
    create_packet,
    PacketType,
    ClipboardAction,
    MacroAction,
    PresentationAction
)

async def run_phase3_tests():
    print("[PHASE 3 TEST] Starting Productivity, Stream Deck & File Server Tests...")

    # 1. Initialize Engines
    input_engine = InputEngine()
    clipboard_engine = ClipboardEngine()
    macro_engine = MacroEngine(input_engine)
    presentation_engine = PresentationEngine(input_engine)

    # Test ClipboardEngine
    clipboard_engine.set_clipboard("RemoteFlowMax_Test_Payload_42")
    assert clipboard_engine.get_clipboard() == "RemoteFlowMax_Test_Payload_42"
    print(" -> ClipboardEngine set/get: PASSED")

    # Test MacroEngine
    decks = macro_engine.get_decks()
    assert len(decks) >= 3, f"Expected at least 3 default decks, got {len(decks)}"
    print(f" -> MacroEngine loaded {len(decks)} decks: PASSED")

    # Test PresentationEngine Teleprompter
    active = presentation_engine.toggle_teleprompter(enable=True, speed=3.0)
    assert active is True
    time.sleep(0.2)
    active = presentation_engine.toggle_teleprompter(enable=False)
    assert active is False
    print(" -> PresentationEngine teleprompter toggle: PASSED")

    # 2. Start HTTP Server on test port 5098
    test_http_port = 5098
    http_server = HTTPServer("127.0.0.1", test_http_port)
    await http_server.start()

    # 3. Start WebSocket Server on test port 5099
    test_ws_port = 5099
    ws_server = WebSocketServer(
        "127.0.0.1",
        test_ws_port,
        input_engine,
        clipboard_engine=clipboard_engine,
        macro_engine=macro_engine,
        presentation_engine=presentation_engine
    )
    await ws_server.start()
    time.sleep(0.3)

    try:
        # TEST HTTP FILE SERVER
        base_http = f"http://127.0.0.1:{test_http_port}"
        async with aiohttp.ClientSession() as session:
            # 1. Status Check
            async with session.get(f"{base_http}/api/status") as resp:
                assert resp.status == 200
                data = await resp.json()
                assert data["status"] == "online"
                print(" -> HTTP Server /api/status: PASSED")

            # 2. Browse Drives
            async with session.get(f"{base_http}/api/files/browse") as resp:
                assert resp.status == 200
                browse_data = await resp.json()
                assert len(browse_data["items"]) > 0
                print(f" -> HTTP File Explorer Drive Listing ({len(browse_data['items'])} drives/shortcuts): PASSED")

            # 3. Quick File Drop Upload
            test_filename = "rf_test_upload.txt"
            test_content = b"Hello RemoteFlow Max Quick File Drop!"
            data = aiohttp.FormData()
            data.add_field("file", test_content, filename=test_filename, content_type="text/plain")

            # Upload into temp directory
            temp_dir = os.environ.get("TEMP", "C:\\temp")
            async with session.post(f"{base_http}/api/files/upload?dest={temp_dir}", data=data) as resp:
                assert resp.status == 200
                up_res = await resp.json()
                assert up_res["status"] == "success"
                uploaded_path = up_res["files"][0]["path"]
                assert os.path.exists(uploaded_path)
                print(f" -> HTTP Quick File Drop upload: PASSED ({uploaded_path})")

            # 4. Download Uploaded File
            async with session.get(f"{base_http}/api/files/download?path={uploaded_path}") as resp:
                assert resp.status == 200
                downloaded_bytes = await resp.read()
                assert downloaded_bytes == test_content
                print(" -> HTTP File Download from host: PASSED")

            # 5. Delete Test File
            async with session.post(f"{base_http}/api/files/delete", json={"path": uploaded_path}) as resp:
                assert resp.status == 200
                assert not os.path.exists(uploaded_path)
                print(" -> HTTP File Delete cleanup: PASSED")

        # TEST WEBSOCKET PHASE 3 CHANNELS
        uri = f"ws://127.0.0.1:{test_ws_port}"
        async with websockets.connect(uri) as ws:
            # Collect initial welcome, audio, and macro decks
            welcome = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            audio_state = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            decks_pkt = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))

            assert decks_pkt["type"] == "macro"
            assert decks_pkt["action"] == "decks"
            print(f" -> WS Stream Deck received {len(decks_pkt['payload']['decks'])} decks: PASSED")

            # Test Clipboard Push from Mobile
            clip_set = create_packet(PacketType.CLIPBOARD, ClipboardAction.SET, {"text": "Mobile_Clip_Content_99"})
            await ws.send(json.dumps(clip_set))
            await asyncio.sleep(0.2)
            assert clipboard_engine.get_clipboard() == "Mobile_Clip_Content_99"
            print(" -> WS Mobile -> Host Clipboard Sync: PASSED")

            # Test Presentation Teleprompter Toggle over WS
            tele_pkt = create_packet(PacketType.PRESENTATION, PresentationAction.TELEPROMPTER, {"enable": True, "speed": 4.0})
            await ws.send(json.dumps(tele_pkt))
            tele_resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=2.0))
            assert tele_resp["type"] == "presentation"
            assert tele_resp["payload"]["active"] is True
            print(" -> WS Presentation Teleprompter Control: PASSED")

        print("\n[PHASE 3 SERVER & HTTP TESTS PASSED SUCCESSFULLY!]")
    finally:
        await http_server.stop()
        ws_server.stop()

if __name__ == "__main__":
    asyncio.run(run_phase3_tests())
