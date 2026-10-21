class SystemTelemetry {
  final double cpuPercent;
  final List<double> cpuCores;
  final double ramPercent;
  final double ramUsedGb;
  final double ramTotalGb;
  final double diskPercent;
  final double diskUsedGb;
  final double diskTotalGb;
  final double uploadKbps;
  final double downloadKbps;
  final double? batteryPercent;
  final bool isCharging;
  final int uptimeSeconds;
  final bool caffeine;
  final int timestamp;

  const SystemTelemetry({
    this.cpuPercent = 0.0,
    this.cpuCores = const [],
    this.ramPercent = 0.0,
    this.ramUsedGb = 0.0,
    this.ramTotalGb = 0.0,
    this.diskPercent = 0.0,
    this.diskUsedGb = 0.0,
    this.diskTotalGb = 0.0,
    this.uploadKbps = 0.0,
    this.downloadKbps = 0.0,
    this.batteryPercent,
    this.isCharging = false,
    this.uptimeSeconds = 0,
    this.caffeine = false,
    this.timestamp = 0,
  });

  factory SystemTelemetry.fromMap(Map<String, dynamic> map) {
    return SystemTelemetry(
      cpuPercent: (map['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      cpuCores: (map['cpu_cores'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      ramPercent: (map['ram_percent'] as num?)?.toDouble() ?? 0.0,
      ramUsedGb: (map['ram_used_gb'] as num?)?.toDouble() ?? 0.0,
      ramTotalGb: (map['ram_total_gb'] as num?)?.toDouble() ?? 0.0,
      diskPercent: (map['disk_percent'] as num?)?.toDouble() ?? 0.0,
      diskUsedGb: (map['disk_used_gb'] as num?)?.toDouble() ?? 0.0,
      diskTotalGb: (map['disk_total_gb'] as num?)?.toDouble() ?? 0.0,
      uploadKbps: (map['upload_kbps'] as num?)?.toDouble() ?? 0.0,
      downloadKbps: (map['download_kbps'] as num?)?.toDouble() ?? 0.0,
      batteryPercent: (map['battery_percent'] as num?)?.toDouble(),
      isCharging: map['is_charging'] as bool? ?? false,
      uptimeSeconds: map['uptime_seconds'] as int? ?? 0,
      caffeine: map['caffeine'] as bool? ?? false,
      timestamp: map['timestamp'] as int? ?? 0,
    );
  }
}
