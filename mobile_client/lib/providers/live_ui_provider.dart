import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/packet.dart';
import 'connection_provider.dart';
import 'touchpad_settings_provider.dart';

Color _parseHex(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    String clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    return Color(int.parse(clean, radix: 16));
  } catch (_) {
    return fallback;
  }
}

class LiveThemeConfig {
  final String activeMode;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryAccent;
  final Color bgDark;
  final Color cardColor;
  final double glowIntensity;

  const LiveThemeConfig({
    this.activeMode = 'cinematicNeon',
    this.primaryColor = const Color(0xFF00E5FF),
    this.accentColor = const Color(0xFF7C3AED),
    this.secondaryAccent = const Color(0xFFFF6B00),
    this.bgDark = const Color(0xFF050814),
    this.cardColor = const Color(0x33101C38),
    this.glowIntensity = 1.0,
  });

  factory LiveThemeConfig.fromJson(Map<String, dynamic> json) {
    return LiveThemeConfig(
      activeMode: json['active_mode'] as String? ?? 'cinematicNeon',
      primaryColor: _parseHex(json['primary_color'] as String?, const Color(0xFF00E5FF)),
      accentColor: _parseHex(json['accent_color'] as String?, const Color(0xFF7C3AED)),
      secondaryAccent: _parseHex(json['secondary_accent'] as String?, const Color(0xFFFF6B00)),
      bgDark: _parseHex(json['bg_dark'] as String?, const Color(0xFF050814)),
      cardColor: _parseHex(json['card_color'] as String?, const Color(0x33101C38)),
      glowIntensity: (json['glow_intensity'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class LiveTouchpadConfig {
  final double sensitivity;
  final String mode;
  final double scrollSpeed;
  final bool invertScroll;
  final bool tapToClick;
  final bool hapticsEnabled;
  final bool swapMouseButtons;
  final bool showScrollStrip;
  final String guideTextMain;
  final String guideTextSub;

  const LiveTouchpadConfig({
    this.sensitivity = 1.0,
    this.mode = 'normal',
    this.scrollSpeed = 2.2,
    this.invertScroll = false,
    this.tapToClick = true,
    this.hapticsEnabled = true,
    this.swapMouseButtons = false,
    this.showScrollStrip = true,
    this.guideTextMain = 'لوحة لمس فائقة الدقة 120Hz',
    this.guideTextSub = 'لمسة = كليك شمال • لمستين = كليك يمين • سحب بإصبعين = تمرير',
  });

  factory LiveTouchpadConfig.fromJson(Map<String, dynamic> json) {
    return LiveTouchpadConfig(
      sensitivity: (json['sensitivity'] as num?)?.toDouble() ?? 1.0,
      mode: json['mode'] as String? ?? 'normal',
      scrollSpeed: (json['scroll_speed'] as num?)?.toDouble() ?? 2.2,
      invertScroll: json['invert_scroll'] as bool? ?? false,
      tapToClick: json['tap_to_click'] as bool? ?? true,
      hapticsEnabled: json['haptics_enabled'] as bool? ?? true,
      swapMouseButtons: json['swap_mouse_buttons'] as bool? ?? false,
      showScrollStrip: json['show_scroll_strip'] as bool? ?? true,
      guideTextMain: json['guide_text_main'] as String? ?? 'لوحة لمس فائقة الدقة 120Hz',
      guideTextSub: json['guide_text_sub'] as String? ?? 'لمسة = كليك شمال • لمستين = كليك يمين • سحب بإصبعين = تمرير',
    );
  }
}

class QuickActionItem {
  final String id;
  final String label;
  final String icon;
  final Color color;
  final bool visible;

  const QuickActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.visible = true,
  });

  factory QuickActionItem.fromJson(Map<String, dynamic> json) {
    return QuickActionItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? 'touch_app',
      color: _parseHex(json['color'] as String?, const Color(0xFF00E5FF)),
      visible: json['visible'] as bool? ?? true,
    );
  }
}

class LiveButtonLayout {
  final String leftButtonLabel;
  final String leftButtonSubtitle;
  final String rightButtonLabel;
  final String rightButtonSubtitle;
  final String scrollButtonLabel;
  final List<QuickActionItem> quickActions;

  const LiveButtonLayout({
    this.leftButtonLabel = 'كليك شمال',
    this.leftButtonSubtitle = 'الأساسي',
    this.rightButtonLabel = 'كليك يمين',
    this.rightButtonSubtitle = 'القائمة',
    this.scrollButtonLabel = 'تمرير',
    this.quickActions = const [],
  });

  factory LiveButtonLayout.fromJson(Map<String, dynamic> json) {
    final actionsList = (json['quick_actions'] as List<dynamic>?)
            ?.map((e) => QuickActionItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return LiveButtonLayout(
      leftButtonLabel: json['left_button_label'] as String? ?? 'كليك شمال',
      leftButtonSubtitle: json['left_button_subtitle'] as String? ?? 'الأساسي',
      rightButtonLabel: json['right_button_label'] as String? ?? 'كليك يمين',
      rightButtonSubtitle: json['right_button_subtitle'] as String? ?? 'القائمة',
      scrollButtonLabel: json['scroll_button_label'] as String? ?? 'تمرير',
      quickActions: actionsList,
    );
  }
}

class LiveMacroButtonItem {
  final String id;
  final String label;
  final String icon;
  final Color color;
  final String action;
  final dynamic param;

  const LiveMacroButtonItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
    this.param,
  });

  factory LiveMacroButtonItem.fromJson(Map<String, dynamic> json) {
    return LiveMacroButtonItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: json['icon'] as String? ?? 'bolt',
      color: _parseHex(json['color'] as String?, const Color(0xFF00E5FF)),
      action: json['action'] as String? ?? 'hotkey',
      param: json['param'],
    );
  }
}

