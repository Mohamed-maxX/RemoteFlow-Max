import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../models/system_telemetry.dart';
import '../providers/telemetry_provider.dart';
import '../providers/power_provider.dart';

class SystemDeckScreen extends ConsumerWidget {
  const SystemDeckScreen({super.key});

  void _showShutdownDialog(BuildContext context, PowerNotifier powerNotifier) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.power_settings_new, color: AppTheme.redAlert, size: 24),
              SizedBox(width: 10),
              Text(
                "التحكم بالطاقة والإغلاق",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "اختر الإجراء أو حدد مؤقتاً تنازلياً لإيقاف تشغيل الكمبيوتر:",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTimerChip(ctx, "إغلاق فوري", 0, powerNotifier),
                  _buildTimerChip(ctx, "خلال 15 دقيقة", 900, powerNotifier),
                  _buildTimerChip(ctx, "خلال 30 دقيقة", 1800, powerNotifier),
                  _buildTimerChip(ctx, "خلال 60 دقيقة", 3600, powerNotifier),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.orangeNeon, size: 18),
                label: const Text(
                  "إلغاء الإغلاق المجدول",
                  style: TextStyle(color: AppTheme.orangeNeon, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.orangeNeon),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  powerNotifier.cancelShutdown();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم إلغاء مؤقت إيقاف التشغيل."),
                      backgroundColor: AppTheme.bgCard,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("إغلاق", style: TextStyle(color: AppTheme.textMuted)),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerChip(BuildContext ctx, String label, int seconds, PowerNotifier notifier) {
    return ActionChip(
      backgroundColor: AppTheme.bgCard,
      side: const BorderSide(color: AppTheme.borderSubtle),
      label: Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      onPressed: () {
        notifier.shutdownPc(timer: seconds);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.bgCard,
            content: Text(
              seconds == 0
                  ? "جاري إيقاف تشغيل الكمبيوتر الآن..."
                  : "تمت جدولة إيقاف التشغيل بعد ${seconds ~/ 60} دقيقة.",
            ),
          ),
        );
      },
    );
  }

  void _showWolDialog(BuildContext context, PowerNotifier powerNotifier) {
    final controller = TextEditingController(text: "00:11:22:33:44:55");
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppTheme.bgSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.settings_remote, color: AppTheme.cyanGlow, size: 24),
              SizedBox(width: 10),
              Text(
                "تشغيل الكمبيوتر عن بعد (WOL)",
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "إرسال حزمة سحرية (Magic Packet) عبر الشبكة لإيقاظ الكمبيوتر من وضع الإيقاف التام:",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: "عنوان الـ MAC للجهاز المستهدف",
                  labelStyle: const TextStyle(color: AppTheme.cyanGlow, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("إلغاء", style: TextStyle(color: AppTheme.textMuted)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanGlow,
                foregroundColor: AppTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("إرسال إشارة الإيقاظ", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                powerNotifier.wakeOnLan(controller.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم إرسال حزمة الإيقاظ بنجاح!"),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetry = ref.watch(telemetryProvider).current;
    final power = ref.watch(powerProvider);
    final powerNotifier = ref.read(powerProvider.notifier);

    // Show Flush RAM feedback if available
    ref.listen<PowerState>(powerProvider, (previous, next) {
      if (previous?.lastFlush != next.lastFlush && next.lastFlush != null) {
        final f = next.lastFlush!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.greenActive,
            content: Text(
              "🚀 تم تفريغ الرام بنجاح! تحرير ${f.freedMb} ميجابايت عبر ${f.processesTrimmed} تطبيق (${f.initialPercent}% -> ${f.newPercent}%)",
              style: const TextStyle(color: AppTheme.bgDark, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Section: Real-Time Hardware Performance Gauges
            _buildTelemetrySection(context, telemetry),
            const SizedBox(height: 16),

            // Section: Boss Key / Panic Button
            _buildBossKeyCard(context, powerNotifier),
            const SizedBox(height: 20),

            // Section Header: Power & Optimization Deck
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeNeon.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt, color: AppTheme.orangeNeon, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  "لوحة الطاقة وإدارة النظام",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildActionCard(
                  icon: Icons.cleaning_services_rounded,
                  title: "تنظيف فوري للرام",
                  subtitle: power.isFlushing ? "جاري التحرير..." : "تفريغ الذاكرة المؤقتة",
                  color: AppTheme.cyanGlow,
                  isLoading: power.isFlushing,
                  onTap: () {
                    powerNotifier.flushRam();
                    HapticFeedback.heavyImpact();
                  },
                ),
                _buildActionCard(
                  icon: Icons.coffee_rounded,
                  title: "منع السكون (Caffeine)",
                  subtitle: power.caffeine ? "نشط (الشاشة تعمل دائماً)" : "وضع الطاقة العادي",
                  color: power.caffeine ? AppTheme.orangeNeon : AppTheme.textMuted,
                  isActive: power.caffeine,
                  onTap: () {
                    powerNotifier.toggleCaffeine();
                    HapticFeedback.mediumImpact();
                  },
                ),
                _buildActionCard(
                  icon: Icons.lock_rounded,
                  title: "قفل الكمبيوتر",
                  subtitle: "Win + L تأمين فوري",
                  color: AppTheme.purpleNeon,
                  onTap: () {
                    powerNotifier.lockPc();
                    HapticFeedback.lightImpact();
                  },
                ),
                _buildActionCard(
                  icon: Icons.nights_stay_rounded,
                  title: "وضع السكون",
                  subtitle: "تعليق منخفض الطاقة",
                  color: Colors.blueAccent,
                  onTap: () {
                    powerNotifier.sleepPc();
                    HapticFeedback.mediumImpact();
                  },
                ),
                _buildActionCard(
                  icon: Icons.timer_outlined,
                  title: "مؤقت الإغلاق",
                  subtitle: "جدولة إطفاء الجهاز",
                  color: AppTheme.redAlert,
                  onTap: () => _showShutdownDialog(context, powerNotifier),
                ),
                _buildActionCard(
                  icon: Icons.restart_alt_rounded,
                  title: "إعادة التشغيل",
                  subtitle: "Reboot النظام كاملاً",
                  color: Colors.tealAccent,
                  onTap: () {
                    powerNotifier.restartPc();
                    HapticFeedback.heavyImpact();
                  },
                ),
                _buildActionCard(
                  icon: Icons.speed_rounded,
                  title: "أداء فائق (Turbo)",
                  subtitle: "تفعيل نمط الطاقة العالي",
                  color: AppTheme.orangeNeon,
                  onTap: () {
                    powerNotifier.setPowerProfile("high_performance");
                    HapticFeedback.selectionClick();
                  },
                ),
                _buildActionCard(
                  icon: Icons.settings_remote,
                  title: "إيقاظ عن بعد (WOL)",
                  subtitle: "تشغيل الكمبيوتر عبر الشبكة",
                  color: AppTheme.cyanGlow,
                  onTap: () => _showWolDialog(context, powerNotifier),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySection(BuildContext context, SystemTelemetry telemetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      color: AppTheme.greenActive.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.monitor_heart_rounded, color: AppTheme.greenActive, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "مراقبة موارد النظام المباشرة",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  "تشغيل: ${telemetry.uptimeSeconds ~/ 3600}س ${(telemetry.uptimeSeconds % 3600) ~/ 60}د",
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row of CPU & RAM Gauges
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: "استهلاك المعالج CPU",
                  value: "${telemetry.cpuPercent.round()}%",
                  subtext: "${telemetry.cpuCores.length} أنوية",
                  percent: (telemetry.cpuPercent / 100).clamp(0.0, 1.0),
                  color: AppTheme.cyanGlow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: "الذاكرة العشوائية RAM",
                  value: "${telemetry.ramPercent.round()}%",
                  subtext: "${telemetry.ramUsedGb} / ${telemetry.ramTotalGb} جيجابايت",
                  percent: (telemetry.ramPercent / 100).clamp(0.0, 1.0),
                  color: AppTheme.purpleNeon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row of Disk & Network Speed
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: "القرص الرئيسي (C:)",
                  value: "${telemetry.diskPercent.round()}%",
                  subtext: "${telemetry.diskUsedGb} / ${telemetry.diskTotalGb} جيجابايت",
                  percent: (telemetry.diskPercent / 100).clamp(0.0, 1.0),
                  color: AppTheme.orangeNeon,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "حركة الشبكة I/O",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, color: AppTheme.greenActive, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${telemetry.downloadKbps} KB/s",
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, color: AppTheme.cyanGlow, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${telemetry.uploadKbps} KB/s",
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required double percent,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Flexible(
                child: Text(
                  subtext,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppTheme.bgCardHover,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBossKeyCard(BuildContext context, PowerNotifier notifier) {
    return GestureDetector(
      onTap: () {
        notifier.bossKey();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.redAlert,
            content: Text(
              "🚨 تم تفعيل زر الطوارئ: تم تصغير كافة النوافذ وكتم الصوت فوراً!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF991B1B), Color(0xFF450A0A)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.redAlert.withOpacity(0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.redAlert.withOpacity(0.3),
              blurRadius: 18,
              spreadRadius: 2,
            )
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "زر الطوارئ السريع (Boss Key)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "نقرة واحدة: تصغير جميع النوافذ (Win+D) + كتم السماعات والمايك بالكامل",
                    style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : AppTheme.bgSurface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? color : AppTheme.borderSubtle,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanGlow),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isActive ? color : AppTheme.textMuted,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
