import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import '../services/preferences_service.dart';
import '../services/udp_service.dart';
import '../services/ws_service.dart';

class ConnectionStateModel {
  final ConnectionStatus status;
  final String hostIp;
  final int wsPort;
  final int udpPort;
  final int latencyMs;
  final String? serverName;
  final List<int>? screenSize;

  const ConnectionStateModel({
    this.status = ConnectionStatus.disconnected,
    this.hostIp = "192.168.1.6",
    this.wsPort = 5056,
    this.udpPort = 5055,
    this.latencyMs = 0,
    this.serverName,
    this.screenSize,
  });

  bool get isConnected => status == ConnectionStatus.connected;

  ConnectionStateModel copyWith({
    ConnectionStatus? status,
    String? hostIp,
    int? wsPort,
    int? udpPort,
    int? latencyMs,
    String? serverName,
    List<int>? screenSize,
  }) {
    return ConnectionStateModel(
      status: status ?? this.status,
      hostIp: hostIp ?? this.hostIp,
      wsPort: wsPort ?? this.wsPort,
      udpPort: udpPort ?? this.udpPort,
      latencyMs: latencyMs ?? this.latencyMs,
      serverName: serverName ?? this.serverName,
      screenSize: screenSize ?? this.screenSize,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionStateModel> {
  final UDPService _udp = UDPService();
  final WebSocketService _ws = WebSocketService();
  final StreamController<RemotePacket> _packetStreamController =
      StreamController<RemotePacket>.broadcast();

  Stream<RemotePacket> get incomingPackets => _packetStreamController.stream;

  ConnectionNotifier()
      : super(ConnectionStateModel(
          hostIp: PreferencesService.serverIp,
          wsPort: PreferencesService.wsPort,
          udpPort: PreferencesService.udpPort,
        )) {
    _ws.onStatusChanged = (status) {
      state = state.copyWith(
        status: status,
        serverName: _ws.serverName ?? state.serverName,
        screenSize: _ws.screenSize ?? state.screenSize,
      );
    };

    _ws.onLatencyUpdated = (latency) {
      state = state.copyWith(latencyMs: latency);
    };

    _ws.onPacketReceived = (pkt) {
      _packetStreamController.add(pkt);
    };

    // Auto-connect on launch with saved primary IP
    Future.microtask(() => connect(
          ip: state.hostIp,
          wsPort: state.wsPort,
          udpPort: state.udpPort,
        ));
  }

  Future<bool> connect({
    required String ip,
    int wsPort = 5056,
    int udpPort = 5055,
  }) async {
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      hostIp: ip,
      wsPort: wsPort,
      udpPort: udpPort,
    );

    // Initialize UDP Client
    await _udp.init(ip, udpPort);

    // Initialize WebSocket Channel
    final success = await _ws.connect(ip, wsPort);
    if (!success) {
      state = state.copyWith(status: ConnectionStatus.disconnected);
      return false;
    }

    // Persist successful server connection immediately
    await PreferencesService.saveServerConnection(ip, wsPort, udpPort);

    state = state.copyWith(
      status: _ws.status,
      serverName: _ws.serverName,
      screenSize: _ws.screenSize,
    );
    return true;
  }

  Future<bool> reconnect() async {
    return await connect(ip: state.hostIp, wsPort: state.wsPort, udpPort: state.udpPort);
  }

  void disconnect() {
    _ws.disconnect();
    _udp.close();
    state = state.copyWith(status: ConnectionStatus.disconnected);
  }

  // --- High Frequency UDP Dispatches ---
  void sendDelta(double dx, double dy, {String mode = 'normal'}) {
    _udp.sendDelta(dx, dy, mode: mode);
  }

  void sendScroll(double dy, [double dx = 0.0]) {
    _udp.sendScroll(dy, dx);
  }

  void sendJog(double delta) {
    _udp.sendJog(delta);
  }

  // --- Mouse Clicks ---
  void sendClick(String button, {String state = 'click'}) {
    if (_udp.isReady) {
      _udp.sendClick(button, state: state);
    } else {
      _ws.sendClick(button, state: state);
    }
  }

  // --- Keyboard & System Dispatches ---
  void sendText(String text) {
    _ws.sendText(text);
  }

  void sendKey(String key, {String state = 'press'}) {
    _ws.sendKey(key, state: state);
  }

  void sendHotkey(List<String> keys) {
    _ws.sendHotkey(keys);
  }

  void sendPacket(RemotePacket packet) {
    _ws.sendPacket(packet);
  }

  @override
  void dispose() {
    _packetStreamController.close();
    disconnect();
    super.dispose();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionStateModel>((ref) {
  return ConnectionNotifier();
});
