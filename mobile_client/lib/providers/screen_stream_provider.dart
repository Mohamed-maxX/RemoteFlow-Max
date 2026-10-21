import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class ScreenStreamState {
  final bool isStreaming;
  final Uint8List? currentFrame;
  final Uint8List? lastScreenshot;
  final int frameCount;
  final double fps;
  final bool isCapturingScreenshot;

  const ScreenStreamState({
    this.isStreaming = false,
    this.currentFrame,
    this.lastScreenshot,
    this.frameCount = 0,
    this.fps = 0.0,
    this.isCapturingScreenshot = false,
  });

  ScreenStreamState copyWith({
    bool? isStreaming,
    Uint8List? currentFrame,
    Uint8List? lastScreenshot,
    int? frameCount,
    double? fps,
    bool? isCapturingScreenshot,
  }) {
    return ScreenStreamState(
      isStreaming: isStreaming ?? this.isStreaming,
      currentFrame: currentFrame ?? this.currentFrame,
      lastScreenshot: lastScreenshot ?? this.lastScreenshot,
      frameCount: frameCount ?? this.frameCount,
      fps: fps ?? this.fps,
      isCapturingScreenshot: isCapturingScreenshot ?? this.isCapturingScreenshot,
    );
  }
}

class ScreenStreamNotifier extends StateNotifier<ScreenStreamState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;
  int _lastFpsCalcTime = 0;
  int _framesSinceLastCalc = 0;

  ScreenStreamNotifier(this._ref) : super(const ScreenStreamState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'stream') {
      if (pkt.action == 'frame') {
        final b64 = pkt.payload['image'] as String? ?? '';
        if (b64.isNotEmpty) {
          try {
            final bytes = base64Decode(b64);
            final now = DateTime.now().millisecondsSinceEpoch;
            _framesSinceLastCalc++;

            double currentFps = state.fps;
            if (_lastFpsCalcTime == 0) {
              _lastFpsCalcTime = now;
            } else if (now - _lastFpsCalcTime >= 1000) {
              currentFps = (_framesSinceLastCalc * 1000.0) / (now - _lastFpsCalcTime);
              _framesSinceLastCalc = 0;
              _lastFpsCalcTime = now;
            }

            state = state.copyWith(
              currentFrame: bytes,
              frameCount: state.frameCount + 1,
              fps: currentFps,
            );
          } catch (_) {}
        }
      } else if (pkt.action == 'screenshot') {
        final b64 = pkt.payload['image'] as String? ?? '';
        if (b64.isNotEmpty) {
          try {
            final bytes = base64Decode(b64);
            state = state.copyWith(
              lastScreenshot: bytes,
              isCapturingScreenshot: false,
            );
          } catch (_) {}
        }
      }
    }
  }

  void startStream() {
    state = state.copyWith(isStreaming: true);
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'stream',
          action: 'start',
          payload: {},
        ));
  }

  void stopStream() {
    state = state.copyWith(isStreaming: false, fps: 0.0);
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'stream',
          action: 'stop',
          payload: {},
        ));
  }

  void takeScreenshot() {
    state = state.copyWith(isCapturingScreenshot: true);
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'stream',
          action: 'screenshot',
          payload: {},
        ));
  }

  @override
  void dispose() {
    if (state.isStreaming) {
      stopStream();
    }
    _sub?.cancel();
    super.dispose();
  }
}

final screenStreamProvider =
    StateNotifierProvider<ScreenStreamNotifier, ScreenStreamState>((ref) {
  return ScreenStreamNotifier(ref);
});
