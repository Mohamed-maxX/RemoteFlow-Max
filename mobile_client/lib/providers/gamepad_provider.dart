import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packet.dart';
import 'connection_provider.dart';

class GamepadNotifier {
  final Ref _ref;

  GamepadNotifier(this._ref);

  void sendButton(String button, {String state = 'press'}) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'gamepad',
          action: 'button',
          payload: {'button': button, 'state': state},
        ));
  }

  void sendStick(String stick, double x, double y) {
    _ref.read(connectionProvider.notifier).sendPacket(RemotePacket(
          type: 'gamepad',
          action: 'stick',
          payload: {'stick': stick, 'x': x, 'y': y},
        ));
  }
}

final gamepadProvider = Provider<GamepadNotifier>((ref) {
  return GamepadNotifier(ref);
});
