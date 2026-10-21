import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/touchpad_settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/live_ui_provider.dart';
import '../widgets/keyboard_sheet.dart';
import '../widgets/jog_wheel_sheet.dart';
import '../widgets/settings_modal.dart';

class TouchpadScreen extends ConsumerStatefulWidget {
  const TouchpadScreen({super.key});

  @override
  ConsumerState<TouchpadScreen> createState() => _TouchpadScreenState();
}

class _TouchPoint {
  final int id;
  Offset position;
  final Offset startPosition;
  final int startTime;
  Offset lastPosition;
  final List<Offset> trail;

  _TouchPoint({
    required this.id,
    required this.position,
    required this.startTime,
  })  : startPosition = position,
        lastPosition = position,
        trail = [position];
}

class _TouchpadScreenState extends ConsumerState<TouchpadScreen> {
  final Map<int, _TouchPoint> _activePointers = {};
  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  bool _isRightStripScrolling = false;

  void _onPointerDown(PointerDownEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _activePointers[event.pointer] = _TouchPoint(
        id: event.pointer,
        position: event.localPosition,
        startTime: now,
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _activePointers[event.pointer];
    if (touch == null) return;

    final settings = ref.read(touchpadSettingsProvider);
    final connNotifier = ref.read(connectionProvider.notifier);

    touch.lastPosition = touch.position;
    touch.position = event.localPosition;
    touch.trail.add(event.localPosition);
    if (touch.trail.length > 12) {
      touch.trail.removeAt(0);
    }

    final delta = event.delta;

    if (_activePointers.length == 1) {
      // 1-Finger Delta Mouse Movement (Ultra low latency via UDP)
      final dx = delta.dx * settings.sensitivity;
      final dy = delta.dy * settings.sensitivity;
      connNotifier.sendDelta(dx, dy, mode: settings.mode);
    } else if (_activePointers.length == 2) {
      // 2-Finger Vertical Scroll
      double scrollDelta = delta.dy;
      if (settings.invertScroll) {
        scrollDelta = -scrollDelta;
      }
      connNotifier.sendScroll(scrollDelta);
    }

    setState(() {});
  }

  void _onPointerUp(PointerUpEvent event) {
    final touch = _activePointers.remove(event.pointer);
    final settings = ref.read(touchpadSettingsProvider);
    final connNotifier = ref.read(connectionProvider.notifier);

    if (touch != null && settings.tapToClick) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = now - touch.startTime;
      final distance = (event.localPosition - touch.startPosition).distance;

      // Tap gesture detection (< 250ms and < 14px total movement)
      if (duration < 250 && distance < 14.0) {
        if (_activePointers.isEmpty) {
          // 1 Finger Tap = Left Click
          connNotifier.sendClick('left', state: 'click');
          if (settings.hapticsEnabled) {
            HapticFeedback.lightImpact();
          }
        } else if (_activePointers.length == 1) {
          // 2 Finger Tap = Right Click
          connNotifier.sendClick('right', state: 'click');
          if (settings.hapticsEnabled) {
            HapticFeedback.mediumImpact();
          }
        }
      }
    }

    setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent event) {
    setState(() {
      _activePointers.remove(event.pointer);
    });
  }

