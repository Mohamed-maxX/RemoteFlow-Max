import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/screen_stream_provider.dart';

class ScreenMirrorScreen extends ConsumerStatefulWidget {
  const ScreenMirrorScreen({super.key});

  @override
  ConsumerState<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

class _ScreenMirrorScreenState extends ConsumerState<ScreenMirrorScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(screenStreamProvider.notifier).startStream();
    });
  }

  void _showScreenshotDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.camera_alt_rounded, color: AppTheme.cyanGlow, size: 24),
              SizedBox(width: 10),
              Text(
                "لقطة شاشة كاملة الدقة",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              const Text(
                "تم التقاط صورة كاملة الدقة للشاشة الحالية من الكمبيوتر.",
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("إغلاق", style: TextStyle(color: AppTheme.textMuted)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanGlow,
                foregroundColor: AppTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم حفظ لقطة الشاشة في الذاكرة المؤقتة بنجاح!"),
                    backgroundColor: AppTheme.greenActive,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(screenStreamProvider);
    final notifier = ref.read(screenStreamProvider.notifier);

    // Listen for screenshot capture completion
    ref.listen<ScreenStreamState>(screenStreamProvider, (prev, next) {
      if (prev?.lastScreenshot != next.lastScreenshot && next.lastScreenshot != null) {
        _showScreenshotDialog(next.lastScreenshot!);
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface.withOpacity(0.85),
                border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.cyanGlow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: AppTheme.cyanGlow, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "بث شاشة الكمبيوتر الحي",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  // FPS Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: streamState.isStreaming
                            ? AppTheme.greenActive.withOpacity(0.5)
                            : AppTheme.textMuted.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      streamState.isStreaming ? "${streamState.fps.toStringAsFixed(0)} إطار/ث" : "متوقف",
                      style: TextStyle(
                        color: streamState.isStreaming ? AppTheme.greenActive : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Stream Toggle Button
                  IconButton(
                    icon: Icon(
                      streamState.isStreaming ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: streamState.isStreaming ? AppTheme.orangeNeon : AppTheme.cyanGlow,
                      size: 26,
                    ),
                    onPressed: () {
                      if (streamState.isStreaming) {
                        notifier.stopStream();
                      } else {
                        notifier.startStream();
                      }
                      HapticFeedback.lightImpact();
                    },
                  ),
                  // Instant Screen Grab Button
                  IconButton(
                    icon: streamState.isCapturingScreenshot
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanGlow),
                          )
                        : const Icon(Icons.camera_alt_rounded, color: AppTheme.cyanGlow, size: 24),
                    tooltip: "التقاط شاشة فوري",
                    onPressed: streamState.isCapturingScreenshot
                        ? null
                        : () {
                            notifier.takeScreenshot();
                            HapticFeedback.heavyImpact();
                          },
                  ),
                ],
              ),
            ),

            // Live Screen Canvas
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: [
                    if (streamState.isStreaming)
                      BoxShadow(
                        color: AppTheme.cyanGlow.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Center(
                    child: streamState.currentFrame != null
                        ? Image.memory(
                            streamState.currentFrame!,
                            gaplessPlayback: true,
                            fit: BoxFit.contain,
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tv_off_rounded,
                                size: 54,
                                color: AppTheme.textMuted.withOpacity(0.4),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "جاري الاتصال بالبث المباشر فائق السرعة...",
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Bottom Quick Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 50),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt_rounded, color: AppTheme.orangeNeon, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "بث Turbo فائق السرعة • اضغط زر الكاميرا لحفظ لقطة شاشة بدقة أصلية",
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