class LiveMacroDeck {
  final String title;
  final List<LiveMacroButtonItem> buttons;

  const LiveMacroDeck({
    this.title = 'وحدة التحكم السريعة والماكرو',
    this.buttons = const [],
  });

  factory LiveMacroDeck.fromJson(Map<String, dynamic> json) {
    final bList = (json['buttons'] as List<dynamic>?)
            ?.map((e) => LiveMacroButtonItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return LiveMacroDeck(
      title: json['title'] as String? ?? 'وحدة التحكم السريعة والماكرو',
      buttons: bList,
    );
  }
}

class LiveUIStrings {
  final String appTitle;
  final String navMouse;
  final String navAudio;
  final String navMacro;
  final String navFiles;
  final String navGame;
  final String navSystem;

  const LiveUIStrings({
    this.appTitle = 'RemoteFlow Max',
    this.navMouse = 'الماوس',
    this.navAudio = 'الصوت',
    this.navMacro = 'الماكرو',
    this.navFiles = 'الملفات',
    this.navGame = 'الألعاب',
    this.navSystem = 'النظام',
  });

  factory LiveUIStrings.fromJson(Map<String, dynamic> json) {
    return LiveUIStrings(
      appTitle: json['app_title'] as String? ?? 'RemoteFlow Max',
      navMouse: json['nav_mouse'] as String? ?? 'الماوس',
      navAudio: json['nav_audio'] as String? ?? 'الصوت',
      navMacro: json['nav_macro'] as String? ?? 'الماكرو',
      navFiles: json['nav_files'] as String? ?? 'الملفات',
      navGame: json['nav_game'] as String? ?? 'الألعاب',
      navSystem: json['nav_system'] as String? ?? 'النظام',
    );
  }
}

class LiveUIConfig {
  final int version;
  final String lastUpdated;
  final LiveThemeConfig theme;
  final LiveTouchpadConfig touchpad;
  final LiveButtonLayout buttonLayout;
  final LiveMacroDeck macroDeck;
  final LiveUIStrings strings;

  const LiveUIConfig({
    this.version = 1,
    this.lastUpdated = '',
    this.theme = const LiveThemeConfig(),
    this.touchpad = const LiveTouchpadConfig(),
    this.buttonLayout = const LiveButtonLayout(),
    this.macroDeck = const LiveMacroDeck(),
    this.strings = const LiveUIStrings(),
  });

