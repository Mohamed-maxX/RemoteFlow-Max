import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/presentation_provider.dart';

class PresentationScreen extends ConsumerWidget {
  const PresentationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(presentationProvider);
    final notifier = ref.read(presentationProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          children: [
            // Section 1: Presentation Stopwatch Timer
            _buildTimerCard(context, state, notifier),
            const SizedBox(height: 18),

            // Section 2: Huge Slide Remote Control Deck
            _buildSlideRemoteDeck(context, notifier),
            const SizedBox(height: 18),

            // Section 3: Slide Deck Utilities Bar (F5, Esc, Blackout B, Whiteout W)
            _buildSlideUtilitiesBar(notifier),
            const SizedBox(height: 24),

            // Section 4: Auto-Scroll Teleprompter Deck
            _buildTeleprompterDeck(context, state, notifier),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard(
    BuildContext context,
    PresentationState state,
    PresentationNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.cyanGlow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_outlined, color: AppTheme.cyanGlow, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("الوقت المنقضي", style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(
                    state.formattedTimer,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  state.isTimerRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: state.isTimerRunning ? AppTheme.orangeNeon : AppTheme.greenActive,
                  size: 34,
                ),
                onPressed: () {
                  notifier.toggleTimer();
                  HapticFeedback.lightImpact();
                },
              ),
              IconButton(
                icon: const Icon(Icons.replay_rounded, color: AppTheme.textSecondary, size: 24),
                onPressed: () {
                  notifier.resetTimer();
                  HapticFeedback.mediumImpact();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlideRemoteDeck(BuildContext context, PresentationNotifier notifier) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Next Slide Card (RTL: right side is next, or vice versa)
          Expanded(
            flex: 6,
            child: _buildBigSlideButton(
              label: "الشريحة التالية",
              icon: Icons.skip_next_rounded,
              color: AppTheme.cyanGlow,
              isPrimary: true,
              onTap: () {
                notifier.slideAction("next");
                HapticFeedback.heavyImpact();
              },
            ),
          ),
          const SizedBox(width: 12),
          // Previous Slide Card
          Expanded(
            flex: 5,
            child: _buildBigSlideButton(
              label: "الشريحة السابقة",
              icon: Icons.skip_previous_rounded,
              color: AppTheme.purpleNeon,
              onTap: () {
                notifier.slideAction("prev");
                HapticFeedback.heavyImpact();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBigSlideButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary ? color.withOpacity(0.18) : AppTheme.bgSurface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withOpacity(isPrimary ? 0.8 : 0.4),
            width: isPrimary ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isPrimary ? 0.25 : 0.08),
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isPrimary ? 54 : 44),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideUtilitiesBar(PresentationNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSmallActionPill("F5 بدء العرض", () => notifier.slideAction("start"), AppTheme.cyanGlow),
          _buildSmallActionPill("شاشة سوداء (B)", () => notifier.slideAction("blackout"), Colors.grey),
          _buildSmallActionPill("شاشة بيضاء (W)", () => notifier.slideAction("whiteout"), Colors.white70),
          _buildSmallActionPill("ESC إنهاء", () => notifier.slideAction("exit"), AppTheme.redAlert),
        ],
      ),
    );
  }

  Widget _buildSmallActionPill(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTeleprompterDeck(
    BuildContext context,
    PresentationState state,
    PresentationNotifier notifier,
  ) {
    final active = state.teleprompterActive;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppTheme.orangeNeon : AppTheme.borderSubtle,
          width: active ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Icon(Icons.text_snippet_outlined, color: AppTheme.orangeNeon, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "المُلقن الآلي (Teleprompter)",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Switch(
                value: active,
                activeColor: AppTheme.orangeNeon,
                onChanged: (_) {
                  notifier.toggleTeleprompter();
                  HapticFeedback.mediumImpact();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "تمرير شاشة تلقائي ومستمر لقراءة النصوص والملاحظات دون لمس الجهاز",
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("سرعة التمرير", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text(
                "${state.teleprompterSpeed.toStringAsFixed(1)}x",
                style: const TextStyle(color: AppTheme.orangeNeon, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.orangeNeon,
              thumbColor: AppTheme.orangeNeon,
              inactiveTrackColor: AppTheme.bgCardHover,
            ),
            child: Slider(
              value: state.teleprompterSpeed.clamp(0.5, 10.0),
              min: 0.5,
              max: 10.0,
              divisions: 19,
              onChanged: (val) => notifier.setSpeed(val),
            ),
          ),
        ],
      ),
    );
  }
}
