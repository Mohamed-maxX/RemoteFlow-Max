import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class ClipboardState {
  final String text;
  final bool autoSync;
  final DateTime lastUpdated;

  const ClipboardState({
    this.text = '',
    this.autoSync = true,
    required this.lastUpdated,
  });

  ClipboardState copyWith({
    String? text,
    bool? autoSync,
    DateTime? lastUpdated,
  }) {
    return ClipboardState(
      text: text ?? this.text,
      autoSync: autoSync ?? this.autoSync,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ClipboardNotifier extends StateNotifier<ClipboardState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  ClipboardNotifier(this._ref)
      : super(ClipboardState(lastUpdated: DateTime.now())) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'clipboard' && pkt.action == 'sync') {
      final newText = pkt.payload['text'] as String? ?? '';
      if (newText.isNotEmpty && newText != state.text) {
        state = state.copyWith(text: newText, lastUpdated: DateTime.now());
        if (state.autoSync) {
          Clipboard.setData(ClipboardData(text: newText));
        }
      }
    }
  }

  void pushToPc(String text) {
    if (text.isEmpty) return;
    state = state.copyWith(text: text, lastUpdated: DateTime.now());
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'clipboard',
          action: 'set',
          payload: {'text': text},
        ));
  }

  void copyToMobile(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void toggleAutoSync() {
    state = state.copyWith(autoSync: !state.autoSync);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final clipboardProvider =
    StateNotifierProvider<ClipboardNotifier, ClipboardState>((ref) {
  return ClipboardNotifier(ref);
});
