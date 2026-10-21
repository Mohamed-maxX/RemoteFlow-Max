import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/packet.dart';
import 'preferences_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  String? _currentHost;
  int? _currentPort;
  bool _manualDisconnect = false;
  bool _isConnecting = false;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionStatus get status => _status;

  int _latencyMs = 0;
  int get latencyMs => _latencyMs;

  String? _serverName;
  String? get serverName => _serverName;

  List<int>? _screenSize;
  List<int>? get screenSize => _screenSize;

  Function(ConnectionStatus)? onStatusChanged;
  Function(int latency)? onLatencyUpdated;
  Function(RemotePacket)? onPacketReceived;

  Future<bool> connect(String hostIp, int port, {bool isAutoReconnect = false}) async {
    _currentHost = hostIp;
    _currentPort = port;

    if (!isAutoReconnect) {
      _manualDisconnect = false;
    }

    _status = ConnectionStatus.connecting;
    onStatusChanged?.call(_status);

    try {
      // Clean up previous channel/subscription before connecting
      _pingTimer?.cancel();
      await _subscription?.cancel();
      _subscription = null;
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;

      final uri = Uri.parse('ws://$hostIp:$port');
      _channel = WebSocketChannel.connect(uri);

      // Listen for incoming packets
      _subscription = _channel?.stream.listen(
        (data) {
          _handleIncoming(data.toString());
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      // Perform Handshake
      final handshakePkt = RemotePacket(
        type: PacketType.handshake,
        action: HandshakeAction.connect,
        payload: {
          'client_name': PreferencesService.isInitialized ? PreferencesService.deviceName : 'RemoteFlow Mobile',
          'device_id': PreferencesService.isInitialized ? PreferencesService.deviceId : 'rfm_client_unknown',
          'version': '1.0.0',
        },
      );
      sendPacket(handshakePkt);

      // We start the ping loop immediately to measure latency
      _startPingLoop();
      return true;
    } catch (e) {
      _handleDisconnect();
      return false;
    }
  }

  void _handleIncoming(String raw) {
    try {
      final pkt = RemotePacket.fromJson(raw);
      onPacketReceived?.call(pkt);

      // As soon as any valid packet arrives from host, mark as connected
      if (_status != ConnectionStatus.connected) {
        _status = ConnectionStatus.connected;
        _stopReconnectTimer();
        onStatusChanged?.call(_status);
      }

      if (pkt.type == PacketType.handshake && pkt.action == HandshakeAction.ack) {
        _serverName = pkt.payload['server_name'] as String?;
        final screen = pkt.payload['screen_size'] as List<dynamic>?;
        if (screen != null && screen.length >= 2) {
          _screenSize = [screen[0] as int, screen[1] as int];
        }
        _status = ConnectionStatus.connected;
        _stopReconnectTimer();
        onStatusChanged?.call(_status);
      } else if (pkt.type == PacketType.system && pkt.action == SystemAction.pong) {
        final clientTs = pkt.payload['client_ts'] as int? ?? 0;
        if (clientTs > 0) {
          _latencyMs = DateTime.now().millisecondsSinceEpoch - clientTs;
          onLatencyUpdated?.call(_latencyMs);
        }
      }
    } catch (_) {}
  }

  void _startPingLoop() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_status == ConnectionStatus.connected) {
        final ping = RemotePacket(
          type: PacketType.system,
          action: SystemAction.ping,
          payload: {'client_ts': DateTime.now().millisecondsSinceEpoch},
        );
        sendPacket(ping);
      }
    });
  }

  void sendPacket(RemotePacket packet) {
    try {
      _channel?.sink.add(packet.toJson());
    } catch (_) {}
  }

  void sendText(String text) {
    sendPacket(RemotePacket(
      type: PacketType.keyboard,
      action: KeyboardAction.text,
      payload: {'text': text},
    ));
  }

  void sendKey(String key, {String state = 'press'}) {
    sendPacket(RemotePacket(
      type: PacketType.keyboard,
      action: KeyboardAction.key,
      payload: {'key': key, 'state': state},
    ));
  }

  void sendHotkey(List<String> keys) {
    sendPacket(RemotePacket(
      type: PacketType.keyboard,
      action: KeyboardAction.hotkey,
      payload: {'keys': keys},
    ));
  }

  void sendClick(String button, {String state = 'click'}) {
    sendPacket(RemotePacket(
      type: PacketType.mouse,
      action: MouseAction.click,
      payload: {'button': button, 'state': state},
    ));
  }

  void _handleDisconnect() {
    _status = ConnectionStatus.disconnected;
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    onStatusChanged?.call(_status);

    // Auto-reconnect every 2 seconds if not manually disconnected by user
    if (!_manualDisconnect && _currentHost != null && _currentPort != null) {
      _startReconnectTimer();
    }
  }

  void _startReconnectTimer() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      return;
    }
    _reconnectTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_manualDisconnect || _status == ConnectionStatus.connected) {
        _stopReconnectTimer();
        return;
      }
      if (!_isConnecting && _currentHost != null && _currentPort != null) {
        _isConnecting = true;
        try {
          await connect(_currentHost!, _currentPort!, isAutoReconnect: true);
        } catch (_) {
        } finally {
          _isConnecting = false;
        }
      }
    });
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<bool> reconnectNow() async {
    _manualDisconnect = false;
    _stopReconnectTimer();
    if (_currentHost != null && _currentPort != null) {
      return await connect(_currentHost!, _currentPort!);
    }
    return false;
  }

  void disconnect() {
    _manualDisconnect = true;
    _stopReconnectTimer();
    _handleDisconnect();
  }
}
