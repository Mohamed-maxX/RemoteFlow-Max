import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../models/audio_state.dart';
import '../providers/audio_provider.dart';
import '../providers/theme_provider.dart';

class AudioDeckScreen extends ConsumerStatefulWidget {
  const AudioDeckScreen({super.key});

  @override
  ConsumerState<AudioDeckScreen> createState() => _AudioDeckScreenState();
}

class _AudioDeckScreenState extends ConsumerState<AudioDeckScreen> {
  // Independent local drag tracking for Master Volume
  double? _activeDragMasterVolume;
  bool _isDraggingMaster = false;
  Timer? _masterReleaseTimer;

  // Independent local drag tracking for Per-App Volume sliders
  final Map<String, double> _draggingAppVolumes = {};
  final Set<String> _activeAppDrags = {};
  final Map<String, Timer> _appReleaseTimers = {};

  @override
  void dispose() {
    _masterReleaseTimer?.cancel();
    for (final timer in _appReleaseTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  String _sessionKey(int pid, String rawName) => "${pid}_$rawName";

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final audioNotifier = ref.read(audioProvider.notifier);
    final theme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          // Section: Global Microphone Kill-Switch
          _buildMicKillSwitch(context, audio, audioNotifier, theme),
          const SizedBox(height: 16),

          // Section: Master Volume & Device (with decoupled touch slider)
          _buildMasterVolumeCard(context, audio, audioNotifier, theme),
          const SizedBox(height: 16),

          // Section: Media Transport Deck
          _buildMediaTransportBar(context, audioNotifier, theme),
          const SizedBox(height: 22),

          // Section Header: Per-App Volume Mixer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: theme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "التحكم في صوت التطبيقات المفتوحة",
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${audio.sessions.length} تطبيق نشط",
                  style: GoogleFonts.cairo(
                    color: theme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Per-App Sessions List
          if (audio.sessions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardFillColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.cardBorderColor, width: 1.2),
              ),
              child: Column(
                children: [
                  Icon(Icons.volume_mute_rounded, size: 36, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  Text(
                    "لا توجد تطبيقات نشطة تُخرج صوتاً حالياً في ويندوز",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...audio.sessions.map((s) => _buildAppSessionCard(context, s, audioNotifier, theme)),
        ],
      ),
    );
  }

  Widget _buildMicKillSwitch(
    BuildContext context,
    AudioStateModel audio,
    AudioNotifier notifier,
    ThemeConfig theme,
  ) {
    final isMuted = audio.micMuted;
    return GestureDetector(
      onTap: () {
        notifier.toggleMicMute();
        HapticFeedback.heavyImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isMuted ? AppTheme.redAlert.withOpacity(0.15) : theme.cardFillColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMuted ? AppTheme.redAlert : theme.primaryColor.withOpacity(0.5),
            width: isMuted ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isMuted ? AppTheme.redAlert : theme.primaryColor).withOpacity(0.18),
              blurRadius: 18,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMuted ? AppTheme.redAlert.withOpacity(0.25) : theme.primaryColor.withOpacity(0.2),
              ),
              child: Icon(
                isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: isMuted ? AppTheme.redAlert : theme.primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMuted ? "الميكروفون مكتوم حالياً (Muted)" : "الميكروفون مفعّل ويعمل (Live)",
                    style: GoogleFonts.cairo(
                      color: isMuted ? AppTheme.redAlert : theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    isMuted ? "اضغط لإلغاء كتم الميكروفون فوراً" : "اضغط لكتم الميكروفون الفوري (Kill-Switch)",
                    style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isMuted ? AppTheme.redAlert : theme.primaryColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isMuted ? AppTheme.redAlert : theme.primaryColor.withOpacity(0.5)),
              ),
              child: Text(
                isMuted ? "مكتوم" : "مفعّل",
                style: GoogleFonts.cairo(
                  color: isMuted ? Colors.white : theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterVolumeCard(
    BuildContext context,
    AudioStateModel audio,
    AudioNotifier notifier,
    ThemeConfig theme,
  ) {
    // Decoupled Master Volume calculation:
    // If the user is currently touching/dragging, show local finger position.
    // If not touching, show the confirmed server volume.
    final displayVolume = _isDraggingMaster
        ? (_activeDragMasterVolume ?? audio.masterVolume).clamp(0.0, 1.0)
        : audio.masterVolume.clamp(0.0, 1.0);

    final displayPercent = (displayVolume * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardFillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "مستوى الصوت العام (Master Volume)",
                    style: GoogleFonts.cairo(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    audio.masterDevice.isNotEmpty ? audio.masterDevice : "جهاز الصوت الافتراضي",
                    style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    "$displayPercent%",
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      audio.masterMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: audio.masterMuted ? AppTheme.redAlert : theme.primaryColor,
                    ),
                    onPressed: () {
                      notifier.toggleMasterMute();
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.primaryColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: theme.primaryColor,
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: displayVolume,
              // ONLY dispatch to server when touched and moved by user!
              onChangeStart: (val) {
                _masterReleaseTimer?.cancel();
                setState(() {
                  _isDraggingMaster = true;
                  _activeDragMasterVolume = val;
                });
              },
              onChanged: (val) {
                setState(() {
                  _activeDragMasterVolume = val;
                });
              },
              onChangeEnd: (val) {
                // Send the definitive audio change to Windows host
                notifier.setMasterVolume(val);
                HapticFeedback.lightImpact();

                // Buffer release to prevent incoming echo packets from snapping the slider
                _masterReleaseTimer?.cancel();
                _masterReleaseTimer = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    setState(() {
                      _isDraggingMaster = false;
                      _activeDragMasterVolume = null;
                    });
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTransportBar(
    BuildContext context,
    AudioNotifier notifier,
    ThemeConfig theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardFillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.cardBorderColor, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaBtn(Icons.skip_previous_rounded, "السابق", () => notifier.mediaAction("prev"), theme),
          _buildMediaBtn(Icons.replay_10_rounded, "10 ثواني للخلف", () => notifier.mediaAction("prev"), theme),
          _buildPlayPauseBtn(notifier, theme),
          _buildMediaBtn(Icons.forward_10_rounded, "10 ثواني للأمام", () => notifier.mediaAction("next"), theme),
          _buildMediaBtn(Icons.skip_next_rounded, "التالي", () => notifier.mediaAction("next"), theme),
        ],
      ),
    );
  }

  Widget _buildPlayPauseBtn(AudioNotifier notifier, ThemeConfig theme) {
    return GestureDetector(
      onTap: () {
        notifier.mediaAction("play_pause");
        HapticFeedback.mediumImpact();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [theme.primaryColor, theme.accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 1,
            )
          ],
        ),
        child: const Center(
          child: Icon(Icons.play_arrow_rounded, color: Colors.black87, size: 30),
        ),
      ),
    );
  }

  Widget _buildMediaBtn(IconData icon, String tooltip, VoidCallback onTap, ThemeConfig theme) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 24),
      tooltip: tooltip,
      onPressed: () {
        onTap();
        HapticFeedback.lightImpact();
      },
    );
  }

  Widget _buildAppSessionCard(
    BuildContext context,
    AudioAppSession session,
    AudioNotifier notifier,
    ThemeConfig theme,
  ) {
    final key = _sessionKey(session.pid, session.rawName);
    final isDragging = _activeAppDrags.contains(key);
    final displayVolume = isDragging
        ? (_draggingAppVolumes[key] ?? session.volume).clamp(0.0, 1.0)
        : session.volume.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardFillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor, width: 1.0),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apps_rounded, color: theme.accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session.name,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                "${(displayVolume * 100).round()}%",
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
              ),
              IconButton(
                icon: Icon(
                  session.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: session.muted ? AppTheme.redAlert : theme.primaryColor,
                  size: 20,
                ),
                onPressed: () {
                  notifier.toggleAppMute(session.pid, session.rawName);
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: theme.accentColor,
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: displayVolume,
              onChangeStart: (val) {
                _appReleaseTimers[key]?.cancel();
                setState(() {
                  _activeAppDrags.add(key);
                  _draggingAppVolumes[key] = val;
                });
              },
              onChanged: (val) {
                setState(() {
                  _draggingAppVolumes[key] = val;
                });
              },
              onChangeEnd: (val) {
                notifier.setAppVolume(session.pid, session.rawName, val);
                HapticFeedback.lightImpact();

                _appReleaseTimers[key]?.cancel();
                _appReleaseTimers[key] = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    setState(() {
                      _activeAppDrags.remove(key);
                      _draggingAppVolumes.remove(key);
                    });
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
