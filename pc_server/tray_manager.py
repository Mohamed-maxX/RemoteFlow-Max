"""
RemoteFlow Max - System Tray Application Manager
Provides Windows system tray integration with live status, IP copying,
QR code pairing dashboard launcher, update checker, and clean process control.
"""

import os
import sys
import logging
import threading
import webbrowser
import subprocess
from PIL import Image, ImageDraw

try:
    import pystray
    from pystray import MenuItem, Menu
    PYSTRAY_AVAILABLE = True
except ImportError:
    PYSTRAY_AVAILABLE = False

try:
    import pyperclip
    PYPERCLIP_AVAILABLE = True
except ImportError:
    PYPERCLIP_AVAILABLE = False

logger = logging.getLogger("RemoteFlow.Tray")

class TrayManager:
    def __init__(self, primary_ip: str, http_port: int, on_exit_callback, on_restart_callback=None, on_show_gui_callback=None):
        self.primary_ip = primary_ip
        self.http_port = http_port
        self.on_exit = on_exit_callback
        self.on_restart = on_restart_callback
        self.on_show_gui = on_show_gui_callback
        self.icon = None
        self._running = False

    def show_control_center(self, icon=None, item=None):
        """Restores the main GUI Control Center window."""
        if self.on_show_gui:
            self.on_show_gui()

    def _get_icon_image(self) -> Image.Image:
        """Finds or dynamically generates the RemoteFlow Max glowing neon tray icon."""
        possible_paths = [
            os.path.join(os.path.dirname(os.path.abspath(__file__)), "tray_icon.png"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tray_icon.png"),
            os.path.join(os.path.dirname(sys.executable), "tray_icon.png"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "mobile_client", "assets", "app_icon.png"),
        ]
        for path in possible_paths:
            if os.path.exists(path):
                try:
                    img = Image.open(path).convert("RGBA")
                    return img.resize((64, 64), Image.Resampling.LANCZOS)
                except Exception as e:
                    logger.warning(f"Error loading tray icon from {path}: {e}")

        # Fallback: Generate a crisp neon RF icon dynamically
        img = Image.new("RGBA", (64, 64), (7, 11, 25, 255))
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle([4, 4, 60, 60], radius=16, fill=(15, 23, 42, 255), outline=(0, 229, 255, 255), width=2)
        draw.ellipse([20, 20, 44, 44], fill=(0, 229, 255, 200))
        return img

    def show_qr(self, icon=None, item=None):
        """Opens the dynamic browser QR code pairing dashboard."""
        url = f"http://127.0.0.1:{self.http_port}/"
        try:
            webbrowser.open(url)
            if self.icon:
                self.icon.notify(f"تم فتح لوحة الاقتران والـ QR Code:\n{url}", "RemoteFlow Max")
        except Exception as e:
            logger.error(f"Failed to open browser: {e}")

    def copy_ip(self, icon=None, item=None):
        """Copies host LAN IP to Windows clipboard."""
        if PYPERCLIP_AVAILABLE:
            try:
                pyperclip.copy(self.primary_ip)
            except Exception:
                pass
        if self.icon:
            self.icon.notify(f"تم نسخ عنوان الآي بي إلى الحافظة:\n{self.primary_ip}", "RemoteFlow Max")

    def check_updates(self, icon=None, item=None):
        """Displays update status and opens GitHub Releases page."""
        release_url = "https://github.com/Mohamed-maxX/RemoteFlow-Max/releases/latest"
        if self.icon:
            self.icon.notify("RemoteFlow Max v1.0.0\nفتح صفحة التحديثات الرسمية على GitHub...", "التحقق من التحديثات")
        try:
            webbrowser.open(release_url)
        except Exception:
            pass

    def restart(self, icon=None, item=None):
        """Restarts the host daemon."""
        if self.icon:
            self.icon.notify("جاري إعادة تشغيل السيرفر الآن...", "RemoteFlow Max")
        logger.info("Restart requested from tray.")
        if self.on_restart:
            self.on_restart()
        else:
            python = sys.executable
            if getattr(sys, 'frozen', False):
                subprocess.Popen([sys.executable] + sys.argv[1:])
            else:
                subprocess.Popen([python] + sys.argv)
            self.stop()

    def stop(self, icon=None, item=None):
        """Stops the tray icon and invokes the exit callback."""
        logger.info("Tray stop invoked.")
        self._running = False
        if self.icon:
            try:
                self.icon.stop()
            except Exception:
                pass
        if self.on_exit:
            self.on_exit()

    def start(self):
        """Starts the tray icon in detached mode (background thread)."""
        if not PYSTRAY_AVAILABLE:
            logger.warning("pystray not installed; skipping system tray.")
            return

        icon_img = self._get_icon_image()

        menu = Menu(
            MenuItem("🖥️ فتح لوحة التحكم", self.show_control_center, default=True),
            MenuItem("✨ فحص التحديثات", self.check_updates),
            Menu.SEPARATOR,
            MenuItem(f"🌐 نسخ الآي بي: {self.primary_ip}", self.copy_ip),
            MenuItem("📁 مجلد الملفات المستلمة", lambda: os.startfile(os.path.join(os.environ.get("USERPROFILE", ""), "Downloads", "RemoteFlow")) if os.path.exists(os.path.join(os.environ.get("USERPROFILE", ""), "Downloads", "RemoteFlow")) else None),
            MenuItem("🔄 إعادة تشغيل السيرفر", self.restart),
            Menu.SEPARATOR,
            MenuItem("❌ إغلاق البرنامج نهائياً", self.stop),
        )

        self.icon = pystray.Icon(
            "RemoteFlowMax",
            icon_img,
            f"RemoteFlow Max - {self.primary_ip}",
            menu=menu
        )
        self._running = True
        try:
            self.icon.run_detached()
            logger.info("System Tray Icon running in background.")
        except Exception as e:
            logger.error(f"Error starting pystray detached: {e}")
