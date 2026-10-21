class DiscoveredDevice {
  final String ip;
  final int wsPort;
  final int udpPort;
  final String name;
  final DateTime lastSeen;

  DiscoveredDevice({
    required this.ip,
    required this.wsPort,
    required this.udpPort,
    required this.name,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          wsPort == other.wsPort;

  @override
  int get hashCode => ip.hashCode ^ wsPort.hashCode;
}
