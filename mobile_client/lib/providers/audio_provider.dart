import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import '../models/audio_state.dart';
import 'connection_provider.dart';

class AudioNotifier extends StateNotifier<AudioStateModel> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  AudioNotifier(this._ref) : super(const AudioStateModel()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'audio' && pkt.action == 'state') {
      state = AudioStateModel.fromMap(pkt.payload);
    }
  }

  void setMasterVolume(double volume) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'audio',
          action: 'set_master_volume',
          payload: {'volume': volume},
        ));
  }

  void toggleMasterMute() {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'audio',
          action: 'toggle_master_mute',
          payload: {},
        ));
  }

  void toggleMicMute() {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'audio',
          action: 'toggle_mic_mute',
          payload: {},
        ));
  }

  void setAppVolume(int pid, String rawName, double volume) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'audio',
          action: 'set_app_volume',
          payload: {'pid': pid, 'raw_name': rawName, 'volume': volume},
        ));
  }

  void toggleAppMute(int pid, String rawName) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'audio',
          action: 'toggle_app_mute',
          payload: {'pid': pid, 'raw_name': rawName},
        ));
  }

  void mediaAction(String action) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'media',
          action: action,
          payload: {},
        ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final audioProvider =
    StateNotifierProvider<AudioNotifier, AudioStateModel>((ref) {
  return AudioNotifier(ref);
});
