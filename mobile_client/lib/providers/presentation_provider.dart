import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class PresentationState {
  final bool teleprompterActive;
  final double teleprompterSpeed;
  final int elapsedSeconds;
  final bool isTimerRunning;

  const PresentationState({
    this.teleprompterActive = false,
    this.teleprompterSpeed = 2.0,
    this.elapsedSeconds = 0,
    this.isTimerRunning = false,
  });

  String get formattedTimer {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PresentationState copyWith({
    bool? teleprompterActive,
    double? teleprompterSpeed,
    int? elapsedSeconds,
    bool? isTimerRunning,
  }) {
    return PresentationState(
      teleprompterActive: teleprompterActive ?? this.teleprompterActive,
      teleprompterSpeed: teleprompterSpeed ?? this.teleprompterSpeed,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isTimerRunning: isTimerRunning ?? this.isTimerRunning,
    );
  }
}

class PresentationNotifier extends StateNotifier<PresentationState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;
  Timer? _timer;

  PresentationNotifier(this._ref) : super(const PresentationState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'presentation' && pkt.action == 'teleprompter') {
      final active = pkt.payload['active'] as bool? ?? false;
      final speed = (pkt.payload['speed'] as num?)?.toDouble() ?? state.teleprompterSpeed;
      state = state.copyWith(teleprompterActive: active, teleprompterSpeed: speed);
    }
  }

  void slideAction(String action) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'presentation',
          action: 'action',
          payload: {'slide_action': action},
        ));
  }

  void toggleTeleprompter() {
    final next = !state.teleprompterActive;
    state = state.copyWith(teleprompterActive: next);
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'presentation',
          action: 'teleprompter',
          payload: {
            'enable': next,
            'speed': state.teleprompterSpeed,
          },
        ));
  }

  void setSpeed(double speed) {
    state = state.copyWith(teleprompterSpeed: speed);
    if (state.teleprompterActive) {
      _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
            type: 'presentation',
            action: 'teleprompter',
            payload: {'speed': speed},
          ));
    }
  }

  void toggleTimer() {
    if (state.isTimerRunning) {
      _timer?.cancel();
      state = state.copyWith(isTimerRunning: false);
    } else {
      state = state.copyWith(isTimerRunning: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      });
    }
  }

  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(elapsedSeconds: 0, isTimerRunning: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final presentationProvider =
    StateNotifierProvider<PresentationNotifier, PresentationState>((ref) {
  return PresentationNotifier(ref);
});
