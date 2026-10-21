"""
RemoteFlow Max - Phase 2 Integration Test Suite
Verifies Windows Core Audio mixer, media transport, live telemetry push,
instant RAM flush, and power deck controls.
"""

import sys
import os
import asyncio
import json
import websockets
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from pc_server.core.audio_engine import AudioEngine
from pc_server.core.system_engine import SystemEngine
from pc_server.core.input_engine import InputEngine
from pc_server.network.ws_server import WebSocketServer
from pc_server.core.protocol import create_packet, PacketType, AudioAction, MediaAction, PowerAction

async def run_phase2_tests():
    print("[PHASE 2 TEST] Starting Audio & System Power Deck Integration Tests...")

    # 1. Test AudioEngine Directly
    audio = AudioEngine()
    master = audio.get_master_volume_info()
    print(f" -> Master Volume Info: Level={master.get('volume')}, Muted={master.get('muted')}, Device={master.get('device_name')}")
    assert "volume" in master, "Missing volume in master info"

    mic = audio.get_microphone_info()
    print(f" -> Microphone Info: Muted={mic.get('muted')}, Device={mic.get('device_name')}")
    assert "muted" in mic, "Missing muted in mic info"

    sessions = audio.get_app_sessions()
    print(f" -> Active Audio Sessions ({len(sessions)}):")
    for s in sessions[:3]:
        print(f"    * App: {s['name']} (PID {s['pid']}), Volume: {s['volume']}, Muted: {s['muted']}")

    # 2. Test SystemEngine Directly
    sys_engine = SystemEngine()
    telemetry = sys_engine.get_telemetry()
    print(f" -> Live Telemetry Snapshot:")
    print(f"    CPU: {telemetry['cpu_percent']}% | RAM: {telemetry['ram_percent']}% ({telemetry['ram_used_gb']}/{telemetry['ram_total_gb']} GB)")
    print(f"    Disk: {telemetry['disk_percent']}% ({telemetry['disk_used_gb']}/{telemetry['disk_total_gb']} GB) | Uptime: {telemetry['uptime_seconds']}s")
    assert telemetry["cpu_percent"] >= 0
    assert telemetry["ram_percent"] > 0

    # Test Caffeine / Keep-Awake
    caff_state = sys_engine.set_caffeine(True)
    assert caff_state is True
    sys_engine.set_caffeine(False)
    print(" -> Keep-Awake / Caffeine Toggle: PASSED")

    # Test Instant RAM Flush
    flush_res = sys_engine.flush_ram()
    print(f" -> Instant RAM Flush: Initial={flush_res['initial_percent']}%, New={flush_res['new_percent']}%, Freed={flush_res['freed_mb']}MB")
    assert "freed_mb" in flush_res

    # 3. Test WebSocket Communication for Phase 2 Packets
    input_engine = InputEngine()
    test_port = 5092
    ws_server = WebSocketServer("127.0.0.1", test_port, input_engine, audio_engine=audio, system_engine=sys_engine)
    await ws_server.start()
    time.sleep(0.3)

    received_types = set()
    received_audio_states = []
    received_telemetry = []
    received_flush_results = []

    try:
        uri = f"ws://127.0.0.1:{test_port}"
        async with websockets.connect(uri) as ws:
            async def reader():
                while True:
                    try:
                        raw = await ws.recv()
                        data = json.loads(raw)
                        p_type = data.get("type")
                        action = data.get("action")
                        received_types.add((p_type, action))

                        if p_type == "audio" and action == "state":
                            received_audio_states.append(data["payload"])
                        elif p_type == "system" and action == "telemetry":
                            received_telemetry.append(data["payload"])
                        elif p_type == "power" and action == "ram_flush_result":
                            received_flush_results.append(data["payload"])
                    except Exception:
                        break

            reader_task = asyncio.create_task(reader())

            # Wait briefly to collect initial handshake and audio state
            await asyncio.sleep(0.4)

            # Send Set Master Volume packet
            set_vol_pkt = create_packet(PacketType.AUDIO, AudioAction.SET_MASTER_VOLUME, {"volume": 0.55})
            await ws.send(json.dumps(set_vol_pkt))

            # Send Media Transport packet
            media_pkt = create_packet(PacketType.MEDIA, MediaAction.PLAY_PAUSE)
            await ws.send(json.dumps(media_pkt))

            # Send RAM Flush packet over WebSocket
            ram_pkt = create_packet(PacketType.POWER, PowerAction.RAM_FLUSH)
            await ws.send(json.dumps(ram_pkt))

            # Wait 2.2 seconds to allow telemetry broadcast and flush response
            await asyncio.sleep(2.2)

            reader_task.cancel()

        print(f" -> Received packet types: {received_types}")
        assert len(received_audio_states) >= 1, "Did not receive Audio State!"
        print(f" -> Audio States received ({len(received_audio_states)}): PASSED")

        assert len(received_flush_results) >= 1, "Did not receive RAM Flush Result!"
        print(f" -> RAM Flush Result received: Freed {received_flush_results[0]['freed_mb']}MB: PASSED")

        assert len(received_telemetry) >= 1, "Did not receive Live Telemetry Broadcast!"
        print(f" -> Telemetry packets received ({len(received_telemetry)}), latest CPU: {received_telemetry[-1]['cpu_percent']}%, RAM: {received_telemetry[-1]['ram_percent']}%: PASSED")

        print("\n[PHASE 2 SERVER TESTS PASSED SUCCESSFULLY!]")
    finally:
        ws_server.stop()

if __name__ == "__main__":
    asyncio.run(run_phase2_tests())
