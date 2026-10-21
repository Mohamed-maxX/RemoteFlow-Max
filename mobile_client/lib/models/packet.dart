import 'dart:convert';

class PacketType {
  static const String mouse = "mouse";
  static const String keyboard = "keyboard";
  static const String system = "system";
  static const String handshake = "handshake";
}

class MouseAction {
  static const String delta = "delta";
  static const String click = "click";
  static const String down = "down";
  static const String up = "up";
  static const String scroll = "scroll";
  static const String jog = "jog";
}

class KeyboardAction {
  static const String text = "text";
  static const String key = "key";
  static const String hotkey = "hotkey";
}

class SystemAction {
  static const String ping = "ping";
  static const String pong = "pong";
  static const String setSensitivity = "set_sensitivity";
}

class HandshakeAction {
  static const String connect = "connect";
  static const String ack = "ack";
}

class RemotePacket {
  final String type;
  final String action;
  final Map<String, dynamic> payload;
  final int timestamp;

  RemotePacket({
    required this.type,
    required this.action,
    required this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'action': action,
      'payload': payload,
      'timestamp': timestamp,
    };
  }

  String toJson() => json.encode(toMap());

  factory RemotePacket.fromMap(Map<String, dynamic> map) {
    return RemotePacket(
      type: map['type'] as String? ?? '',
      action: map['action'] as String? ?? '',
      payload: (map['payload'] as Map<String, dynamic>?) ?? {},
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }

  factory RemotePacket.fromJson(String source) =>
      RemotePacket.fromMap(json.decode(source) as Map<String, dynamic>);
}
