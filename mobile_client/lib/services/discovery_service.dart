import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/discovered_device.dart';

class DiscoveryService {
  static const int discoveryPort = 5057;
  static const String magicRequest = "REMOTEFLOW_DISCOVERY_REQ";
  static const String magicResponse = "REMOTEFLOW_DISCOVERY_ACK";

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final Map<String, DiscoveredDevice> _devices = {};
  
  final _devicesStreamController = StreamController<List<DiscoveredDevice>>.broadcast();
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesStreamController.stream;

  List<DiscoveredDevice> get currentDevices => _devices.values.toList();

  Future<void> startDiscovery() async {
    stopDiscovery();
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.broadcastEnabled = true;

      _socket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // Send initial scan probe immediately
      sendProbe();

      // Repeat discovery probe every 2.5 seconds
      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        sendProbe();
      });
    } catch (_) {}
  }

  void sendProbe() {
    try {
      final probe = utf8.encode(magicRequest);
      _socket?.send(probe, InternetAddress("255.255.255.255"), discoveryPort);
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final text = utf8.decode(datagram.data).trim();
      if (text.startsWith(magicResponse)) {
        final jsonStr = text.substring(magicResponse.length + 1);
        final data = json.decode(jsonStr) as Map<String, dynamic>;

        if (data['app'] == 'RemoteFlowMax') {
          final device = DiscoveredDevice(
            ip: data['ip'] as String? ?? datagram.address.address,
            wsPort: (data['ws_port'] as int?) ?? 5056,
            udpPort: (data['udp_port'] as int?) ?? 5055,
            name: data['name'] as String? ?? "RemoteFlow PC",
            lastSeen: DateTime.now(),
          );

          _devices[device.ip] = device;
          _devicesStreamController.add(currentDevices);
        }
      }
    } catch (_) {}
  }

  void stopDiscovery() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    stopDiscovery();
    _devicesStreamController.close();
  }
}
