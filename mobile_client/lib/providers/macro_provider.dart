import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macro_deck.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class MacroState {
  final List<MacroDeck> decks;
  final int selectedDeckIndex;

  const MacroState({
    this.decks = const [],
    this.selectedDeckIndex = 0,
  });

  MacroDeck? get activeDeck =>
      (decks.isNotEmpty && selectedDeckIndex < decks.length)
          ? decks[selectedDeckIndex]
          : null;

  MacroState copyWith({
    List<MacroDeck>? decks,
    int? selectedDeckIndex,
  }) {
    return MacroState(
      decks: decks ?? this.decks,
      selectedDeckIndex: selectedDeckIndex ?? this.selectedDeckIndex,
    );
  }
}

class MacroNotifier extends StateNotifier<MacroState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  MacroNotifier(this._ref) : super(const MacroState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'macro' && pkt.action == 'decks') {
      final decksRaw = pkt.payload['decks'] as List<dynamic>? ?? [];
      final decks = decksRaw
          .map((d) => MacroDeck.fromMap(d as Map<String, dynamic>))
          .toList();
      state = state.copyWith(decks: decks);
    }
  }

  void selectDeck(int index) {
    if (index >= 0 && index < state.decks.length) {
      state = state.copyWith(selectedDeckIndex: index);
    }
  }

  void executeButton(MacroButton btn) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'macro',
          action: 'execute',
          payload: {
            'macro_type': btn.type,
            'payload': btn.payload,
          },
        ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final macroProvider =
    StateNotifierProvider<MacroNotifier, MacroState>((ref) {
  return MacroNotifier(ref);
});
