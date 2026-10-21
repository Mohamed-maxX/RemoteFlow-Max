"""
RemoteFlow Max - PC Host Daemon Entrypoint (Phases 1-4 + Modern Dark GUI Control Center)
Production-grade server coordinating UDP high-frequency input, WebSocket command server,
HTTP File Explorer & upload server, web pairing dashboard, zero-config discovery, audio engine,
system performance monitor, shared clipboard sync, virtual stream deck, screen streaming,
virtual gamepad, Windows System Tray integration, and Modern CustomTkinter Control Center.
"""

import sys
import os
import time
import asyncio
import logging
import threading
import subprocess

# Add current workspace to python path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Ensure safe stdout/stderr handling when running headless/pythonw in background
app_dir = os.path.dirname(sys.executable if getattr(sys, 'frozen', False) else __file__)
log_file_path = os.path.join(app_dir, "remoteflow_server.log")

if sys.stdout is None:
    try:
        sys.stdout = open(log_file_path, "a", encoding="utf-8", buffering=1)
    except Exception:
        sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    try:
        sys.stderr = open(log_file_path, "a", encoding="utf-8", buffering=1)
    except Exception:
        sys.stderr = open(os.devnull, "w")

from pc_server.config import HOST, UDP_PORT, WS_PORT, HTTP_PORT, SERVER_NAME, SERVER_VERSION
from pc_server.core.input_engine import InputEngine
from pc_server.core.audio_engine import AudioEngine
from pc_server.core.system_engine import SystemEngine
from pc_server.core.clipboard_engine import ClipboardEngine
from pc_server.core.macro_engine import MacroEngine
from pc_server.core.presentation_engine import PresentationEngine
from pc_server.core.auth_engine import AuthEngine
from pc_server.core.gamepad_engine import GamepadEngine
from pc_server.core.screen_engine import ScreenEngine
from pc_server.network.udp_listener import UDPListener
from pc_server.network.ws_server import WebSocketServer
from pc_server.network.http_server import HTTPServer
from pc_server.network.discovery import DiscoveryService
from pc_server.utils.net_utils import get_primary_local_ip, get_all_local_ips
from pc_server.utils.qr_display import print_qr_code, generate_pairing_payload
from pc_server.utils.port_manager import free_conflicting_ports
from pc_server.utils.shortcut_utils import create_windows_shortcuts
from pc_server.utils.config_manager import config_manager
from pc_server.tray_manager import TrayManager, PYSTRAY_AVAILABLE

try:
    from pc_server.gui.control_center import ControlCenterApp
    GUI_AVAILABLE = True
except Exception as e:
    GUI_AVAILABLE = False

BANNER = r"""
========================================================================
   ____                       __         ______ __                 __  ___            
  / __ \___  ____ ___  ____  / /____    / ____// /____  _      __ /  |/  /____ _ _  __
 / /_/ // _ \/ __ `__ \/ __ \/ __/ _ \  / /_   / // __ \| | /| / // /|_/ // __ `/| |/_/
/ _, _//  __/ / / / / / /_/ / /_/  __/ / __/  / // /_/ /| |/ |/ // /  / // /_/ />  <  
/_/ |_| \___//_/ /_/ /_/\____/\__/\___/ /_/    /_/ \____/ |__/|__//_/  /_/ \__,_//_/|_|  
========================================================================
"""

def setup_logging():
    handlers = []
    try:
        handlers.append(logging.FileHandler(log_file_path, encoding="utf-8"))
    except Exception:
        pass
    if sys.stdout is not None:
        try:
            handlers.append(logging.StreamHandler(sys.stdout))
        except Exception:
            pass
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
        handlers=handlers
    )

