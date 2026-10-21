import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class SecurityState {
  final bool pinRequired;
  final bool isAuthenticated;
  final String? errorMessage;
  final String? authToken;

  const SecurityState({
    this.pinRequired = false,
    this.isAuthenticated = true,
    this.errorMessage,
    this.authToken,
  });

  SecurityState copyWith({
    bool? pinRequired,
    bool? isAuthenticated,
    String? errorMessage,
    String? authToken,
  }) {
    return SecurityState(
      pinRequired: pinRequired ?? this.pinRequired,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
      authToken: authToken ?? this.authToken,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  final Ref _ref;
  StreamSubscription<RemotePacket>? _sub;

  SecurityNotifier(this._ref) : super(const SecurityState()) {
    final connNotifier = _ref.read(connectionProvider.notifier);
    _sub = connNotifier.incomingPackets.listen(_onPacket);
  }

  void _onPacket(RemotePacket pkt) {
    if (pkt.type == 'handshake' && pkt.action == 'ack') {
      final pinReq = pkt.payload['pin_required'] as bool? ?? false;
      if (pinReq) {
        state = state.copyWith(pinRequired: true, isAuthenticated: false);
      }
    } else if (pkt.type == 'security') {
      if (pkt.action == 'auth_ack') {
        final token = pkt.payload['token'] as String? ?? '';
        state = state.copyWith(isAuthenticated: true, authToken: token, errorMessage: null);
      } else if (pkt.action == 'auth_fail') {
        final err = pkt.payload['error'] as String? ?? 'Invalid PIN';
        state = state.copyWith(isAuthenticated: false, errorMessage: err);
      }
    }
  }

  void sendPin(String pin) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'security',
          action: 'auth',
          payload: {'pin': pin},
        ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier(ref);
});
