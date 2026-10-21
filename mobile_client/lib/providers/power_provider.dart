import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class RamFlushResult {
  final double freedMb;
  final double initialPercent;
  final double newPercent;
  final int processesTrimmed;

  const RamFlushResult({
    this.freedMb = 0.0,
    this.initialPercent = 0.0,
    this.newPercent = 0.0,
    this.processesTrimmed = 0,
  });
}

class PowerState {
  final bool caffeine;
  final RamFlushResult? lastFlush;
  final bool isFlushing;

  const PowerState({
    this.caffeine = false,
    this.lastFlush,
    this.isFlushing = false,
  });

  PowerState copyWith({
    bool? caffeine,
    RamFlushResult? lastFlush,
    bool? isFlushing,
  }) {
    return PowerState(
      caffeine: caffeine ?? this.caffeine,
      lastFlush: lastFlush ?? this.lastFlush,
      isFlushing: isFlushing ?? this.isFlushing,
    );
  }
}

class PowerNotifier extends StateNotifier<PowerState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  PowerNotifier(this._ref) : super(const PowerState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'power' && pkt.action == 'ram_flush_result') {
      final res = RamFlushResult(
        freedMb: (pkt.payload['freed_mb'] as num?)?.toDouble() ?? 0.0,
        initialPercent: (pkt.payload['initial_percent'] as num?)?.toDouble() ?? 0.0,
        newPercent: (pkt.payload['new_percent'] as num?)?.toDouble() ?? 0.0,
        processesTrimmed: (pkt.payload['processes_trimmed'] as int?) ?? 0,
      );
      state = state.copyWith(lastFlush: res, isFlushing: false);
    } else if (pkt.type == 'system' && pkt.action == 'telemetry') {
      final isCaff = pkt.payload['caffeine'] as bool? ?? false;
      if (state.caffeine != isCaff) {
        state = state.copyWith(caffeine: isCaff);
      }
    }
  }

  void lockPc() {
    _sendPower('lock');
  }

  void sleepPc() {
    _sendPower('sleep');
  }

  void shutdownPc({int timer = 0}) {
    _sendPower('shutdown', {'timer': timer});
  }

  void restartPc({int timer = 0}) {
    _sendPower('restart', {'timer': timer});
  }

  void cancelShutdown() {
    _sendPower('cancel_shutdown');
  }

  void toggleCaffeine() {
    final next = !state.caffeine;
    state = state.copyWith(caffeine: next);
    _sendPower('caffeine', {'enable': next});
  }

  void flushRam() {
    state = state.copyWith(isFlushing: true);
    _sendPower('ram_flush');
  }

  void bossKey() {
    _sendPower('boss_key');
  }

  void setPowerProfile(String profile) {
    _sendPower('set_profile', {'profile': profile});
  }

  void wakeOnLan(String mac) {
    _sendPower('wol', {'mac': mac});
  }

  void _sendPower(String action, [Map<String, dynamic>? payload]) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'power',
          action: action,
          payload: payload ?? {},
        ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final powerProvider = StateNotifierProvider<PowerNotifier, PowerState>((ref) {
  return PowerNotifier(ref);
});
