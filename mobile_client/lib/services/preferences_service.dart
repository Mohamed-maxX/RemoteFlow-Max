import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Persistent Storage Service for RemoteFlow Max Mobile Client.
/// Manages instant loading and permanent saving of all user preferences:
/// - Server IP & Ports (auto-reconnect without re-entering)
/// - Mouse sensitivity & Speed presets (0.25x / 1.0x / 2.0x)
/// - Scroll strip speed & direction
/// - Mouse buttons customization (Left/Right button swapping)
/// - Touchpad gestures (Tap to click, Haptic feedback)
/// - Active UI Theme (Cinematic Neon, Floating Glass, Cyber Gaming)
/// - Unique Device ID for trusted PC pairing
class PreferencesService {
  static late SharedPreferences _prefs;
  static bool _isInitialized = false;

  // Storage Keys
  static const String _keyServerIp = 'remoteflow_server_ip';
  static const String _keyWsPort = 'remoteflow_ws_port';
  static const String _keyUdpPort = 'remoteflow_udp_port';
  static const String _keySensitivity = 'remoteflow_mouse_sensitivity';
  static const String _keyMouseMode = 'remoteflow_mouse_mode';
  static const String _keyScrollSpeed = 'remoteflow_scroll_speed';
  static const String _keyInvertScroll = 'remoteflow_invert_scroll';
  static const String _keyTapToClick = 'remoteflow_tap_to_click';
  static const String _keyHapticsEnabled = 'remoteflow_haptics_enabled';
  static const String _keySwapMouseButtons = 'remoteflow_swap_mouse_buttons';
  static const String _keyThemeModeIndex = 'remoteflow_theme_mode';
  static const String _keyDeviceId = 'remoteflow_device_id';
  static const String _keyDeviceName = 'remoteflow_device_name';

  /// Initializes SharedPreferences instance synchronously before runApp().
  static Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;

    // Ensure unique persistent device ID exists
    if (!_prefs.containsKey(_keyDeviceId)) {
      final randomId = "rfm_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}";
      await _prefs.setString(_keyDeviceId, randomId);
    }
  }

  static bool get isInitialized => _isInitialized;

  // -------------------------------------------------------------
  // 1. Connection & Server Settings
  // -------------------------------------------------------------
  static String get serverIp => _prefs.getString(_keyServerIp) ?? '192.168.1.6';
  static int get wsPort => _prefs.getInt(_keyWsPort) ?? 5056;
  static int get udpPort => _prefs.getInt(_keyUdpPort) ?? 5055;

  static Future<void> saveServerConnection(String ip, int wsPort, int udpPort) async {
    await _prefs.setString(_keyServerIp, ip.trim());
    await _prefs.setInt(_keyWsPort, wsPort);
    await _prefs.setInt(_keyUdpPort, udpPort);
  }

  static Future<void> setServerIp(String ip) async {
    await _prefs.setString(_keyServerIp, ip.trim());
  }

  static Future<void> setWsPort(int port) async {
    await _prefs.setInt(_keyWsPort, port);
  }

  static Future<void> setUdpPort(int port) async {
    await _prefs.setInt(_keyUdpPort, port);
  }

  // -------------------------------------------------------------
  // 2. Mouse, Touchpad & Scroll Settings
  // -------------------------------------------------------------
  static double get mouseSensitivity => _prefs.getDouble(_keySensitivity) ?? 1.0;
  static String get mouseMode => _prefs.getString(_keyMouseMode) ?? 'normal';
  static double get scrollSpeed => _prefs.getDouble(_keyScrollSpeed) ?? 2.2;
  static bool get invertScroll => _prefs.getBool(_keyInvertScroll) ?? false;
  static bool get tapToClick => _prefs.getBool(_keyTapToClick) ?? true;
  static bool get hapticsEnabled => _prefs.getBool(_keyHapticsEnabled) ?? true;
  static bool get swapMouseButtons => _prefs.getBool(_keySwapMouseButtons) ?? false;

  static Future<void> setMouseSensitivity(double val) async {
    await _prefs.setDouble(_keySensitivity, val);
  }

  static Future<void> setMouseMode(String mode) async {
    await _prefs.setString(_keyMouseMode, mode);
  }

  static Future<void> setScrollSpeed(double val) async {
    await _prefs.setDouble(_keyScrollSpeed, val);
  }

  static Future<void> setInvertScroll(bool val) async {
    await _prefs.setBool(_keyInvertScroll, val);
  }

  static Future<void> setTapToClick(bool val) async {
    await _prefs.setBool(_keyTapToClick, val);
  }

  static Future<void> setHapticsEnabled(bool val) async {
    await _prefs.setBool(_keyHapticsEnabled, val);
  }

  static Future<void> setSwapMouseButtons(bool val) async {
    await _prefs.setBool(_keySwapMouseButtons, val);
  }

  // -------------------------------------------------------------
  // 3. UI Theme & Appearance
  // -------------------------------------------------------------
  static int get themeModeIndex => _prefs.getInt(_keyThemeModeIndex) ?? 0;

  static Future<void> setThemeModeIndex(int index) async {
    await _prefs.setInt(_keyThemeModeIndex, index);
  }

  // -------------------------------------------------------------
  // 4. Client Identity
  // -------------------------------------------------------------
  static String get deviceId => _prefs.getString(_keyDeviceId) ?? 'rfm_client_default';
  static String get deviceName => _prefs.getString(_keyDeviceName) ?? 'RemoteFlow Mobile';

  static Future<void> setDeviceName(String name) async {
    await _prefs.setString(_keyDeviceName, name.trim());
  }

  /// Resets all settings to default values.
  static Future<void> resetToDefaults() async {
    await _prefs.clear();
    await init();
  }
}
