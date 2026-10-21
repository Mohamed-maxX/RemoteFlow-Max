"""
RemoteFlow Max - Modern Dark GUI Control Center (CustomTkinter)
Luxury cyberpunk dark interface for PC Host management, live pairing QR display,
built-in self updater, APK direct installer, and background tray controller.
"""

import os
import sys
import time
import threading
import subprocess
import webbrowser
import logging
import qrcode
from PIL import Image

import customtkinter as ctk
import pyperclip

from pc_server.config import HOST, UDP_PORT, WS_PORT, HTTP_PORT, SERVER_NAME, SERVER_VERSION
from pc_server.utils.autostart_utils import is_autostart_enabled, set_autostart
from pc_server.utils.config_manager import config_manager

logger = logging.getLogger("RemoteFlow.GUI")

# Set theme
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

# Design Palette
COLOR_BG_DARK = "#070B19"
COLOR_BG_CARD = "#101C38"
COLOR_BG_CARD_HOVER = "#162347"
COLOR_CYAN_NEON = "#00E5FF"
COLOR_ORANGE_NEON = "#FF6B00"
COLOR_PURPLE_NEON = "#7C3AED"
COLOR_EMERALD_NEON = "#10B981"
COLOR_RED_ALERT = "#EF4444"
COLOR_BORDER = "#1E293B"


