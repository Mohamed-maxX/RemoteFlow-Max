"""
RemoteFlow Max - Asynchronous HTTP File Management, Web Pairing & Transfer Server
Provides remote file browsing, opening, deleting, downloading, and Quick File Drop uploads over Wi-Fi.
Also handles direct URL opening in host browser, web pairing dashboard, in-app updates, and APK distribution.
"""

import os
import sys
import io
import json
import string
import logging
import webbrowser
import asyncio
import aiohttp
from aiohttp import web
from typing import Optional
import qrcode
from qrcode.image.pil import PilImage

from pc_server.config import HTTP_PORT, WS_PORT, UDP_PORT, SERVER_NAME, SERVER_VERSION
from pc_server.core.screen_engine import ScreenEngine
from pc_server.utils.net_utils import get_primary_local_ip
from pc_server.utils.live_ui_manager import live_ui_manager

logger = logging.getLogger("RemoteFlow.HTTPServer")

class HTTPServer:
    def __init__(self, host: str, port: int = HTTP_PORT, screen_engine: Optional[ScreenEngine] = None, primary_ip: Optional[str] = None):
        self.host = host
        self.port = port
        self.primary_ip = primary_ip or get_primary_local_ip()
        self.screen_engine = screen_engine or ScreenEngine()
        self.app = web.Application(client_max_size=1024 * 1024 * 500)  # 500MB max upload
        self.runner: Optional[web.AppRunner] = None
        self._setup_routes()

    def _setup_routes(self):
        # Web PWA & Static Routes
        self.app.router.add_get("/", self.handle_index)
        self.app.router.add_get("/manifest.json", self.handle_manifest)
        self.app.router.add_get("/sw.js", self.handle_sw)
        self.app.router.add_get("/api/qr", self.handle_qr_png)
        self.app.router.add_get("/api/version", self.handle_version)
        self.app.router.add_get("/api/update/check", self.handle_update_check)
        self.app.router.add_get("/api/update/latest.apk", self.handle_download_apk)
        self.app.router.add_get("/download/RemoteFlowMax.apk", self.handle_download_apk)
        self.app.router.add_get("/RemoteFlowMax.apk", self.handle_download_apk)

        # Live UI Hot-Reload APIs
        self.app.router.add_get("/api/live_ui/config", self.handle_live_ui_config)
        self.app.router.add_post("/api/live_ui/update", self.handle_live_ui_update)

        # Core APIs
        self.app.router.add_get("/api/status", self.handle_status)
        self.app.router.add_get("/api/files/browse", self.handle_browse)
        self.app.router.add_post("/api/files/open", self.handle_open)
        self.app.router.add_post("/api/files/delete", self.handle_delete)
        self.app.router.add_post("/api/files/upload", self.handle_upload)
        self.app.router.add_get("/api/files/download", self.handle_download)
        self.app.router.add_post("/api/files/open_url", self.handle_open_url)

        # Screen Streaming & Screenshots
        self.app.router.add_get("/api/stream/mjpeg", self.handle_mjpeg_stream)
        self.app.router.add_get("/api/stream/screenshot", self.handle_screenshot)

    def _find_apk_path(self) -> Optional[str]:
        if os.path.exists(live_ui_manager.apk_path):
            return live_ui_manager.apk_path
        possible = [
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "RemoteFlowMax.apk"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "RemoteFlowMax.apk"),
            os.path.join(os.getcwd(), "RemoteFlowMax.apk"),
            r"G:\RemoteFlow Max\RemoteFlowMax.apk",
        ]
        for p in possible:
            if os.path.exists(p):
                return p
        return None

    def _get_web_dir(self) -> str:
        candidates = []
        if getattr(sys, 'frozen', False):
            exe_dir = os.path.dirname(sys.executable)
            candidates.extend([
                os.path.join(exe_dir, "pc_server", "web"),
                os.path.join(exe_dir, "web"),
                os.path.join(getattr(sys, '_MEIPASS', ''), "pc_server", "web"),
                os.path.join(getattr(sys, '_MEIPASS', ''), "web"),
            ])
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        candidates.extend([
            os.path.join(base_dir, "web"),
            os.path.join(os.path.dirname(base_dir), "pc_server", "web"),
            r"G:\RemoteFlow Max\pc_server\web"
        ])
        for c in candidates:
            if c and os.path.exists(c):
                return c
        return os.path.join(base_dir, "web")

    async def handle_manifest(self, request: web.Request) -> web.Response:
        web_dir = self._get_web_dir()
        p = os.path.join(web_dir, "manifest.json")
        if os.path.exists(p):
            return web.FileResponse(p, headers={"Content-Type": "application/manifest+json; charset=utf-8"})
        return web.Response(text="{}", content_type="application/json")

    async def handle_sw(self, request: web.Request) -> web.Response:
        web_dir = self._get_web_dir()
        p = os.path.join(web_dir, "sw.js")
        if os.path.exists(p):
            return web.FileResponse(p, headers={"Content-Type": "application/javascript; charset=utf-8"})
        return web.Response(text="// empty sw", content_type="application/javascript")

    async def handle_update_check(self, request: web.Request) -> web.Response:
        meta = live_ui_manager.get_apk_metadata()
        return web.json_response({
            "app": SERVER_NAME,
            "version": SERVER_VERSION,
            "available": meta["available"],
            "size": meta["size"],
            "size_mb": meta["size_mb"],
            "hash": meta["hash"],
            "timestamp": meta["timestamp"],
            "download_url": f"http://{self.primary_ip}:{self.port}/api/update/latest.apk",
            "release_notes": "تحديث برمجي فوري متاح لـ RemoteFlow Max (Zero-Touch In-App OTA)"
        })

    async def handle_live_ui_config(self, request: web.Request) -> web.Response:
        config = live_ui_manager.load_config()
        return web.json_response(config)

    async def handle_live_ui_update(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            if not isinstance(data, dict):
                return web.json_response({"error": "Invalid payload"}, status=400)
            success = live_ui_manager.save_config(data)
            return web.json_response({"status": "saved" if success else "failed"})
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    async def handle_version(self, request: web.Request) -> web.Response:
        apk_path = self._find_apk_path()
        apk_size = os.path.getsize(apk_path) if apk_path else 0
        return web.json_response({
            "app": SERVER_NAME,
            "version": SERVER_VERSION,
            "version_code": 3,
            "apk_available": apk_path is not None,
            "apk_size": apk_size,
            "download_url": f"http://{self.primary_ip}:{self.port}/api/update/latest.apk",
            "release_notes": "تحديث فوري: نظام التحديث المباشر Live UI بدون APK، وتطبيق الويب PWA، وتحديثات OTA بنقرة واحدة.",
        })

    async def handle_download_apk(self, request: web.Request) -> web.StreamResponse:
        apk_path = self._find_apk_path()
        if not apk_path:
            return web.Response(text="APK file not found on host. Please build the APK first.", status=404)
        return web.FileResponse(
            apk_path,
            chunk_size=1024 * 512,
            headers={
                "Content-Type": "application/vnd.android.package-archive",
                "Content-Disposition": 'attachment; filename="RemoteFlowMax.apk"',
            }
        )

    async def handle_qr_png(self, request: web.Request) -> web.Response:
        payload = json.dumps({
            "type": "remoteflow_pairing",
            "name": SERVER_NAME,
            "ip": self.primary_ip,
            "ws_port": WS_PORT,
            "udp_port": UDP_PORT,
            "http_port": self.port,
            "v": SERVER_VERSION
        })
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=2,
        )
        qr.add_data(payload)
        qr.make(fit=True)
        img = qr.make_image(fill_color="#00E5FF", back_color="#070B19")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return web.Response(body=buf.getvalue(), content_type="image/png")

    async def handle_index(self, request: web.Request) -> web.Response:
        web_dir = self._get_web_dir()
        pwa_path = os.path.join(web_dir, "index.html")
        if os.path.exists(pwa_path):
            return web.FileResponse(pwa_path, headers={"Content-Type": "text/html; charset=utf-8"})

        apk_path = self._find_apk_path()
        apk_status = "جاهز للتحميل" if apk_path else "جاري البناء"
        html = f"""<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{SERVER_NAME} v{SERVER_VERSION} - لوحة التحكم والاقتران</title>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&display=swap" rel="stylesheet">
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; font-family: 'Cairo', sans-serif; }}
        body {{
            background: linear-gradient(135deg, #070B19 0%, #0A1024 50%, #0F172A 100%);
            color: #F8FAFC;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }}
        .card {{
            background: rgba(17, 28, 53, 0.85);
            backdrop-filter: blur(20px);
            border: 1px solid rgba(0, 229, 255, 0.3);
            border-radius: 28px;
            padding: 36px;
            max-width: 520px;
            width: 100%;
            text-align: center;
            box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6), 0 0 30px rgba(0, 229, 255, 0.15);
        }}
        .badge {{
            display: inline-block;
            background: rgba(0, 229, 255, 0.12);
            color: #00E5FF;
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 12px;
            border: 1px solid rgba(0, 229, 255, 0.4);
        }}
        h1 {{
            font-size: 26px;
            font-weight: 900;
            margin-bottom: 6px;
            letter-spacing: 1px;
        }}
        h1 span {{ color: #FF6B00; }}
        p.subtitle {{
            color: #94A3B8;
            font-size: 13px;
            margin-bottom: 24px;
        }}
        .qr-container {{
            background: #070B19;
            padding: 16px;
            border-radius: 22px;
            border: 2px solid rgba(0, 229, 255, 0.4);
            display: inline-block;
            box-shadow: 0 0 25px rgba(0, 229, 255, 0.2);
            margin-bottom: 20px;
        }}
        .qr-container img {{
            display: block;
            width: 220px;
            height: 220px;
            border-radius: 12px;
        }}
        .info-grid {{
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 10px;
            margin-bottom: 24px;
            text-align: right;
        }}
        .info-box {{
            background: rgba(30, 41, 59, 0.6);
            padding: 10px 14px;
            border-radius: 14px;
            border: 1px solid rgba(255, 255, 255, 0.08);
        }}
        .info-label {{ font-size: 11px; color: #64748B; font-weight: 600; }}
        .info-val {{ font-size: 14px; font-weight: 700; color: #00E5FF; direction: ltr; text-align: left; }}
        .btn {{
            display: block;
            width: 100%;
            background: linear-gradient(135deg, #00E5FF 0%, #7C3AED 100%);
            color: #070B19;
            text-decoration: none;
            padding: 14px;
            border-radius: 16px;
            font-weight: 900;
            font-size: 15px;
            transition: all 0.2s ease;
            box-shadow: 0 8px 25px rgba(0, 229, 255, 0.35);
        }}
        .btn:hover {{
            transform: translateY(-2px);
            box-shadow: 0 12px 30px rgba(0, 229, 255, 0.5);
            color: #fff;
        }}
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">⚡ السيرفر متصل ويعمل بنشاط</div>
        <h1>{SERVER_NAME} <span>v{SERVER_VERSION}</span></h1>
        <p class="subtitle">امسح الباركود بهاتفك للاقتران الفوري عبر شبكة الواي فاي</p>
        
        <div class="qr-container">
            <img src="/api/qr" alt="QR Pairing Code">
        </div>

        <div class="info-grid">
            <div class="info-box">
                <div class="info-label">عنوان الآي بي (IP)</div>
                <div class="info-val">{self.primary_ip}</div>
            </div>
            <div class="info-box">
                <div class="info-label">منفذ WebSocket</div>
                <div class="info-val">{WS_PORT}</div>
            </div>
            <div class="info-box">
                <div class="info-label">منفذ اللمس UDP</div>
                <div class="info-val">{UDP_PORT}</div>
            </div>
            <div class="info-box">
                <div class="info-label">ملف التطبيق APK</div>
                <div class="info-val" style="color: #10B981;">{apk_status}</div>
            </div>
        </div>

        <a class="btn" href="/download/RemoteFlowMax.apk" download>
            📲 تنزيل وتثبيت تطبيق الأندرويد (APK)
        </a>
    </div>
</body>
</html>
"""
        return web.Response(text=html, content_type="text/html", charset="utf-8")

    async def handle_screenshot(self, request: web.Request) -> web.Response:
        """Instant Screen Grab: Returns full-res JPEG screenshot."""
        jpeg_bytes = self.screen_engine.capture_full_screenshot_jpeg()
        return web.Response(body=jpeg_bytes, content_type="image/jpeg")

    async def handle_mjpeg_stream(self, request: web.Request) -> web.StreamResponse:
        """Low-Latency Screen Mirror Preview: Multipart MJPEG video stream."""
        response = web.StreamResponse(
            status=200,
            reason="OK",
            headers={"Content-Type": "multipart/x-mixed-replace; boundary=--frame"}
        )
        await response.prepare(request)

        try:
            while True:
                jpeg_bytes = self.screen_engine.capture_frame_jpeg(quality=50, target_width=800)
                await response.write(
                    b"----frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n" + jpeg_bytes + b"\r\n"
                )
                await asyncio.sleep(0.033)
        except (asyncio.CancelledError, ConnectionResetError):
            pass
        return response

    async def handle_status(self, request: web.Request) -> web.Response:
        return web.json_response({
            "app": SERVER_NAME,
            "version": SERVER_VERSION,
            "status": "online",
            "primary_ip": self.primary_ip,
            "http_port": self.port,
            "ws_port": WS_PORT,
            "udp_port": UDP_PORT,
        })

    async def handle_browse(self, request: web.Request) -> web.Response:
        target_path = request.query.get("path", "").strip()

        if not target_path:
            drives = []
            for d in string.ascii_uppercase:
                drive_str = f"{d}:\\"
                if os.path.exists(drive_str):
                    drives.append({
                        "name": f"Local Disk ({d}:)",
                        "path": drive_str,
                        "is_dir": True,
                        "size": 0,
                        "ext": "drive"
                    })
            downloads_dir = os.path.join(os.path.expanduser("~"), "Downloads")
            return web.json_response({
                "current_path": "",
                "parent_path": "",
                "downloads_path": downloads_dir,
                "items": drives
            })

        if not os.path.exists(target_path):
            return web.json_response({"error": "Path not found"}, status=404)

        try:
            items = []
            with os.scandir(target_path) as entries:
                for entry in entries:
                    try:
                        is_dir = entry.is_dir(follow_symlinks=False)
                        stat = entry.stat()
                        size = stat.st_size if not is_dir else 0
                        _, ext = os.path.splitext(entry.name)

                        items.append({
                            "name": entry.name,
                            "path": entry.path,
                            "is_dir": is_dir,
                            "size": size,
                            "modified": int(stat.st_mtime * 1000),
                            "ext": ext.lower().replace(".", "") if ext else ("folder" if is_dir else "")
                        })
                    except (PermissionError, OSError):
                        continue

            items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
            parent_path = os.path.dirname(os.path.abspath(target_path))
            if parent_path == target_path:
                parent_path = ""

            return web.json_response({
                "current_path": target_path,
                "parent_path": parent_path,
                "items": items
            })
        except Exception as e:
            logger.warning(f"[HTTP] Error browsing {target_path}: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def handle_open(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            target_path = data.get("path", "").strip()
            if not target_path or not os.path.exists(target_path):
                return web.json_response({"error": "File or path not found"}, status=404)

            os.startfile(target_path)
            logger.info(f"[HTTP] Opened host file: {target_path}")
            return web.json_response({"status": "opened", "path": target_path})
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    async def handle_delete(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            target_path = data.get("path", "").strip()
            if not target_path or not os.path.exists(target_path):
                return web.json_response({"error": "Path not found"}, status=404)

            if os.path.isdir(target_path):
                os.rmdir(target_path)
            else:
                os.remove(target_path)

            logger.info(f"[HTTP] Deleted host file: {target_path}")
            return web.json_response({"status": "deleted", "path": target_path})
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    async def handle_upload(self, request: web.Request) -> web.Response:
        import urllib.parse
        try:
            reader = await request.multipart()
            dest_query = request.query.get("dest")
            if dest_query:
                dest_dir = urllib.parse.unquote(dest_query).strip()
            else:
                dest_dir = os.path.join(os.environ.get("USERPROFILE", os.path.expanduser("~")), "Downloads", "RemoteFlow")
            os.makedirs(dest_dir, exist_ok=True)

            uploaded_files = []
            while True:
                part = await reader.next()
                if part is None:
                    break

                if part.filename:
                    filename = os.path.basename(part.filename)
                    out_path = os.path.join(dest_dir, filename)

                    size = 0
                    with open(out_path, "wb") as f:
                        while True:
                            chunk = await part.read_chunk(1024 * 512)
                            if not chunk:
                                break
                            f.write(chunk)
                            size += len(chunk)

                    logger.info(f"[HTTP] Received mobile upload: {out_path} ({size} bytes)")
                    uploaded_files.append({"filename": filename, "path": out_path, "size": size})

            return web.json_response({"status": "success", "files": uploaded_files})
        except Exception as e:
            logger.warning(f"[HTTP] File upload error: {e}")
            return web.json_response({"error": str(e)}, status=500)

    async def handle_download(self, request: web.Request) -> web.StreamResponse:
        import urllib.parse
        target_path = request.query.get("path", "").strip()
        if not target_path:
            return web.Response(text="No file path provided", status=400)

        target_path = urllib.parse.unquote(target_path)
        if not os.path.exists(target_path) or os.path.isdir(target_path):
            return web.Response(text="File not found", status=404)

        filename = os.path.basename(target_path)
        file_size = os.path.getsize(target_path)
        logger.info(f"[HTTP] Streaming download of {filename} ({file_size} bytes) at high speed")

        return web.FileResponse(
            target_path,
            chunk_size=1024 * 512,  # 512 KB streaming buffer for high Wi-Fi throughput
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "Content-Length": str(file_size),
                "Accept-Ranges": "bytes",
                "Cache-Control": "no-cache",
            }
        )

    async def handle_open_url(self, request: web.Request) -> web.Response:
        try:
            data = await request.json()
            url = data.get("url", "").strip()
            if not url:
                return web.json_response({"error": "No URL provided"}, status=400)

            if not (url.startswith("http://") or url.startswith("https://")):
                url = "https://" + url

            webbrowser.open(url)
            logger.info(f"[HTTP] Direct Link Injector opened URL: {url}")
            return web.json_response({"status": "opened", "url": url})
        except Exception as e:
            return web.json_response({"error": str(e)}, status=500)

    async def start(self):
        self.runner = web.AppRunner(self.app)
        await self.runner.setup()
        site = web.TCPSite(self.runner, self.host, self.port)
        await site.start()
        logger.info(f"[HTTP] File Explorer, Web Pairing & Download API listening on http://{self.host}:{self.port}")

    async def stop(self):
        if self.runner:
            await self.runner.cleanup()
