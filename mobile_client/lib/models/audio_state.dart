class AudioAppSession {
  final String name;
  final String rawName;
  final int pid;
  final double volume;
  final bool muted;

  const AudioAppSession({
    required this.name,
    required this.rawName,
    required this.pid,
    required this.volume,
    required this.muted,
  });

  factory AudioAppSession.fromMap(Map<String, dynamic> map) {
    return AudioAppSession(
      name: map['name'] as String? ?? 'App',
      rawName: map['raw_name'] as String? ?? '',
      pid: map['pid'] as int? ?? 0,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      muted: map['muted'] as bool? ?? false,
    );
  }
}

class AudioStateModel {
  final double masterVolume;
  final bool masterMuted;
  final String masterDevice;
  final bool micMuted;
  final double micVolume;
  final String micDevice;
  final List<AudioAppSession> sessions;

  const AudioStateModel({
    this.masterVolume = 0.5,
    this.masterMuted = false,
    this.masterDevice = 'Speakers',
    this.micMuted = false,
    this.micVolume = 1.0,
    this.micDevice = 'Microphone',
    this.sessions = const [],
  });

  factory AudioStateModel.fromMap(Map<String, dynamic> map) {
    final master = map['master'] as Map<String, dynamic>? ?? {};
    final mic = map['mic'] as Map<String, dynamic>? ?? {};
    final sessionsRaw = map['sessions'] as List<dynamic>? ?? [];

    return AudioStateModel(
      masterVolume: (master['volume'] as num?)?.toDouble() ?? 0.5,
      masterMuted: master['muted'] as bool? ?? false,
      masterDevice: master['device_name'] as String? ?? 'Speakers',
      micMuted: mic['muted'] as bool? ?? false,
      micVolume: (mic['volume'] as num?)?.toDouble() ?? 1.0,
      micDevice: mic['device_name'] as String? ?? 'Microphone',
      sessions: sessionsRaw
          .map((s) => AudioAppSession.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
