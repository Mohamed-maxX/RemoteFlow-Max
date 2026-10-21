"""
RemoteFlow Max - Asynchronous WebSocket Command Server (Phases 1, 2, 3 & 4)
Handles reliable bidirectional commands, keyboard emulation, ping/pong latency measurement,
live hardware telemetry broadcasting, audio mixer control, media keys, power actions,
shared clipboard sync, virtual stream deck macros, presentation remote,
virtual gamepad controls, security PIN handshake, and screen streaming.
Robust event handlers with comprehensive try/except protection and keepalive heartbeats.
"""

import asyncio
import json
import logging
import base64
import websockets
from typing import Set, Optional
from pc_server.core.protocol import (
    parse_packet,
    create_packet,
    serialize_packet,
    PacketType,
    MouseAction,
    KeyboardAction,
    SystemAction,
    HandshakeAction,
    AudioAction,
    MediaAction,
    PowerAction,
    ClipboardAction,
    MacroAction,
    PresentationAction,
    GamepadAction,
    SecurityAction,
    StreamAction
)
from pc_server.core.input_engine import InputEngine
from pc_server.core.audio_engine import AudioEngine
from pc_server.core.system_engine import SystemEngine
from pc_server.core.clipboard_engine import ClipboardEngine
from pc_server.core.macro_engine import MacroEngine
from pc_server.core.presentation_engine import PresentationEngine
from pc_server.core.auth_engine import AuthEngine
from pc_server.core.gamepad_engine import GamepadEngine
from pc_server.core.screen_engine import ScreenEngine
from pc_server.config import SERVER_NAME, SERVER_VERSION, HTTP_PORT
from pc_server.utils.config_manager import config_manager
from pc_server.utils.net_utils import get_primary_local_ip
from pc_server.utils.live_ui_manager import live_ui_manager

try:
    from websockets.protocol import State
    OPEN_STATE = State.OPEN
except Exception:
    OPEN_STATE = 1

logger = logging.getLogger("RemoteFlow.WSServer")


