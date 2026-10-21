import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/gamepad_provider.dart';

class GamepadScreen extends ConsumerStatefulWidget {
  const GamepadScreen({super.key});

  @override
  ConsumerState<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends ConsumerState<GamepadScreen> {
  Offset _leftStickDelta = Offset.zero;
  Offset _rightStickDelta = Offset.zero;

  void _onStickUpdate(String stick, DragUpdateDetails details, Size areaSize) {
    final center = Offset(areaSize.width / 2, areaSize.height / 2);
    final maxRadius = areaSize.width / 2 - 16;
    final touchPos = details.localPosition;
    var delta = touchPos - center;

    if (delta.distance > maxRadius) {
      delta = Offset.fromDirection(delta.direction, maxRadius);
    }

    final normalizedX = delta.dx / maxRadius;
    final normalizedY = delta.dy / maxRadius;

    setState(() {
      if (stick == "left") {
        _leftStickDelta = delta;
      } else {
        _rightStickDelta = delta;
      }
    });

    ref.read(gamepadProvider).sendStick(stick, normalizedX, normalizedY);
  }

  void _onStickEnd(String stick) {
    setState(() {
      if (stick == "left") {
        _leftStickDelta = Offset.zero;
      } else {
        _rightStickDelta = Offset.zero;
      }
    });
    ref.read(gamepadProvider).sendStick(stick, 0.0, 0.0);
  }

  Widget _buildButton(
    String label,
    String buttonId,
    Color color, {
    double size = 52,
    bool isTrigger = false,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        ref.read(gamepadProvider).sendButton(buttonId, state: 'down');
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        ref.read(gamepadProvider).sendButton(buttonId, state: 'up');
      },
      onTapCancel: () {
        ref.read(gamepadProvider).sendButton(buttonId, state: 'up');
      },
      child: Container(
        width: isTrigger ? 80 : size,
        height: isTrigger ? 44 : size,
        decoration: BoxDecoration(
          color: isTrigger ? AppTheme.bgCard : color.withOpacity(0.18),
          shape: isTrigger ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isTrigger ? BorderRadius.circular(14) : null,
          border: Border.all(color: color.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: isTrigger ? 11 : 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoystick(String stick, Offset currentDelta) {
    const size = 120.0;
    return SizedBox(
      width: size,
      height: size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final areaSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanUpdate: (d) => _onStickUpdate(stick, d, areaSize),
            onPanEnd: (_) => _onStickEnd(stick),
            onPanCancel: () => _onStickEnd(stick),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgSurface.withOpacity(0.85),
                border: Border.all(color: AppTheme.borderHighlight, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                  )
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: currentDelta,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: stick == "left"
                              ? [AppTheme.cyanGlow, const Color(0xFF0091EA)]
                              : [AppTheme.orangeNeon, const Color(0xFFD84315)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (stick == "left" ? AppTheme.cyanGlow : AppTheme.orangeNeon).withOpacity(0.4),
                            blurRadius: 12,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          stick == "left" ? "L" : "R",
                          style: const TextStyle(
                            color: AppTheme.bgDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Top Triggers & Bumpers Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildButton("LT (تصويب)", "lt", AppTheme.cyanGlow, isTrigger: true),
                      const SizedBox(width: 8),
                      _buildButton("LB", "lb", AppTheme.textSecondary, isTrigger: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton("تحديد", "select", AppTheme.textMuted, size: 38, isTrigger: true),
                      const SizedBox(width: 8),
                      _buildButton("بدء", "start", AppTheme.textMuted, size: 38, isTrigger: true),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton("RB", "rb", AppTheme.textSecondary, isTrigger: true),
                      const SizedBox(width: 8),
                      _buildButton("RT (إطلاق)", "rt", AppTheme.orangeNeon, isTrigger: true),
                    ],
                  ),
                ],
              ),
              const Spacer(),

              // Main Dual-Cluster Deck
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Cluster: D-Pad & Left Stick
                  Column(
                    children: [
                      // D-Pad
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(top: 0, child: _buildButton("▲", "dpad_up", AppTheme.cyanGlow, size: 42)),
                            Positioned(bottom: 0, child: _buildButton("▼", "dpad_down", AppTheme.cyanGlow, size: 42)),
                            Positioned(left: 0, child: _buildButton("◄", "dpad_left", AppTheme.cyanGlow, size: 42)),
                            Positioned(right: 0, child: _buildButton("►", "dpad_right", AppTheme.cyanGlow, size: 42)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildJoystick("left", _leftStickDelta),
                    ],
                  ),

                  // Right Cluster: ABXY Action Diamond & Right Stick
                  Column(
                    children: [
                      // ABXY Diamond
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(top: 0, child: _buildButton("Y", "y", const Color(0xFFFFD600), size: 44)),
                            Positioned(bottom: 0, child: _buildButton("A", "a", const Color(0xFF00E676), size: 44)),
                            Positioned(left: 0, child: _buildButton("X", "x", const Color(0xFF2979FF), size: 44)),
                            Positioned(right: 0, child: _buildButton("B", "b", const Color(0xFFFF1744), size: 44)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildJoystick("right", _rightStickDelta),
                    ],
                  ),
                ],
              ),
              const Spacer(),

              // Bottom Status
              Container(
                margin: const EdgeInsets.only(bottom: 50),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_esports_rounded, color: AppTheme.cyanGlow, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "يد تحكم افتراضية XInput • عصاتي أنالوج تناظرية ومحفزات تصويب وإطلاق",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
