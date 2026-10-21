import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';

class TouchpadSettings {
  final double sensitivity;
  final String mode; // 'sniper' (0.25x), 'normal' (1.0x), 'fast' (2.0x)
  final double scrollSpeed; // Scroll strip velocity multiplier
  final bool invertScroll;
  final bool tapToClick;
  final bool hapticsEnabled;
  final bool swapMouseButtons; // false: LTR (Left on Left, Right on Right), true: swapped

  const TouchpadSettings({
    this.sensitivity = 1.0,
    this.mode = 'normal',
    this.scrollSpeed = 2.2,
    this.invertScroll = false,
    this.tapToClick = true,
    this.hapticsEnabled = true,
    this.swapMouseButtons = false,
  });

  TouchpadSettings copyWith({
    double? sensitivity,
    String? mode,
    double? scrollSpeed,
    bool? invertScroll,
    bool? tapToClick,
    bool? hapticsEnabled,
    bool? swapMouseButtons,
  }) {
    return TouchpadSettings(
      sensitivity: sensitivity ?? this.sensitivity,
      mode: mode ?? this.mode,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      invertScroll: invertScroll ?? this.invertScroll,
      tapToClick: tapToClick ?? this.tapToClick,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      swapMouseButtons: swapMouseButtons ?? this.swapMouseButtons,
    );
  }
}

class TouchpadSettingsNotifier extends StateNotifier<TouchpadSettings> {
  TouchpadSettingsNotifier() : super(_loadInitialSettings());

  static TouchpadSettings _loadInitialSettings() {
    return TouchpadSettings(
      sensitivity: PreferencesService.mouseSensitivity,
      mode: PreferencesService.mouseMode,
      scrollSpeed: PreferencesService.scrollSpeed,
      invertScroll: PreferencesService.invertScroll,
      tapToClick: PreferencesService.tapToClick,
      hapticsEnabled: PreferencesService.hapticsEnabled,
      swapMouseButtons: PreferencesService.swapMouseButtons,
    );
  }

  void setSensitivity(double value) {
    state = state.copyWith(sensitivity: value);
    PreferencesService.setMouseSensitivity(value);
  }

  void setMode(String mode) {
    double sens = 1.0;
    if (mode == 'sniper') sens = 0.25;
    if (mode == 'fast') sens = 2.0;

    state = state.copyWith(mode: mode, sensitivity: sens);
    PreferencesService.setMouseMode(mode);
    PreferencesService.setMouseSensitivity(sens);
  }

  void setScrollSpeed(double speed) {
    state = state.copyWith(scrollSpeed: speed);
    PreferencesService.setScrollSpeed(speed);
  }

  void toggleInvertScroll() {
    final next = !state.invertScroll;
    state = state.copyWith(invertScroll: next);
    PreferencesService.setInvertScroll(next);
  }

  void toggleTapToClick() {
    final next = !state.tapToClick;
    state = state.copyWith(tapToClick: next);
    PreferencesService.setTapToClick(next);
  }

  void toggleHaptics() {
    final next = !state.hapticsEnabled;
    state = state.copyWith(hapticsEnabled: next);
    PreferencesService.setHapticsEnabled(next);
  }

  void toggleSwapMouseButtons() {
    final next = !state.swapMouseButtons;
    state = state.copyWith(swapMouseButtons: next);
    PreferencesService.setSwapMouseButtons(next);
  }
}

final touchpadSettingsProvider =
    StateNotifierProvider<TouchpadSettingsNotifier, TouchpadSettings>((ref) {
  return TouchpadSettingsNotifier();
});