class WebSocketServer:
    def __init__(
        self,
        host: str,
        port: int,
        input_engine: InputEngine,
        audio_engine: Optional[AudioEngine] = None,
        system_engine: Optional[SystemEngine] = None,
        clipboard_engine: Optional[ClipboardEngine] = None,
        macro_engine: Optional[MacroEngine] = None,
        presentation_engine: Optional[PresentationEngine] = None,
        auth_engine: Optional[AuthEngine] = None,
        gamepad_engine: Optional[GamepadEngine] = None,
        screen_engine: Optional[ScreenEngine] = None
    ):
        self.host = host
        self.port = port
        self.input_engine = input_engine
        self.audio_engine = audio_engine or AudioEngine()
        self.system_engine = system_engine or SystemEngine()
        self.clipboard_engine = clipboard_engine or ClipboardEngine()
        self.macro_engine = macro_engine or MacroEngine(input_engine)
        self.presentation_engine = presentation_engine or PresentationEngine(input_engine)
        self.auth_engine = auth_engine or AuthEngine()
        self.gamepad_engine = gamepad_engine or GamepadEngine(input_engine)
        self.screen_engine = screen_engine or ScreenEngine()

        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self.clipboard_engine.on_clipboard_changed = self._on_clipboard_changed_sync

        self.active_clients: Set[websockets.WebSocketServerProtocol] = set()
        self.streaming_clients: Set[websockets.WebSocketServerProtocol] = set()
        self.server: Optional[websockets.Server] = None
        self._telemetry_task: Optional[asyncio.Task] = None
        self._stream_task: Optional[asyncio.Task] = None
        self._running = False

        # Live mobile client monitoring for Control Center GUI
        self.client_info = {
            "connected": False,
            "name": "لا يوجد جهاز متصل",
            "ip": "0.0.0.0",
            "latency_ms": 0,
        }

    def _on_clipboard_changed_sync(self, text: str):
        if self._loop and self._loop.is_running() and self.active_clients:
            pkt = create_packet(PacketType.CLIPBOARD, ClipboardAction.SYNC, {"text": text})
            asyncio.run_coroutine_threadsafe(self.broadcast(pkt), self._loop)

    async def start(self):
        self._running = True
        self._loop = asyncio.get_running_loop()
        # Resilient keepalive ping interval allowing mobile battery savers without premature disconnects
        self.server = await websockets.serve(
            self._handle_client,
            self.host,
            self.port,
            ping_interval=20,
            ping_timeout=40
        )
        self._telemetry_task = asyncio.create_task(self._telemetry_loop())
        self._stream_task = asyncio.create_task(self._stream_loop())

        # Start Live UI & APK OTA File Watcher
        def on_ui_changed(new_config: dict):
            if self._loop and self._loop.is_running() and self.active_clients:
                pkt = create_packet("ui", "live_update", {"config": new_config})
                asyncio.run_coroutine_threadsafe(self.broadcast(pkt), self._loop)

        def on_apk_changed(meta: dict):
            if self._loop and self._loop.is_running() and self.active_clients:
                ip = get_primary_local_ip()
                pkt = create_packet("system", "new_apk_ready", {
                    "version": SERVER_VERSION,
                    "size_mb": meta.get("size_mb", 0),
                    "hash": meta.get("hash", ""),
                    "timestamp": meta.get("timestamp", 0),
                    "download_url": f"http://{ip}:{HTTP_PORT}/api/update/latest.apk",
                    "notes": "تحديث برمجي فوري متاح لـ RemoteFlow Max (Zero-Touch OTA)"
                })
                asyncio.run_coroutine_threadsafe(self.broadcast(pkt), self._loop)

        live_ui_manager.start_watcher(on_ui_update=on_ui_changed, on_apk_update=on_apk_changed)
        logger.info(f"[WS] WebSocket command server listening on ws://{self.host}:{self.port} (Heartbeat: 5s)")

    async def _telemetry_loop(self):
        while self._running:
            try:
                await asyncio.sleep(1.0)
                if self.active_clients:
                    telemetry = self.system_engine.get_telemetry()
                    pkt = create_packet(PacketType.SYSTEM, SystemAction.TELEMETRY, telemetry)
                    await self.broadcast(pkt)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.debug(f"[WS] Telemetry loop warning: {e}")

    async def _stream_loop(self):
        """Streams compressed screen frames over WebSocket to subscribed mobile viewers."""
        while self._running:
            try:
                if self.streaming_clients:
                    jpeg_bytes = self.screen_engine.capture_frame_jpeg(quality=45, target_width=720)
                    b64 = base64.b64encode(jpeg_bytes).decode("ascii")
                    pkt = create_packet(PacketType.STREAM, StreamAction.FRAME, {"image": b64})
                    pkt_str = serialize_packet(pkt)
                    await asyncio.gather(
                        *[c.send(pkt_str) for c in list(self.streaming_clients) if hasattr(c, "state") and c.state == OPEN_STATE],
                        return_exceptions=True
                    )
                    await asyncio.sleep(0.04)  # ~25 FPS
                else:
                    await asyncio.sleep(0.2)
            except asyncio.CancelledError:
                break
            except Exception:
                await asyncio.sleep(0.1)

    async def _get_audio_state_packet_async(self) -> dict:
        try:
            state = await self.audio_engine.get_state_async()
            return create_packet(PacketType.AUDIO, AudioAction.STATE, state)
        except Exception as e:
            logger.warning(f"[WS] Error obtaining audio state async: {e}")
            return self._get_audio_state_packet()

    async def push_file_to_clients_async(self, file_path: str) -> bool:
        import urllib.parse
        if not os.path.exists(file_path):
            return False

        filename = os.path.basename(file_path)
        file_size = os.path.getsize(file_path)
        encoded_path = urllib.parse.quote(file_path)
        ip = get_primary_local_ip()
        download_url = f"http://{ip}:{HTTP_PORT}/api/files/download?path={encoded_path}"

        pkt = create_packet("file", "push_offer", {
            "filename": filename,
            "path": file_path,
            "size": file_size,
            "download_url": download_url
        })
        await self.broadcast(pkt)
        logger.info(f"[WS] Broadcasted file offer to mobile: {filename} ({file_size} bytes)")
        return True

    def push_file_to_clients(self, file_path: str):
        if self._loop and self._loop.is_running():
            asyncio.run_coroutine_threadsafe(self.push_file_to_clients_async(file_path), self._loop)

    def _get_audio_state_packet(self) -> dict:
        try:
            state = self.audio_engine._get_state_sync()
            return create_packet(PacketType.AUDIO, AudioAction.STATE, state)
        except Exception as e:
            logger.warning(f"[WS] Error obtaining audio state: {e}")
            return create_packet(PacketType.AUDIO, AudioAction.STATE, {
                "master": {"volume": 0.5, "muted": False, "device_name": "Speakers"},
                "mic": {"muted": False, "volume": 1.0, "device_name": "Microphone"},
                "sessions": []
            })

    async def _handle_client(self, websocket):
        client_ip = websocket.remote_address[0] if websocket.remote_address else "unknown"
        logger.info(f"[WS] Client connected from {client_ip}")
        self.active_clients.add(websocket)

        w, h = 1920, 1080
        try:
            w, h = self.input_engine.get_screen_size()
        except Exception:
            pass

        # 1. Send initial welcome / discovery packet safely
        try:
            welcome = create_packet(PacketType.HANDSHAKE, HandshakeAction.ACK, {
                "server_name": SERVER_NAME,
                "version": SERVER_VERSION,
                "screen_size": [w, h],
                "pin_required": self.auth_engine.pin_enabled
            })
            await websocket.send(serialize_packet(welcome))
        except Exception as e:
            logger.warning(f"[WS] Failed sending welcome to {client_ip}: {e}")

        # 2. Send initial audio state safely
        try:
            await websocket.send(serialize_packet(await self._get_audio_state_packet_async()))
        except Exception as e:
            logger.warning(f"[WS] Failed sending audio state to {client_ip}: {e}")

        # 3. Send initial macro decks safely
        try:
            decks_pkt = create_packet(PacketType.MACRO, MacroAction.DECKS, {
                "decks": self.macro_engine.get_decks()
            })
            await websocket.send(serialize_packet(decks_pkt))
        except Exception as e:
            logger.warning(f"[WS] Failed sending decks to {client_ip}: {e}")

        # 4. Send initial Live UI dynamic configuration
        try:
            ui_cfg = live_ui_manager.load_config()
            if ui_cfg:
                ui_pkt = create_packet("ui", "live_update", {"config": ui_cfg})
                await websocket.send(serialize_packet(ui_pkt))
        except Exception as e:
            logger.warning(f"[WS] Failed sending initial live UI config to {client_ip}: {e}")

        try:
            async for message in websocket:
                try:
                    pkt = parse_packet(message)
                    if not pkt:
                        continue

                    p_type = str(pkt.get("type", "")).lower()
                    action = str(pkt.get("action", "")).lower()
                    payload = pkt.get("payload", {})
                    if not isinstance(payload, dict):
                        payload = {}

                    # -------------------------------------------------------------
                    # 1. Handshake & Connect
                    # -------------------------------------------------------------
                    if p_type in ("handshake", PacketType.HANDSHAKE):
                        try:
                            if action in ("connect", HandshakeAction.CONNECT, "init"):
                                client_name = payload.get("client_name", "Remote Client")
                                device_id = payload.get("device_id", "")

                                # Check and register trusted device in config.json
                                is_trusted = config_manager.is_trusted_device(device_id, client_ip)
                                config_manager.add_trusted_device(device_id, client_name, client_ip)

                                logger.info(f"[WS] Handshake established with {client_name} ({client_ip}, Trusted: {is_trusted})")
                                self.client_info["connected"] = True
                                self.client_info["name"] = str(client_name)
                                self.client_info["ip"] = str(client_ip)
                                self.client_info["device_id"] = str(device_id)

                                # If already trusted, bypass pin verification
                                pin_required = self.auth_engine.pin_enabled and not is_trusted

                                response = create_packet(PacketType.HANDSHAKE, HandshakeAction.ACK, {
                                    "status": "connected",
                                    "server_name": SERVER_NAME,
                                    "version": SERVER_VERSION,
                                    "screen_size": [w, h],
                                    "pin_required": pin_required,
                                    "is_trusted": True
                                })
                                await websocket.send(serialize_packet(response))
                        except Exception as e:
                            logger.error(f"[WS] Handshake error: {e}")

                    # -------------------------------------------------------------
                    # 2. Security & PIN Authentication
                    # -------------------------------------------------------------
                    elif p_type in ("security", PacketType.SECURITY):
                        try:
                            if action in ("auth", SecurityAction.AUTH):
                                pin = str(payload.get("pin", ""))
                                device_id = payload.get("device_id", self.client_info.get("device_id", ""))
                                client_name = payload.get("client_name", self.client_info.get("name", "Remote Client"))
                                if self.auth_engine.verify_pin(pin):
                                    # Mark device as trusted upon successful PIN verification
                                    config_manager.add_trusted_device(device_id, client_name, client_ip)
                                    ack = create_packet(PacketType.SECURITY, SecurityAction.AUTH_ACK, {
                                        "token": self.auth_engine.auth_token,
                                        "trusted": True
                                    })
                                    await websocket.send(serialize_packet(ack))
                                else:
                                    fail = create_packet(PacketType.SECURITY, SecurityAction.AUTH_FAIL, {
                                        "error": "Invalid PIN"
                                    })
                                    await websocket.send(serialize_packet(fail))
                        except Exception as e:
                            logger.error(f"[WS] Security auth error: {e}")

                    # -------------------------------------------------------------
                    # 3. Keyboard Input (Standard & keyboard_event alias)
                    # -------------------------------------------------------------
                    elif p_type in ("keyboard", "keyboard_event", PacketType.KEYBOARD):
                        try:
                            if action in ("text", KeyboardAction.TEXT) or ("text" in payload and "key" not in payload and "keys" not in payload):
                                text = payload.get("text", "")
                                self.input_engine.type_text(str(text))
                            elif action in ("key", KeyboardAction.KEY) or ("key" in payload and "keys" not in payload):
                                key = payload.get("key", "")
                                state = payload.get("state", "press")
                                self.input_engine.send_key(str(key), str(state))
                            elif action in ("hotkey", KeyboardAction.HOTKEY) or ("keys" in payload):
                                keys = payload.get("keys", [])
                                if isinstance(keys, list):
                                    self.input_engine.send_hotkey(keys)
                        except Exception as e:
                            logger.error(f"[WS] Keyboard execution error: {e}")

                    # -------------------------------------------------------------
                    # 4. Media Keys (Standard & media_key alias)
                    # -------------------------------------------------------------
                    elif p_type in ("media", "media_key", PacketType.MEDIA) or action in ("media_key",):
                        try:
                            target_act = action if action not in ("media_key", "media") else payload.get("action", payload.get("key", "play_pause"))
                            await self.audio_engine.media_action_async(str(target_act))
                        except Exception as e:
                            logger.error(f"[WS] Media action error: {e}")

                    # -------------------------------------------------------------
                    # 5. Audio Deck (volume_change, app_volume, toggle mute)
                    # -------------------------------------------------------------
                    elif p_type in ("audio", "volume_change", "app_volume", PacketType.AUDIO) or action in ("volume_change", "app_volume"):
                        try:
                            if action in ("get_state", AudioAction.GET_STATE):
                                await websocket.send(serialize_packet(await self._get_audio_state_packet_async()))

                            elif p_type == "volume_change" or action in ("volume_change", "set_master_volume", AudioAction.SET_MASTER_VOLUME):
                                vol = float(payload.get("volume", payload.get("level", 0.5)))
                                await self.audio_engine.set_master_volume_async(vol)
                                await self.broadcast(await self._get_audio_state_packet_async())

                            elif action in ("toggle_master_mute", AudioAction.TOGGLE_MASTER_MUTE):
                                await self.audio_engine.toggle_master_mute_async()
                                await self.broadcast(await self._get_audio_state_packet_async())

                            elif action in ("toggle_mic_mute", AudioAction.TOGGLE_MIC_MUTE):
                                await self.audio_engine.toggle_microphone_mute_async()
                                await self.broadcast(await self._get_audio_state_packet_async())

                            elif p_type == "app_volume" or action in ("app_volume", "set_app_volume", AudioAction.SET_APP_VOLUME):
                                pid = int(payload.get("pid", 0))
                                raw_name = payload.get("raw_name") or payload.get("name")
                                vol = float(payload.get("volume", payload.get("level", 1.0)))
                                await self.audio_engine.set_app_volume_async(pid, raw_name, vol)
                                await self.broadcast(await self._get_audio_state_packet_async())

                            elif action in ("toggle_app_mute", AudioAction.TOGGLE_APP_MUTE):
                                pid = int(payload.get("pid", 0))
                                raw_name = payload.get("raw_name") or payload.get("name")
                                await self.audio_engine.toggle_app_mute_async(pid, raw_name)
                                await self.broadcast(await self._get_audio_state_packet_async())
                        except Exception as e:
                            logger.error(f"[WS] Audio execution error: {e}")

                    # -------------------------------------------------------------
                    # 6. Power & System Management (system_power alias)
                    # -------------------------------------------------------------
                    elif p_type in ("power", "system_power", PacketType.POWER) or action in ("system_power",):
                        try:
                            power_cmd = action if action not in ("system_power", "power") else payload.get("command", payload.get("action", ""))
                            power_cmd = str(power_cmd).lower()

                            if power_cmd in ("lock", PowerAction.LOCK):
                                self.system_engine.lock_workstation()
                            elif power_cmd in ("sleep", PowerAction.SLEEP):
                                self.system_engine.sleep_system()
                            elif power_cmd in ("shutdown", PowerAction.SHUTDOWN):
                                timer = int(payload.get("timer", 0))
                                self.system_engine.shutdown_system(timer)
                            elif power_cmd in ("restart", PowerAction.RESTART):
                                timer = int(payload.get("timer", 0))
                                self.system_engine.restart_system(timer)
                            elif power_cmd in ("cancel_shutdown", PowerAction.CANCEL_SHUTDOWN):
                                self.system_engine.cancel_shutdown()
                            elif power_cmd in ("caffeine", PowerAction.CAFFEINE):
                                enable = bool(payload.get("enable", True))
                                self.system_engine.set_caffeine(enable)
                                await self.broadcast(create_packet(PacketType.SYSTEM, SystemAction.TELEMETRY, self.system_engine.get_telemetry()))
                            elif power_cmd in ("ram_flush", PowerAction.RAM_FLUSH):
                                res = self.system_engine.flush_ram()
                                resp = create_packet(PacketType.POWER, "ram_flush_result", res)
                                await websocket.send(serialize_packet(resp))
                                await self.broadcast(create_packet(PacketType.SYSTEM, SystemAction.TELEMETRY, self.system_engine.get_telemetry()))
                            elif power_cmd in ("boss_key", PowerAction.BOSS_KEY):
                                self.system_engine.boss_key(self.audio_engine)
                                await self.broadcast(self._get_audio_state_packet())
                            elif power_cmd in ("set_profile", PowerAction.SET_PROFILE):
                                self.system_engine.set_power_profile(payload.get("profile", "balanced"))
                            elif power_cmd in ("wol", PowerAction.WOL):
                                if payload.get("mac"):
                                    self.system_engine.send_wake_on_lan(payload["mac"])
                        except Exception as e:
                            logger.error(f"[WS] Power command error: {e}")

                    # -------------------------------------------------------------
                    # 7. System Commands & Telemetry (get_telemetry alias & Ping/Pong)
                    # -------------------------------------------------------------
                    elif p_type in ("system", "telemetry", "get_telemetry", PacketType.SYSTEM) or action in ("get_telemetry", "telemetry"):
                        try:
                            if action in ("get_telemetry", "telemetry") or p_type in ("get_telemetry", "telemetry"):
                                resp = create_packet(PacketType.SYSTEM, SystemAction.TELEMETRY, self.system_engine.get_telemetry())
                                await websocket.send(serialize_packet(resp))

                            elif action in ("ping", SystemAction.PING):
                                client_ts = payload.get("client_ts", 0)
                                if client_ts:
                                    import time
                                    calc_latency = int((time.time() * 1000) - client_ts)
                                    if 0 <= calc_latency < 5000:
                                        self.client_info["latency_ms"] = calc_latency
                                pong = create_packet(PacketType.SYSTEM, SystemAction.PONG, {
                                    "client_ts": client_ts,
                                    "server_ts": int(asyncio.get_event_loop().time() * 1000)
                                })
                                await websocket.send(serialize_packet(pong))

                            elif action in ("set_sensitivity", SystemAction.SET_SENSITIVITY):
                                sens = float(payload.get("sensitivity", 1.0))
                                self.input_engine.accel.set_sensitivity(sens)
                        except Exception as e:
                            logger.error(f"[WS] System command error: {e}")

                    # -------------------------------------------------------------
                    # 8. Mouse Actions (Fallback or over WS)
                    # -------------------------------------------------------------
                    elif p_type in ("mouse", PacketType.MOUSE):
                        try:
                            if action in ("click", MouseAction.CLICK):
                                self.input_engine.click(payload.get("button", "left"), payload.get("state", "click"))
                            elif action in ("down", MouseAction.DOWN):
                                self.input_engine.click(payload.get("button", "left"), "down")
                            elif action in ("up", MouseAction.UP):
                                self.input_engine.click(payload.get("button", "left"), "up")
                            elif action in ("scroll", MouseAction.SCROLL):
                                self.input_engine.scroll(float(payload.get("dy", 0.0)), float(payload.get("dx", 0.0)))
                        except Exception as e:
                            logger.error(f"[WS] Mouse WS command error: {e}")

                    # -------------------------------------------------------------
                    # 9. Virtual Gamepad
                    # -------------------------------------------------------------
                    elif p_type in ("gamepad", PacketType.GAMEPAD):
                        try:
                            if action in ("button", GamepadAction.BUTTON):
                                btn = payload.get("button", "")
                                state = payload.get("state", "press")
                                self.gamepad_engine.process_button(btn, state)
                            elif action in ("stick", GamepadAction.STICK):
                                stick = payload.get("stick", "left")
                                x = float(payload.get("x", 0.0))
                                y = float(payload.get("y", 0.0))
                                self.gamepad_engine.process_joystick(stick, x, y)
                        except Exception as e:
                            logger.error(f"[WS] Gamepad command error: {e}")

                    # -------------------------------------------------------------
                    # 10. Screen Stream Subscription & Screenshots
                    # -------------------------------------------------------------
                    elif p_type in ("stream", PacketType.STREAM):
                        try:
                            if action in ("start", StreamAction.START):
                                self.streaming_clients.add(websocket)
                            elif action in ("stop", StreamAction.STOP):
                                self.streaming_clients.discard(websocket)
                            elif action in ("screenshot", StreamAction.SCREENSHOT):
                                jpeg_bytes = self.screen_engine.capture_full_screenshot_jpeg()
                                b64 = base64.b64encode(jpeg_bytes).decode("ascii")
                                resp = create_packet(PacketType.STREAM, StreamAction.SCREENSHOT, {"image": b64})
                                await websocket.send(serialize_packet(resp))
                        except Exception as e:
                            logger.error(f"[WS] Screen stream command error: {e}")

                    # -------------------------------------------------------------
                    # 11. Shared Clipboard
                    # -------------------------------------------------------------
                    elif p_type in ("clipboard", PacketType.CLIPBOARD):
                        try:
                            if action in ("set", ClipboardAction.SET):
                                self.clipboard_engine.set_clipboard(payload.get("text", ""))
                            elif action in ("get", ClipboardAction.GET):
                                curr = self.clipboard_engine.get_clipboard()
                                resp = create_packet(PacketType.CLIPBOARD, ClipboardAction.SYNC, {"text": curr})
                                await websocket.send(serialize_packet(resp))
                        except Exception as e:
                            logger.error(f"[WS] Clipboard command error: {e}")

                    # -------------------------------------------------------------
                    # 12. Virtual Stream Deck Macros
                    # -------------------------------------------------------------
                    elif p_type in ("macro", PacketType.MACRO):
                        try:
                            if action in ("execute", MacroAction.EXECUTE):
                                self.macro_engine.execute_macro(payload.get("macro_type", ""), payload.get("payload", {}))
                            elif action in ("get_decks", MacroAction.GET_DECKS):
                                decks = self.macro_engine.get_decks()
                                await websocket.send(serialize_packet(create_packet(PacketType.MACRO, MacroAction.DECKS, {"decks": decks})))
                        except Exception as e:
                            logger.error(f"[WS] Macro command error: {e}")

                    # -------------------------------------------------------------
                    # 13. Presentation Mode & Teleprompter
                    # -------------------------------------------------------------
                    elif p_type in ("presentation", PacketType.PRESENTATION):
                        try:
                            if action in ("action", PresentationAction.ACTION):
                                self.presentation_engine.slide_action(payload.get("slide_action", "next"))
                            elif action in ("teleprompter", PresentationAction.TELEPROMPTER):
                                enable = payload.get("enable")
                                speed = payload.get("speed")
                                active = self.presentation_engine.toggle_teleprompter(enable, speed)
                                resp = create_packet(PacketType.PRESENTATION, PresentationAction.TELEPROMPTER, {
                                    "active": active,
                                    "speed": self.presentation_engine.teleprompter_speed
                                })
                                await websocket.send(serialize_packet(resp))
                        except Exception as e:
                            logger.error(f"[WS] Presentation command error: {e}")

                    # -------------------------------------------------------------
                    # 14. Server-Driven Live UI & Dynamic Hot-Reload
                    # -------------------------------------------------------------
                    elif p_type in ("ui", "live_ui"):
                        try:
                            if action in ("get_config", "load"):
                                resp = create_packet("ui", "live_update", {"config": live_ui_manager.load_config()})
                                await websocket.send(serialize_packet(resp))
                            elif action in ("save_config", "update"):
                                cfg_to_save = payload.get("config", payload)
                                success = live_ui_manager.save_config(cfg_to_save)
                                ack = create_packet("ui", "save_ack", {"status": "success" if success else "failed"})
                                await websocket.send(serialize_packet(ack))
                        except Exception as e:
                            logger.error(f"[WS] Live UI command error: {e}")

                except Exception as inner_e:
                    logger.error(f"[WS] Malformed packet or parsing error: {inner_e}")
                    # Keep listening, never break the connection!

        except websockets.exceptions.ConnectionClosed:
            logger.info(f"[WS] Client {client_ip} disconnected.")
        except Exception as e:
            logger.warning(f"[WS] Client socket connection dropped: {e}")
        finally:
            self.active_clients.discard(websocket)
            self.streaming_clients.discard(websocket)
            if not self.active_clients:
                self.client_info["connected"] = False
                self.client_info["latency_ms"] = 0
            try:
                self.input_engine.release_all_mouse_buttons()
                self.gamepad_engine.release_all()
            except Exception:
                pass

    async def broadcast(self, packet: dict):
        if not self.active_clients:
            return
        payload_str = serialize_packet(packet)
        tasks = []
        for client in list(self.active_clients):
            try:
                is_open = True
                if hasattr(client, "state"):
                    is_open = (client.state == OPEN_STATE)
                elif hasattr(client, "open"):
                    is_open = bool(client.open)

                if is_open:
                    tasks.append(client.send(payload_str))
            except Exception:
                pass

        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)

    def stop(self):
        self._running = False
        live_ui_manager.stop_watcher()
        if self._telemetry_task:
            self._telemetry_task.cancel()
        if self._stream_task:
            self._stream_task.cancel()
        if self.presentation_engine:
            self.presentation_engine.toggle_teleprompter(enable=False)
        self.gamepad_engine.release_all()
        if self.server:
            self.server.close()