  void _openKeyboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const KeyboardSheet(),
    );
  }

  void _openJogWheel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const JogWheelSheet(),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    SettingsModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(touchpadSettingsProvider);
    final settingsNotifier = ref.read(touchpadSettingsProvider.notifier);
    final theme = ref.watch(themeProvider);
    final liveUI = ref.watch(liveUIProvider);
    final tpConfig = liveUI.config.touchpad;
    final btnLayout = liveUI.config.buttonLayout;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Top Controls (DPI Switcher & Action Tools)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                // DPI Speed Switcher
                _buildModeSelector(settings.mode, settingsNotifier),
                const Spacer(),

                // Action Tools
                _buildTopActionButton(
                  icon: Icons.keyboard_rounded,
                  label: "الكيبورد",
                  color: AppTheme.cyanNeon,
                  onTap: _openKeyboard,
                ),
                const SizedBox(width: 8),
                _buildTopActionButton(
                  icon: Icons.album_rounded,
                  label: "العجلة",
                  color: AppTheme.orangeNeon,
                  onTap: _openJogWheel,
                ),
                const SizedBox(width: 8),
                _buildTopActionButton(
                  icon: Icons.tune_rounded,
                  label: "ضبط",
                  color: Colors.white70,
                  onTap: () => _showSettingsSheet(context),
                ),
              ],
            ),
          ),

          // Precision Touchpad Canvas Area
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(
                color: theme.cardFillColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: (_activePointers.isNotEmpty || _isRightStripScrolling)
                      ? theme.primaryColor
                      : theme.cardBorderColor,
                  width: (_activePointers.isNotEmpty || _isRightStripScrolling) ? 1.8 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ((_activePointers.isNotEmpty || _isRightStripScrolling) ? theme.primaryColor : Colors.black)
                        .withOpacity((_activePointers.isNotEmpty || _isRightStripScrolling) ? 0.22 : 0.4),
                    blurRadius: (_activePointers.isNotEmpty || _isRightStripScrolling) ? 22 : 12,
                    spreadRadius: (_activePointers.isNotEmpty || _isRightStripScrolling) ? 1 : 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Subtle Cyber Grid Pattern
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CyberGridPainter(),
                      ),
                    ),

                    // Central Arabic Guide Text (padded away from the right vertical scroll strip)
                    Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.cyanNeon.withOpacity(0.06),
                                border: Border.all(color: AppTheme.cyanNeon.withOpacity(0.15)),
                              ),
                              child: Icon(
                                Icons.touch_app_rounded,
                                size: 42,
                                color: AppTheme.cyanNeon.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              tpConfig.guideTextMain,
                              style: GoogleFonts.cairo(
                                color: Colors.white.withOpacity(0.85),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tpConfig.guideTextSub,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pointer Listener with Interactive Neon Glow Ripple & Trail (Touch zone)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: 46,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        onPointerCancel: _onPointerCancel,
                        child: CustomPaint(
                          painter: _NeonTouchFeedbackPainter(
                            pointers: _activePointers.values.toList(),
                          ),
                        ),
                      ),
                    ),

                    // Dedicated Vertical Scroll Strip on the Right Edge
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 46,
                      child: _buildRightVerticalScrollStrip(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Physical Hardware Deck (Supports customizable Left/Right button swapping)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Builder(
                builder: (context) {
                  final leftClickBtn = Expanded(
                    flex: 5,
                    child: _buildClickButton(
                      label: btnLayout.leftButtonLabel,
                      subtitle: btnLayout.leftButtonSubtitle,
                      icon: Icons.mouse_rounded,
                      glowColor: AppTheme.cyanNeon,
                      isPressed: _isLeftPressed,
                      onTapDown: () {
                        setState(() => _isLeftPressed = true);
                        ref.read(connectionProvider.notifier).sendClick('left', state: 'down');
                        if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
                      },
                      onTapUp: () {
                        setState(() => _isLeftPressed = false);
                        ref.read(connectionProvider.notifier).sendClick('left', state: 'up');
                      },
                    ),
                  );

                  final rightClickBtn = Expanded(
                    flex: 5,
                    child: _buildClickButton(
                      label: btnLayout.rightButtonLabel,
                      subtitle: btnLayout.rightButtonSubtitle,
                      icon: Icons.mouse_rounded,
                      glowColor: AppTheme.purpleNeon,
                      isPressed: _isRightPressed,
                      onTapDown: () {
                        setState(() => _isRightPressed = true);
                        ref.read(connectionProvider.notifier).sendClick('right', state: 'down');
                        if (settings.hapticsEnabled) HapticFeedback.mediumImpact();
                      },
                      onTapUp: () {
                        setState(() => _isRightPressed = false);
                        ref.read(connectionProvider.notifier).sendClick('right', state: 'up');
                      },
                    ),
                  );

                  final scrollMiddleBtn = Expanded(
                    flex: 3,
                    child: _buildScrollStrip(label: btnLayout.scrollButtonLabel),
                  );

                  return Row(
                    children: settings.swapMouseButtons
                        ? [
                            rightClickBtn,
                            const SizedBox(width: 8),
                            scrollMiddleBtn,
                            const SizedBox(width: 8),
                            leftClickBtn,
                          ]
                        : [
                            leftClickBtn,
                            const SizedBox(width: 8),
                            scrollMiddleBtn,
                            const SizedBox(width: 8),
                            rightClickBtn,
                          ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 70), // Spacing for floating navbar
        ],
      ),
    );
  }

  Widget _buildRightVerticalScrollStrip() {
    final settings = ref.watch(touchpadSettingsProvider);
    final connNotifier = ref.read(connectionProvider.notifier);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        setState(() => _isRightStripScrolling = true);
        if (settings.hapticsEnabled) HapticFeedback.selectionClick();
      },
      onVerticalDragEnd: (_) {
        setState(() => _isRightStripScrolling = false);
      },
      onVerticalDragCancel: () {
        setState(() => _isRightStripScrolling = false);
      },
      onVerticalDragUpdate: (details) {
        double deltaY = details.delta.dy;
        if (settings.invertScroll) {
          deltaY = -deltaY;
        }
        // Send high-resolution smooth scroll (negative deltaY scrolls up, positive scrolls down)
        connNotifier.sendScroll(-deltaY * settings.scrollSpeed);
        if (details.delta.dy.abs() > 4 && settings.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isRightStripScrolling
              ? AppTheme.cyanNeon.withOpacity(0.18)
              : const Color(0x280B132B),
          border: Border(
            left: BorderSide(
              color: _isRightStripScrolling
                  ? AppTheme.cyanNeon
                  : AppTheme.cyanNeon.withOpacity(0.25),
              width: 1.2,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _isRightStripScrolling ? AppTheme.cyanNeon : Colors.white38,
                size: 22,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.unfold_more_rounded,
                  color: _isRightStripScrolling ? AppTheme.cyanNeon : AppTheme.orangeNeon.withOpacity(0.85),
                  size: 26,
                ),
                const SizedBox(height: 4),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    "تمرير سريع",
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isRightStripScrolling ? AppTheme.cyanNeon : Colors.white60,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _isRightStripScrolling ? AppTheme.cyanNeon : Colors.white38,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(String currentMode, TouchpadSettingsNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x40101C38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModePill("دقيق 0.25x", "sniper", currentMode == "sniper", notifier, Icons.gps_fixed),
          _buildModePill("عادي 1.0x", "normal", currentMode == "normal", notifier, Icons.speed_rounded),
          _buildModePill("سريع 2.0x", "fast", currentMode == "fast", notifier, Icons.bolt_rounded),
        ],
      ),
    );
  }

  Widget _buildModePill(
    String label,
    String mode,
    bool isActive,
    TouchpadSettingsNotifier notifier,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () {
        notifier.setMode(mode);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.cyanGlowGradient : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.cyanNeon.withOpacity(0.4),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppTheme.bgDark : Colors.white60,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isActive ? AppTheme.bgDark : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClickButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color glowColor,
    required bool isPressed,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPressed ? glowColor.withOpacity(0.25) : const Color(0x40101C38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isPressed ? glowColor : glowColor.withOpacity(0.35),
            width: isPressed ? 1.8 : 1.2,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPressed ? glowColor : Colors.white, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: isPressed ? glowColor : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollStrip({String label = "تمرير"}) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        ref.read(connectionProvider.notifier).sendScroll(details.delta.dy * 1.2);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x40101C38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.orangeNeon.withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.orangeNeon.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded, color: AppTheme.orangeNeon, size: 16),
            Text(
              label,
              style: GoogleFonts.cairo(
                color: AppTheme.orangeNeon,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.orangeNeon, size: 16),
          ],
        ),
      ),
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1.0;

    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NeonTouchFeedbackPainter extends CustomPainter {
  final List<_TouchPoint> pointers;

  _NeonTouchFeedbackPainter({required this.pointers});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pointers) {
      // 1. Draw Touch Trail
      if (p.trail.length > 1) {
        for (int i = 0; i < p.trail.length - 1; i++) {
          final progress = i / p.trail.length;
          final trailPaint = Paint()
            ..color = AppTheme.cyanNeon.withOpacity(progress * 0.4)
            ..strokeWidth = 2.0 + (progress * 4.0)
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(p.trail[i], p.trail[i + 1], trailPaint);
        }
      }

      // 2. Multi-layer Radial Glow Aura
      final auraPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.cyanNeon.withOpacity(0.35),
            AppTheme.purpleNeon.withOpacity(0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: p.position, radius: 46));
      canvas.drawCircle(p.position, 46, auraPaint);

      // 3. Neon Outline Ring
      final ringPaint = Paint()
        ..color = AppTheme.cyanNeon.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawCircle(p.position, 24, ringPaint);

      // 4. Center Glowing Core
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, 6, dotPaint);

      final innerGlowPaint = Paint()
        ..color = AppTheme.cyanNeon
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, 4, innerGlowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonTouchFeedbackPainter oldDelegate) => true;
}
