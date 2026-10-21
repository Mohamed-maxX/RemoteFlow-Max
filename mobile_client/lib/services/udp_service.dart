import 'dart:convert';
import 'dart:io';

class UDPService {
  RawDatagramSocket? _socket;
  InternetAddress? _targetAddress;
  int _targetPort = 5055;
  bool _isInitialized = false;

  bool get isReady => _isInitialized && _socket != null && _targetAddress != null;

  /// Initializes UDP client socket
  Future<void> init(String hostIp, int port) async {
    try {
      close();
      _targetPort = port;
      _targetAddress = InternetAddress(hostIp);
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  /// Send mouse delta movement with sub-millisecond overhead
  void sendDelta(double dx, double dy, {String mode = 'normal'}) {
    if (!isReady) return;
    // Compact fast-path: "d,dx,dy,mode"
    final data = utf8.encode('d,${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)},$mode');
    _socket?.send(data, _targetAddress!, _targetPort);
  }

  /// Send two-finger smooth scroll delta
  void sendScroll(double dy, [double dx = 0.0]) {
    if (!isReady) return;
    // Compact fast-path: "s,dx,dy"
    final data = utf8.encode('s,${dx.toStringAsFixed(2)},${dy.toStringAsFixed(2)}');
    _socket?.send(data, _targetAddress!, _targetPort);
  }

  /// Send mouse button down/up/click over UDP
  void sendClick(String button, {String state = 'click'}) {
    if (!isReady) return;
    final jsonPkt = json.encode({
      'type': 'mouse',
      'action': state,
      'payload': {'button': button, 'state': state},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _socket?.send(utf8.encode(jsonPkt), _targetAddress!, _targetPort);
  }

  /// Send jog wheel ticks for timeline scrubbing
  void sendJog(double delta) {
    if (!isReady) return;
    final jsonPkt = json.encode({
      'type': 'mouse',
      'action': 'jog',
      'payload': {'delta': delta},
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _socket?.send(utf8.encode(jsonPkt), _targetAddress!, _targetPort);
  }

  void close() {
    _socket?.close();
    _socket = null;
    _isInitialized = false;
  }
}
