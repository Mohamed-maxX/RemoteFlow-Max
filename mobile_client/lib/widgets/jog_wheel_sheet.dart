import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/connection_provider.dart';

class JogWheelSheet extends ConsumerStatefulWidget {
  const JogWheelSheet({super.key});

  @override
  ConsumerState<JogWheelSheet> createState() => _JogWheelSheetState();
}

class _JogWheelSheetState extends ConsumerState<JogWheelSheet> {
  double _currentAngle = 0.0;
  double _accumulatedDelta = 0.0;
  Offset _center = Offset.zero;

  void _onPanStart(DragStartDetails details, Size size) {
    _center = Offset(size.width / 2, size.height / 2);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final touchPos = details.localPosition;
    final dx = touchPos.dx - _center.dx;
    final dy = touchPos.dy - _center.dy;
    final angle = math.atan2(dy, dx);

    var diff = angle - _currentAngle;
    if (diff > math.pi) diff -= 2 * math.pi;
    if (diff < -math.pi) diff += 2 * math.pi;

    _currentAngle = angle;
    _accumulatedDelta += diff;

    // Dispatches tick for every ~15 degrees (0.22 radians) of rotation
    const tickThreshold = 0.22;
    if (_accumulatedDelta.abs() >= tickThreshold) {
      final direction = _accumulatedDelta > 0 ? 1.0 : -1.0;
      ref.read(connectionProvider.notifier).sendJog(direction * 1.5);
      _accumulatedDelta = 0.0;
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(top: BorderSide(color: AppTheme.orangeNeon, width: 2)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.orangeNeon.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeNeon.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.rotate_right_rounded, color: AppTheme.orangeNeon, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "عجلة التمرير الدائرية (Jog Wheel)",
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "قم بتدوير إصبعك للتنقل إطاراً بإطار في المونتاج أو تقريب وتكبير التصاميم بدقة",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const Spacer(),
            // Interactive Rotary Dial
            Center(
              child: SizedBox(
                width: 230,
                height: 230,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanStart: (d) => _onPanStart(d, size),
                      onPanUpdate: _onPanUpdate,
                      child: CustomPaint(
                        painter: _DialPainter(angle: _currentAngle),
                        child: Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.bgDark,
                              border: Border.all(color: AppTheme.orangeNeon.withOpacity(0.6), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.orangeNeon.withOpacity(0.25),
                                  blurRadius: 18,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.touch_app_rounded, color: AppTheme.orangeNeon, size: 36),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double angle;

  _DialPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer Dial Track
    final trackPaint = Paint()
      ..color = AppTheme.bgCardHover
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, radius - 14, trackPaint);

    // Graduation Tick Marks
    final tickPaint = Paint()
      ..color = AppTheme.textMuted.withOpacity(0.5)
      ..strokeWidth = 2;

    const numTicks = 36;
    for (int i = 0; i < numTicks; i++) {
      final tickAngle = (i * 2 * math.pi) / numTicks;
      final isMajor = i % 3 == 0;
      final tickLen = isMajor ? 12.0 : 6.0;
      final innerR = radius - 26;
      final outerR = innerR + tickLen;

      final p1 = Offset(center.dx + innerR * math.cos(tickAngle), center.dy + innerR * math.sin(tickAngle));
      final p2 = Offset(center.dx + outerR * math.cos(tickAngle), center.dy + outerR * math.sin(tickAngle));

      tickPaint.color = isMajor ? AppTheme.orangeNeon.withOpacity(0.8) : AppTheme.textMuted.withOpacity(0.4);
      tickPaint.strokeWidth = isMajor ? 2.5 : 1.5;
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Active Rotary Marker
    final markerPaint = Paint()
      ..color = AppTheme.orangeNeon
      ..style = PaintingStyle.fill;

    final markerPos = Offset(
      center.dx + (radius - 14) * math.cos(angle),
      center.dy + (radius - 14) * math.sin(angle),
    );
    canvas.drawCircle(markerPos, 9, markerPaint);

    final glowPaint = Paint()
      ..color = AppTheme.orangeNeon.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(markerPos, 13, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) => oldDelegate.angle != angle;
}