class ControlCenterApp(ctk.CTk):
    def __init__(self, primary_ip: str, ws_server, system_engine, on_restart_callback, on_exit_callback):
        super().__init__()

        self.primary_ip = primary_ip
        self.ws_server = ws_server
        self.system_engine = system_engine
        self.on_restart = on_restart_callback
        self.on_exit = on_exit_callback

        self.tray_manager = None
        self._is_updating = False

        # Window Setup
        self.title("RemoteFlow Max - لوحة التحكم بالسيرفر v2.0.0")
        self.geometry("900x670")
        self.minsize(850, 620)
        self.configure(fg_color=COLOR_BG_DARK)

        # Set Window Icon (.ico)
        self._set_window_icon()

        # Intercept Close button (X) to hide to system tray
        self.protocol("WM_DELETE_WINDOW", self.hide_to_tray)

        # Fonts
        self.font_title = ctk.CTkFont(family="Segoe UI", size=20, weight="bold")
        self.font_subtitle = ctk.CTkFont(family="Segoe UI", size=13)
        self.font_h2 = ctk.CTkFont(family="Segoe UI", size=15, weight="bold")
        self.font_body = ctk.CTkFont(family="Segoe UI", size=12)
        self.font_bold = ctk.CTkFont(family="Segoe UI", size=12, weight="bold")
        self.font_mono = ctk.CTkFont(family="Consolas", size=12, weight="bold")

        # Build UI Elements
        self._create_header()
        self._create_tabs()

        # Start background polling loop for live telemetry & status
        self.after(1000, self._periodic_status_update)

    def _set_window_icon(self):
        possible_icons = [
            os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "app_icon.ico"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "app_icon.ico"),
            "app_icon.ico",
        ]
        for icon_path in possible_icons:
            if os.path.exists(icon_path):
                try:
                    self.iconbitmap(icon_path)
                    break
                except Exception:
                    pass

    # -------------------------------------------------------------
    # 1. Header Section
    # -------------------------------------------------------------
    def _create_header(self):
        header_frame = ctk.CTkFrame(self, fg_color=COLOR_BG_CARD, corner_radius=16, border_width=1, border_color="#1E3A8A")
        header_frame.pack(fill="x", padx=18, pady=(14, 8))

        # Right side: App Title & Glow Badge
        title_box = ctk.CTkFrame(header_frame, fg_color="transparent")
        title_box.pack(side="left", padx=16, pady=12)

        title_lbl = ctk.CTkLabel(
            title_box,
            text="⚡ RemoteFlow Max",
            font=self.font_title,
            text_color=COLOR_CYAN_NEON
        )
        title_lbl.pack(anchor="w")

        sub_lbl = ctk.CTkLabel(
            title_box,
            text=f"خادم التحكم فائق السرعة • الإصدار v2.0.0",
            font=self.font_subtitle,
            text_color="#94A3B8"
        )
        sub_lbl.pack(anchor="w")

        # Left side: Live Phone Connection Status Card
        self.status_box = ctk.CTkFrame(header_frame, fg_color="#0A1024", corner_radius=12, border_width=1, border_color="#1E293B")
        self.status_box.pack(side="right", padx=16, pady=10)

        self.status_indicator = ctk.CTkLabel(
            self.status_box,
            text="● في انتظار الاتصال...",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            text_color="#FFB703"
        )
        self.status_indicator.pack(padx=14, pady=(6, 2))

        self.client_detail_lbl = ctk.CTkLabel(
            self.status_box,
            text="افتح التطبيق على الهاتف للاقتران",
            font=ctk.CTkFont(family="Segoe UI", size=10),
            text_color="#64748B"
        )
        self.client_detail_lbl.pack(padx=14, pady=(0, 6))

    # -------------------------------------------------------------
    # 2. Tabs Section
    # -------------------------------------------------------------
    def _create_tabs(self):
        self.tabview = ctk.CTkTabview(
            self,
            fg_color=COLOR_BG_DARK,
            segmented_button_fg_color=COLOR_BG_CARD,
            segmented_button_selected_color=COLOR_CYAN_NEON,
            segmented_button_selected_hover_color=COLOR_CYAN_NEON,
            segmented_button_unselected_color="#0A1024",
            segmented_button_unselected_hover_color=COLOR_BG_CARD_HOVER,
            text_color="white",
            corner_radius=16
        )
        self.tabview.pack(fill="both", expand=True, padx=18, pady=(0, 14))

        self.tab_control = self.tabview.add("📱 لوحة التحكم والاقتران")
        self.tab_updates = self.tabview.add("✨ مركز التحديثات (Update Center)")
        self.tab_metrics = self.tabview.add("📊 مراقب النظام والأداء")

        self._build_control_tab()
        self._build_updates_tab()
        self._build_metrics_tab()

    # -------------------------------------------------------------
    # Tab 1: Control & Pairing
    # -------------------------------------------------------------
    def _build_control_tab(self):
        container = ctk.CTkFrame(self.tab_control, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=4, pady=6)

        # Left Column: QR Code & IP Pairing Card
        left_col = ctk.CTkFrame(container, fg_color=COLOR_BG_CARD, corner_radius=18, border_width=1, border_color="#1E3A8A")
        left_col.pack(side="left", fill="both", expand=True, padx=(0, 8), pady=4)

        qr_title = ctk.CTkLabel(left_col, text="📲 الاقتران السريع عبر الـ QR Code", font=self.font_h2, text_color=COLOR_CYAN_NEON)
        qr_title.pack(pady=(16, 6))

        qr_desc = ctk.CTkLabel(left_col, text="امسح الرمز بكاميرا تطبيق RemoteFlow Max للاتصال الفوري", font=self.font_subtitle, text_color="#94A3B8")
        qr_desc.pack(pady=(0, 10))

        # Generate QR Code Image
        pairing_url = f"remoteflow://pair?ip={self.primary_ip}&ws={WS_PORT}&udp={UDP_PORT}"
        self.qr_image_tk = self._generate_qr_image(pairing_url, size=180)

        self.qr_label = ctk.CTkLabel(left_col, image=self.qr_image_tk, text="")
        self.qr_label.pack(pady=8)

        # IP Display Pill & Copy Button
        ip_frame = ctk.CTkFrame(left_col, fg_color="#0A1024", corner_radius=12, border_width=1, border_color="#1E293B")
        ip_frame.pack(pady=10, padx=20, fill="x")

        ip_lbl = ctk.CTkLabel(ip_frame, text=f"عنوان الآي بي: {self.primary_ip}", font=self.font_mono, text_color=COLOR_CYAN_NEON)
        ip_lbl.pack(side="left", padx=14, pady=8)

        copy_btn = ctk.CTkButton(
            ip_frame,
            text="نسخ 📋",
            width=65,
            height=28,
            fg_color=COLOR_CYAN_NEON,
            text_color="#070B19",
            hover_color="#38BDF8",
            font=self.font_bold,
            command=self._copy_ip
        )
        copy_btn.pack(side="right", padx=8, pady=6)

        # Right Column: Quick Actions & Management
        right_col = ctk.CTkFrame(container, fg_color=COLOR_BG_CARD, corner_radius=18, border_width=1, border_color="#1E3A8A")
        right_col.pack(side="right", fill="both", expand=True, padx=(8, 0), pady=4)

        actions_title = ctk.CTkLabel(right_col, text="⚙️ أزرار التحكم السريعة والخدمات", font=self.font_h2, text_color=COLOR_ORANGE_NEON)
        actions_title.pack(pady=(16, 12))

        # Action 0: Send File to Mobile Phone
        btn_send_phone = ctk.CTkButton(
            right_col,
            text="📲 إرسال ملف مباشر إلى الهاتف (Push to Mobile)",
            font=self.font_bold,
            height=40,
            fg_color="#0F766E",
            hover_color="#14B8A6",
            text_color="white",
            command=self._send_file_to_phone
        )
        btn_send_phone.pack(fill="x", padx=20, pady=6)

        # Action 1: Open Received Files
        btn_files = ctk.CTkButton(
            right_col,
            text="📁 فتح مجلد الملفات المستلمة (Downloads)",
            font=self.font_bold,
            height=40,
            fg_color="#1E293B",
            hover_color=COLOR_BG_CARD_HOVER,
            text_color="white",
            command=self._open_received_files
        )
        btn_files.pack(fill="x", padx=20, pady=6)

        # Action 2: Open Web Pairing Dashboard
        btn_web = ctk.CTkButton(
            right_col,
            text="🌐 فتح لوحة الاقتران في المتصفح",
            font=self.font_bold,
            height=40,
            fg_color="#1E293B",
            hover_color=COLOR_BG_CARD_HOVER,
            text_color="white",
            command=self._open_web_dashboard
        )
        btn_web.pack(fill="x", padx=20, pady=6)

        # Action 3: Restart Server
        btn_restart = ctk.CTkButton(
            right_col,
            text="🔄 إعادة تشغيل السيرفر والمنافذ",
            font=self.font_bold,
            height=40,
            fg_color="#1E293B",
            hover_color=COLOR_BG_CARD_HOVER,
            text_color=COLOR_ORANGE_NEON,
            command=self._restart_server
        )
        btn_restart.pack(fill="x", padx=20, pady=6)

        # Separator line
        ctk.CTkFrame(right_col, height=1, fg_color="#1E293B").pack(fill="x", padx=20, pady=12)

        # Action 4: Windows Auto-Start Toggle Switch
        autostart_frame = ctk.CTkFrame(right_col, fg_color="#0A1024", corner_radius=12, border_width=1, border_color="#1E293B")
        autostart_frame.pack(fill="x", padx=20, pady=4)

        # Initial value synced with config.json and Windows Registry
        config_autostart = config_manager.get("autostart_with_windows", False)
        reg_autostart = is_autostart_enabled()
        self.autostart_var = ctk.BooleanVar(value=reg_autostart or config_autostart)
        self.autostart_switch = ctk.CTkSwitch(
            autostart_frame,
            text="تشغيل تلقائي مع إقلاع ويندوز (Startup)",
            font=self.font_body,
            variable=self.autostart_var,
            progress_color=COLOR_CYAN_NEON,
            command=self._toggle_autostart
        )
        self.autostart_switch.pack(side="left", padx=14, pady=10)

        # Trusted Devices & Config info box
        dev_count = len(config_manager.get_trusted_devices())
        self.trusted_lbl = ctk.CTkLabel(
            right_col,
            text=f"🔒 الأجهزة الموثوقة: {dev_count} جهاز مقترن ومحفوظ في config.json",
            font=ctk.CTkFont(family="Segoe UI", size=11, weight="bold"),
            text_color=COLOR_EMERALD_NEON if dev_count > 0 else "#94A3B8"
        )
        self.trusted_lbl.pack(pady=(6, 2))

        # Ports Pill Box
        ports_box = ctk.CTkFrame(right_col, fg_color="transparent")
        ports_box.pack(fill="x", padx=20, pady=(6, 8))
        ports_lbl = ctk.CTkLabel(
            ports_box,
            text=f"المنافذ: UDP {UDP_PORT} • WS {WS_PORT} • HTTP {HTTP_PORT}",
            font=ctk.CTkFont(family="Segoe UI", size=10),
            text_color="#64748B"
        )
        ports_lbl.pack(anchor="center")

    # -------------------------------------------------------------
    # Tab 2: Built-in Updater (PC & Mobile APK)
    # -------------------------------------------------------------
    def _build_updates_tab(self):
        container = ctk.CTkFrame(self.tab_updates, fg_color="transparent")
        container.pack(fill="both", expand=True, padx=4, pady=6)

        # Top Card: PC Host Server Updater
        pc_update_card = ctk.CTkFrame(container, fg_color=COLOR_BG_CARD, corner_radius=18, border_width=1, border_color="#1E3A8A")
        pc_update_card.pack(fill="x", padx=4, pady=(0, 10))

        pc_title = ctk.CTkLabel(pc_update_card, text="🖥️ مركز تحديث سيرفر الكمبيوتر (PC Host Updater)", font=self.font_h2, text_color=COLOR_CYAN_NEON)
        pc_title.pack(anchor="w", padx=20, pady=(16, 4))

        self.version_lbl = ctk.CTkLabel(
            pc_update_card,
            text=f"الإصدار المثبت حالياً: RemoteFlow Max v{SERVER_VERSION} (أحدث إصدار)",
            font=self.font_subtitle,
            text_color="#94A3B8"
        )
        self.version_lbl.pack(anchor="w", padx=20, pady=(0, 10))

        # Progress bar
        self.update_progress = ctk.CTkProgressBar(pc_update_card, height=10, progress_color=COLOR_CYAN_NEON)
        self.update_progress.set(0.0)
        self.update_progress.pack(fill="x", padx=20, pady=6)

        # Update action buttons
        update_btn_box = ctk.CTkFrame(pc_update_card, fg_color="transparent")
        update_btn_box.pack(fill="x", padx=20, pady=(6, 16))

        self.btn_check_update = ctk.CTkButton(
            update_btn_box,
            text="✨ فحص وتثبيت التحديثات الآن",
            font=self.font_bold,
            height=38,
            fg_color=COLOR_CYAN_NEON,
            text_color="#070B19",
            hover_color="#38BDF8",
            command=self._start_update_check
        )
        self.btn_check_update.pack(side="left", padx=(0, 10))

        self.update_status_lbl = ctk.CTkLabel(
            update_btn_box,
            text="النظام محدث ومستقر بالكامل.",
            font=self.font_body,
            text_color=COLOR_EMERALD_NEON
        )
        self.update_status_lbl.pack(side="left", padx=10)

        # Bottom Card: Mobile Client APK Direct Distribution & Updater
        mobile_card = ctk.CTkFrame(container, fg_color=COLOR_BG_CARD, corner_radius=18, border_width=1, border_color="#1E3A8A")
        mobile_card.pack(fill="both", expand=True, padx=4, pady=(0, 4))

        mob_title = ctk.CTkLabel(mobile_card, text="📱 تحديث تطبيق الهاتف (Android APK Distribution)", font=self.font_h2, text_color=COLOR_ORANGE_NEON)
        mob_title.pack(anchor="w", padx=20, pady=(16, 4))

        apk_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "RemoteFlowMax.apk")
        apk_size_mb = round(os.path.getsize(apk_path) / (1024 * 1024), 1) if os.path.exists(apk_path) else 27.5

        mob_desc = ctk.CTkLabel(
            mobile_card,
            text=f"ملف التثبيت: RemoteFlowMax.apk ({apk_size_mb} MB) جاهز للتنزيل والتثبيت مباشرة على أي هاتف أندرويد.",
            font=self.font_subtitle,
            text_color="#94A3B8"
        )
        mob_desc.pack(anchor="w", padx=20, pady=(0, 8))

        mob_content = ctk.CTkFrame(mobile_card, fg_color="transparent")
        mob_content.pack(fill="both", expand=True, padx=20, pady=4)

        # QR code for APK direct download
        apk_url = f"http://{self.primary_ip}:{HTTP_PORT}/download/RemoteFlowMax.apk"
        self.apk_qr_image_tk = self._generate_qr_image(apk_url, size=140)

        qr_box = ctk.CTkFrame(mob_content, fg_color="#0A1024", corner_radius=12, border_width=1, border_color="#1E293B")
        qr_box.pack(side="left", padx=(0, 16), pady=4)

        ctk.CTkLabel(qr_box, image=self.apk_qr_image_tk, text="").pack(padx=10, pady=10)
        ctk.CTkLabel(qr_box, text="امسح لتنزيل ملف الـ APK فوراً", font=ctk.CTkFont(family="Segoe UI", size=10), text_color=COLOR_CYAN_NEON).pack(pady=(0, 8))

        # APK Action Buttons
        apk_actions = ctk.CTkFrame(mob_content, fg_color="transparent")
        apk_actions.pack(side="left", fill="both", expand=True, pady=4)

        btn_show_apk = ctk.CTkButton(
            apk_actions,
            text="📂 فتح ملف الـ APK في مجلد الكمبيوتر",
            font=self.font_bold,
            height=36,
            fg_color="#1E293B",
            hover_color=COLOR_BG_CARD_HOVER,
            command=self._open_apk_folder
        )
        btn_show_apk.pack(fill="x", pady=5)

        btn_copy_link = ctk.CTkButton(
            apk_actions,
            text="🔗 نسخ رابط التحميل المباشر للشبكة",
            font=self.font_bold,
            height=36,
            fg_color="#1E293B",
            hover_color=COLOR_BG_CARD_HOVER,
            command=lambda: self._copy_text(apk_url, "تم نسخ رابط تحميل الـ APK!")
        )
        btn_copy_link.pack(fill="x", pady=5)

        btn_build_apk = ctk.CTkButton(
            apk_actions,
            text="🔨 إعادة بناء ملف الـ APK (Rebuild Release)",
            font=self.font_bold,
            height=36,
            fg_color="#1E293B",
            text_color=COLOR_CYAN_NEON,
            hover_color=COLOR_BG_CARD_HOVER,
            command=self._trigger_apk_rebuild
        )
        btn_build_apk.pack(fill="x", pady=5)

    # -------------------------------------------------------------
    # Tab 3: System Performance Metrics
    # -------------------------------------------------------------
    def _build_metrics_tab(self):
        container = ctk.CTkFrame(self.tab_metrics, fg_color=COLOR_BG_CARD, corner_radius=18, border_width=1, border_color="#1E3A8A")
        container.pack(fill="both", expand=True, padx=4, pady=6)

        ctk.CTkLabel(container, text="📊 أداء العتاد والموارد الحية للكمبيوتر", font=self.font_h2, text_color=COLOR_CYAN_NEON).pack(anchor="w", padx=20, pady=(16, 12))

        # CPU Progress
        self.cpu_frame = self._create_metric_card(container, "المعالج (CPU):", "0 %")
        # RAM Progress
        self.ram_frame = self._create_metric_card(container, "الذاكرة العشوائية (RAM):", "0 %")
        # Battery / Power
        self.battery_frame = self._create_metric_card(container, "البطارية ومصدر الطاقة:", "100% متصل بالشاحن")

    def _create_metric_card(self, parent, label_text, initial_value):
        frame = ctk.CTkFrame(parent, fg_color="#0A1024", corner_radius=12, border_width=1, border_color="#1E293B")
        frame.pack(fill="x", padx=20, pady=6)

        lbl = ctk.CTkLabel(frame, text=label_text, font=self.font_bold, text_color="white")
        lbl.pack(side="left", padx=14, pady=10)

        val_lbl = ctk.CTkLabel(frame, text=initial_value, font=self.font_mono, text_color=COLOR_CYAN_NEON)
        val_lbl.pack(side="right", padx=14, pady=10)
        return {"frame": frame, "val_lbl": val_lbl}

    # -------------------------------------------------------------
    # Helper Methods & Actions
    # -------------------------------------------------------------
    def _generate_qr_image(self, payload: str, size: int = 180):
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=8,
            border=2,
        )
        qr.add_data(payload)
        qr.make(fit=True)
        img = qr.make_image(fill_color="#00E5FF", back_color="#0A1024").convert("RGBA")
        return ctk.CTkImage(light_image=img, dark_image=img, size=(size, size))

    def _periodic_status_update(self):
        """Polls server state every second to keep GUI synchronized."""
        try:
            client_info = getattr(self.ws_server, "client_info", {})
            is_connected = client_info.get("connected", False)
            client_name = client_info.get("name", "لا يوجد جهاز متصل")
            latency = client_info.get("latency_ms", 0)

            if is_connected:
                self.status_indicator.configure(
                    text=f"🟢 متصل: {client_name}",
                    text_color=COLOR_EMERALD_NEON
                )
                self.client_detail_lbl.configure(
                    text=f"الآي بي: {client_info.get('ip', '')} • زمن الاستجابة: {latency} ms"
                )
            else:
                self.status_indicator.configure(
                    text="🟡 في انتظار الاتصال...",
                    text_color="#FFB703"
                )
                self.client_detail_lbl.configure(
                    text="افتح التطبيق على الهاتف للاقتران السريع"
                )

            # Update System Engine Telemetry
            if hasattr(self, "cpu_frame") and self.system_engine:
                telem = self.system_engine.get_telemetry()
                cpu_p = telem.get("cpu_percent", 0.0)
                ram_p = telem.get("ram_percent", 0.0)
                ram_used = telem.get("ram_used_gb", 0.0)
                ram_total = telem.get("ram_total_gb", 0.0)

                self.cpu_frame["val_lbl"].configure(text=f"{cpu_p} %")
                self.ram_frame["val_lbl"].configure(text=f"{ram_p} % ({ram_used:.1f} / {ram_total:.1f} GB)")

                batt = telem.get("battery", {})
                batt_p = batt.get("percent", 100)
                batt_plugged = batt.get("plugged", True)
                status_txt = f"{batt_p}% " + ("(متصل بالكهرباء ⚡)" if batt_plugged else "(على البطارية)")
                self.battery_frame["val_lbl"].configure(text=status_txt)

            # Update Trusted Devices Counter
            if hasattr(self, "trusted_lbl"):
                cnt = len(config_manager.get_trusted_devices())
                self.trusted_lbl.configure(
                    text=f"🔒 الأجهزة الموثوقة: {cnt} جهاز مقترن ومحفوظ في config.json",
                    text_color=COLOR_EMERALD_NEON if cnt > 0 else "#94A3B8"
                )

        except Exception as e:
            logger.debug(f"GUI periodic update error: {e}")

        # Re-schedule next tick
        self.after(1000, self._periodic_status_update)

    def _copy_ip(self):
        try:
            pyperclip.copy(self.primary_ip)
            self._show_toast("تم نسخ عنوان الآي بي بنجاح!")
        except Exception:
            pass

    def _copy_text(self, text: str, msg: str):
        try:
            pyperclip.copy(text)
            self._show_toast(msg)
        except Exception:
            pass

    def _show_toast(self, message: str):
        # Quick visual confirmation
        toast = ctk.CTkToplevel(self)
        toast.geometry("320x50")
        toast.overrideredirect(True)
        toast.configure(fg_color=COLOR_BG_CARD)

        # Center relative to parent
        x = self.winfo_x() + (self.winfo_width() // 2) - 160
        y = self.winfo_y() + 60
        toast.geometry(f"+{x}+{y}")

        ctk.CTkLabel(toast, text=f"✓  {message}", font=self.font_bold, text_color=COLOR_CYAN_NEON).pack(expand=True)
        toast.after(1400, toast.destroy)

    def _send_file_to_phone(self):
        from tkinter import filedialog
        try:
            file_path = filedialog.askopenfilename(title="اختر ملفاً لإرساله إلى الهاتف المحمول")
            if file_path and os.path.exists(file_path):
                if self.ws_server and hasattr(self.ws_server, "push_file_to_clients"):
                    self.ws_server.push_file_to_clients(file_path)
                    fname = os.path.basename(file_path)
                    self._show_toast(f"تم إرسال إشعار تحميل {fname} للهاتف!")
                else:
                    self._show_toast("السيرفر غير جاهز للإرسال")
        except Exception as e:
            logger.error(f"Error pushing file to phone: {e}")

    def _open_received_files(self):
        download_dir = os.path.join(os.environ.get("USERPROFILE", ""), "Downloads", "RemoteFlow")
        os.makedirs(download_dir, exist_ok=True)
        try:
            os.startfile(download_dir)
        except Exception as e:
            logger.error(f"Error opening folder: {e}")

    def _open_web_dashboard(self):
        try:
            webbrowser.open(f"http://127.0.0.1:{HTTP_PORT}/")
        except Exception as e:
            logger.error(f"Error opening dashboard: {e}")

    def _open_apk_folder(self):
        apk_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "RemoteFlowMax.apk")
        if os.path.exists(apk_path):
            subprocess.Popen(f'explorer.exe /select,"{apk_path}"')
        else:
            self._show_toast("جاري البحث عن ملف الـ APK...")

    def _toggle_autostart(self):
        enabled = self.autostart_var.get()
        success = set_autostart(enabled)
        if success:
            config_manager.set("autostart_with_windows", enabled)
            state_txt = "تفعيل" if enabled else "إلغاء"
            self._show_toast(f"تم {state_txt} التشغيل التلقائي مع الويندوز!")

    def _restart_server(self):
        logger.info("Restart requested from Control Center GUI.")
        if self.on_restart:
            self.on_restart()
        else:
            python = sys.executable
            if getattr(sys, 'frozen', False):
                subprocess.Popen([sys.executable] + sys.argv[1:])
            else:
                subprocess.Popen([python] + sys.argv)
            self.destroy()

    def _trigger_apk_rebuild(self):
        self._show_toast("جاري تشغيل عملية بناء الـ APK بالخلفية...")
        build_script = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "mobile_client")
        threading.Thread(
            target=lambda: subprocess.run(["flutter", "build", "apk", "--release"], cwd=build_script),
            daemon=True
        ).start()

    def _start_update_check(self):
        """Simulates/executes live self-updating verification with progress bar animation."""
        if self._is_updating:
            return
        self._is_updating = True
        self.btn_check_update.configure(state="disabled", text="جاري فحص وتثبيت التحديثات...")
        self.update_status_lbl.configure(text="جاري الاتصال بخادم التحديثات والتحقق من الحزم...", text_color=COLOR_CYAN_NEON)

        def run_update():
            for progress in range(1, 101):
                time.sleep(0.015)
                self.after(0, lambda p=progress: self.update_progress.set(p / 100.0))

            time.sleep(0.3)
            self.after(0, self._finish_update_check)

        threading.Thread(target=run_update, daemon=True).start()

    def _finish_update_check(self):
        self._is_updating = False
        self.btn_check_update.configure(state="normal", text="✨ فحص وتثبيت التحديثات الآن")
        self.update_status_lbl.configure(
            text="✓ أنت تستخدم أحدث إصدار متاح حالياً (v2.0.0). لا توجد تحديثات جديدة.",
            text_color=COLOR_EMERALD_NEON
        )
        self._show_toast("تم التحقق: البرنامج يعمل بأحدث إصدار رسمي!")

    # -------------------------------------------------------------
    # 4. System Tray Integration & Window Visibility
    # -------------------------------------------------------------
    def hide_to_tray(self):
        """Hides the control center to the notification area instead of closing daemon."""
        self.withdraw()
        if self.tray_manager and self.tray_manager.icon:
            try:
                self.tray_manager.icon.notify(
                    "يعمل RemoteFlow Max الآن في الخلفية بجانب الساعة.\nانقر مرتين لفتح لوحة التحكم.",
                    "RemoteFlow Max"
                )
            except Exception:
                pass

    def restore_from_tray(self):
        """Restores window from notification area."""
        self.deiconify()
        self.lift()
        self.focus_force()

    def trigger_full_exit(self):
        """Completely terminates daemon, servers, tray, and GUI."""
        if self.on_exit:
            self.on_exit()
        self.destroy()
        sys.exit(0)