  factory LiveUIConfig.fromJson(Map<String, dynamic> json) {
    return LiveUIConfig(
      version: json['version'] as int? ?? 1,
      lastUpdated: json['last_updated'] as String? ?? '',
      theme: json['theme'] is Map<String, dynamic>
          ? LiveThemeConfig.fromJson(json['theme'] as Map<String, dynamic>)
          : const LiveThemeConfig(),
      touchpad: json['touchpad'] is Map<String, dynamic>
          ? LiveTouchpadConfig.fromJson(json['touchpad'] as Map<String, dynamic>)
          : const LiveTouchpadConfig(),
      buttonLayout: json['button_layout'] is Map<String, dynamic>
          ? LiveButtonLayout.fromJson(json['button_layout'] as Map<String, dynamic>)
          : const LiveButtonLayout(),
      macroDeck: json['macro_deck'] is Map<String, dynamic>
          ? LiveMacroDeck.fromJson(json['macro_deck'] as Map<String, dynamic>)
          : const LiveMacroDeck(),
      strings: json['ui_strings'] is Map<String, dynamic>
          ? LiveUIStrings.fromJson(json['ui_strings'] as Map<String, dynamic>)
          : const LiveUIStrings(),
    );
  }
}

class LiveUIState {
  final LiveUIConfig config;
  final bool hasNewApk;
  final Map<String, dynamic>? apkMetadata;
  final bool isDownloading;
  final double downloadProgress;
  final String? downloadError;
  final String? downloadedApkPath;

  const LiveUIState({
    this.config = const LiveUIConfig(),
    this.hasNewApk = false,
    this.apkMetadata,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.downloadError,
    this.downloadedApkPath,
  });

  LiveUIState copyWith({
    LiveUIConfig? config,
    bool? hasNewApk,
    Map<String, dynamic>? apkMetadata,
    bool? isDownloading,
    double? downloadProgress,
    String? downloadError,
    String? downloadedApkPath,
  }) {
    return LiveUIState(
      config: config ?? this.config,
      hasNewApk: hasNewApk ?? this.hasNewApk,
      apkMetadata: apkMetadata ?? this.apkMetadata,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadError: downloadError,
      downloadedApkPath: downloadedApkPath ?? this.downloadedApkPath,
    );
  }
}

class LiveUINotifier extends StateNotifier<LiveUIState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  LiveUINotifier(this._ref) : super(const LiveUIState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket packet) {
    final pType = packet.type.toLowerCase();
    final action = packet.action.toLowerCase();
    final payload = packet.payload;

    if (pType == 'ui' && action == 'live_update') {
      final cfgMap = payload['config'];
      if (cfgMap is Map<String, dynamic>) {
        final parsed = LiveUIConfig.fromJson(cfgMap);
        state = state.copyWith(config: parsed);

        // Apply touchpad configuration sync to local provider
        try {
          final tp = _ref.read(touchpadSettingsProvider.notifier);
          tp.setSensitivity(parsed.touchpad.sensitivity);
          tp.setScrollSpeed(parsed.touchpad.scrollSpeed);
          if (parsed.touchpad.invertScroll != _ref.read(touchpadSettingsProvider).invertScroll) {
            tp.toggleInvertScroll();
          }
          if (parsed.touchpad.swapMouseButtons != _ref.read(touchpadSettingsProvider).swapMouseButtons) {
            tp.toggleSwapMouseButtons();
          }
        } catch (_) {}
      }
    } else if (pType == 'system' && (action == 'new_apk_ready' || action == 'update_available')) {
      state = state.copyWith(
        hasNewApk: true,
        apkMetadata: payload,
      );
    }
  }

  void dismissApkAlert() {
    state = state.copyWith(hasNewApk: false);
  }

  Future<bool> downloadAndInstallApk({String? directUrl}) async {
    final conn = _ref.read(connectionProvider);
    final hostIp = conn.hostIp.isNotEmpty ? conn.hostIp : '192.168.1.6';
    final urlStr = directUrl ??
        (state.apkMetadata?['download_url'] as String?) ??
        'http://$hostIp:5058/api/update/latest.apk';

    state = state.copyWith(
      isDownloading: true,
      downloadProgress: 0.0,
      downloadError: null,
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(urlStr));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/RemoteFlowMax_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          state = state.copyWith(downloadProgress: progress.clamp(0.0, 1.0));
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
        downloadedApkPath: apkFile.path,
      );

      // Launch native Android PackageInstaller immediately
      final openResult = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      if (openResult.type != ResultType.done) {
        state = state.copyWith(
          downloadError: 'تم التحميل بنجاح (${apkFile.path}). فتح المثبت: ${openResult.message}',
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        downloadError: 'فشل تنزيل ملف التحديث: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final liveUIProvider = StateNotifierProvider<LiveUINotifier, LiveUIState>((ref) {
  return LiveUINotifier(ref);
});
