import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import '../models/system_telemetry.dart';
import 'connection_provider.dart';

class TelemetryState {
  final SystemTelemetry current;
  final List<double> cpuHistory;
  final List<double> ramHistory;

  const TelemetryState({
    this.current = const SystemTelemetry(),
    this.cpuHistory = const [],
    this.ramHistory = const [],
  });

  TelemetryState copyWith({
    SystemTelemetry? current,
    List<double>? cpuHistory,
    List<double>? ramHistory,
  }) {
    return TelemetryState(
      current: current ?? this.current,
      cpuHistory: cpuHistory ?? this.cpuHistory,
      ramHistory: ramHistory ?? this.ramHistory,
    );
  }
}

class TelemetryNotifier extends StateNotifier<TelemetryState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  TelemetryNotifier(this._ref) : super(const TelemetryState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == PacketType.system && pkt.action == 'telemetry') {
      final telemetry = SystemTelemetry.fromMap(pkt.payload);

      final newCpu = List<double>.from(state.cpuHistory)..add(telemetry.cpuPercent);
      if (newCpu.length > 20) newCpu.removeAt(0);

      final newRam = List<double>.from(state.ramHistory)..add(telemetry.ramPercent);
      if (newRam.length > 20) newRam.removeAt(0);

      state = state.copyWith(
        current: telemetry,
        cpuHistory: newCpu,
        ramHistory: newRam,
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final telemetryProvider =
    StateNotifierProvider<TelemetryNotifier, TelemetryState>((ref) {
  return TelemetryNotifier(ref);
});