def main():
    setup_logging()
    logger = logging.getLogger("RemoteFlow.Main")

    try:
        print(BANNER)
    except Exception:
        pass
    logger.info(f"Starting {SERVER_NAME} v{SERVER_VERSION}")

    # 0. Load Persistent Configuration (config.json) & Sync Autostart
    config_manager.sync_autostart_with_registry()
    logger.info(f"Loaded persistent configuration from {config_manager.config_path}")

    # 0.1 Single Instance & Port Management (Completely eliminates WinError 10048)
    free_conflicting_ports((UDP_PORT, WS_PORT, 5057, HTTP_PORT))

    # 1. Resolve Local Network IP
    primary_ip = get_primary_local_ip()
    all_ips = get_all_local_ips()
    logger.info(f"Primary LAN IP: {primary_ip}")
    if len(all_ips) > 1:
        logger.info(f"Available Network Interfaces: {', '.join(all_ips)}")

    # 2. Confirm Desktop & Start Menu Shortcuts
    work_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    target_exe = sys.executable if getattr(sys, 'frozen', False) else os.path.join(work_dir, "RemoteFlowMax.exe")
    icon_path = os.path.join(work_dir, "app_icon.ico")
    if os.path.exists(target_exe) and os.path.exists(icon_path):
        create_windows_shortcuts(target_exe, icon_path, work_dir)

    # 3. Initialize Core Engines
    auth_engine = AuthEngine(pin_enabled=False)
    input_engine = InputEngine()
    audio_engine = AudioEngine()
    system_engine = SystemEngine()
    clipboard_engine = ClipboardEngine()
    macro_engine = MacroEngine(input_engine)
    presentation_engine = PresentationEngine(input_engine)
    gamepad_engine = GamepadEngine(input_engine)
    screen_engine = ScreenEngine()

    # 4. Display Pairing QR Code in Terminal
    try:
        pairing_data = generate_pairing_payload(primary_ip, WS_PORT, UDP_PORT, SERVER_NAME)
        print("\n--- [MOBILE PAIRING QR CODE] ---")
        print(f"Scan with RemoteFlow Max mobile app to connect instantly to {primary_ip}")
        print_qr_code(pairing_data)
        print("--------------------------------\n")
    except Exception:
        pass

    w, h = input_engine.get_screen_size()
    logger.info(f"Detected Display Resolution: {w}x{h}")

    # 5. Start Clipboard Monitoring
    clipboard_engine.start_monitoring()

    # 6. Start UDP Listener (Threaded)
    udp_listener = UDPListener(HOST, UDP_PORT, input_engine)
    udp_listener.start_listener()

    # 7. Start Discovery Beacon (Threaded)
    discovery = DiscoveryService(primary_ip)
    discovery.start_service()

    # 8. Start HTTP File Explorer, Upload & Stream Server (Asyncio)
    http_server = HTTPServer(HOST, HTTP_PORT, screen_engine=screen_engine, primary_ip=primary_ip)

    # 9. Start WebSocket Command Server (Asyncio)
    ws_server = WebSocketServer(
        HOST,
        WS_PORT,
        input_engine,
        audio_engine=audio_engine,
        system_engine=system_engine,
        clipboard_engine=clipboard_engine,
        macro_engine=macro_engine,
        presentation_engine=presentation_engine,
        auth_engine=auth_engine,
        gamepad_engine=gamepad_engine,
        screen_engine=screen_engine
    )

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    async_stop_event = asyncio.Event()
    main_stop_event = threading.Event()

    async def run_async_servers():
        await http_server.start()
        await ws_server.start()
        logger.info(f"RemoteFlow Max Host is LIVE (UDP:{UDP_PORT}, WS:{WS_PORT}, HTTP:{HTTP_PORT})")
        while not async_stop_event.is_set():
            await asyncio.sleep(0.5)
        await http_server.stop()
        ws_server.stop()

    def trigger_shutdown():
        logger.info("Shutdown requested. Stopping all services...")
        try:
            udp_listener.stop()
            discovery.stop()
            clipboard_engine.stop()
            screen_engine.close()
            presentation_engine.toggle_teleprompter(enable=False)
            
            if loop.is_running():
                loop.call_soon_threadsafe(async_stop_event.set)
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
        main_stop_event.set()

    def trigger_restart():
        logger.info("Restarting RemoteFlow Max PC Server...")
        trigger_shutdown()
        time.sleep(0.5)
        if getattr(sys, 'frozen', False):
            subprocess.Popen([sys.executable] + sys.argv[1:])
        else:
            subprocess.Popen([sys.executable] + sys.argv)
        sys.exit(0)

    # Run asyncio loop in background thread
    async_thread = threading.Thread(
        target=lambda: loop.run_until_complete(run_async_servers()),
        daemon=True,
        name="AsyncioServerThread"
    )
    async_thread.start()

    # 10. Start System Tray Icon
    tray_manager = None
    use_tray = "--no-tray" not in sys.argv and PYSTRAY_AVAILABLE
    if use_tray:
        tray_manager = TrayManager(
            primary_ip=primary_ip,
            http_port=HTTP_PORT,
            on_exit_callback=trigger_shutdown,
            on_restart_callback=trigger_restart
        )
        tray_manager.start()

    # 11. Start Modern Dark GUI Control Center (CustomTkinter)
    use_gui = "--no-gui" not in sys.argv and "--headless" not in sys.argv and GUI_AVAILABLE
    if use_gui:
        logger.info("Starting Modern Dark GUI Control Center...")
        try:
            app = ControlCenterApp(
                primary_ip=primary_ip,
                ws_server=ws_server,
                system_engine=system_engine,
                on_restart_callback=trigger_restart,
                on_exit_callback=trigger_shutdown
            )
            if tray_manager:
                tray_manager.on_show_gui = lambda open_tab=None: app.after(0, app.restore_from_tray)
                app.tray_manager = tray_manager

            app.mainloop()
        except Exception as e:
            logger.error(f"Error running GUI: {e}")
            while not main_stop_event.is_set():
                time.sleep(0.5)
    else:
        # Fallback to headless loop if GUI is disabled
        try:
            while not main_stop_event.is_set():
                time.sleep(0.5)
        except KeyboardInterrupt:
            trigger_shutdown()

    logger.info("RemoteFlow Max PC Server shut down cleanly.")
    sys.exit(0)

if __name__ == "__main__":
    main()
