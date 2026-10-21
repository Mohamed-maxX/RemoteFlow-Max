import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/connection_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/touchpad_settings_provider.dart';
import 'connection_modal.dart';
import 'update_sheet.dart';

class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final settings = ref.watch(touchpadSettingsProvider);
    final settingsNotifier = ref.read(touchpadSettingsProvider.notifier);
    final conn = ref.watch(connectionProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.bgDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: theme.primaryColor, width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            )
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.settings_suggest_rounded, color: theme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "مركز الضبط والتخصيص",
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "تخصيص الثيم ولوحة اللمس والتحديثات",
                          style: GoogleFonts.cairo(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrollable Content
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // 1. Theme Selection Section
                  _buildSectionHeader(
                    icon: Icons.palette_rounded,
                    title: "مظهر وثيم التطبيق (3 ثيمات فاخرة)",
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeCard(
                          mode: AppThemeMode.cinematicNeon,
                          title: "نيون سينمائي",
                          subtitle: "كحلي وكهربائي",
                          icon: Icons.auto_awesome_rounded,
                          accent: const Color(0xFF00E5FF),
                          currentMode: theme.mode,
                          onSelect: () => themeNotifier.setTheme(AppThemeMode.cinematicNeon),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeCard(
                          mode: AppThemeMode.floatingGlass,
                          title: "زجاجي عائم",
                          subtitle: "طبقات كريستال",
                          icon: Icons.blur_on_rounded,
                          accent: const Color(0xFF38BDF8),
                          currentMode: theme.mode,
                          onSelect: () => themeNotifier.setTheme(AppThemeMode.floatingGlass),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildThemeCard(
                          mode: AppThemeMode.cyberGaming,
                          title: "ألعاب داكن",
                          subtitle: "كاربون وأخضر",
                          icon: Icons.sports_esports_rounded,
                          accent: const Color(0xFF10B981),
                          currentMode: theme.mode,
                          onSelect: () => themeNotifier.setTheme(AppThemeMode.cyberGaming),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. In-App Updates Button
                  _buildSectionHeader(
                    icon: Icons.system_update_rounded,
                    title: "التحديثات المباشرة من السيرفر",
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.cardFillColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.cardBorderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.cloud_download_rounded, color: theme.primaryColor, size: 22),
                      ),
                      title: Text(
                        "فحص التحديثات وتثبيتها الآن",
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        "التحقق من ملف APK بالسيرفر وتحميله وتثبيته مباشرة",
                        style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const UpdateSheet(),
                          );
                        },
                        child: Text(
                          "فحص الآن",
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Touchpad Settings
                  _buildSectionHeader(
                    icon: Icons.mouse_rounded,
                    title: "إعدادات حركة لوحة اللمس",
                    theme: theme,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardFillColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.cardBorderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "حساسية حركة المؤشر (Sensitivity)",
                              style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                            ),
                            Text(
                              "${settings.sensitivity.toStringAsFixed(1)}x",
                              style: GoogleFonts.cairo(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.primaryColor,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: theme.primaryColor,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: settings.sensitivity.clamp(0.2, 3.0),
                            min: 0.2,
                            max: 3.0,
                            divisions: 14,
                            onChanged: (val) => settingsNotifier.setSensitivity(val),
                          ),
                        ),
                        const Divider(color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "سرعة شريط التمرير (Scroll Speed)",
                              style: GoogleFonts.cairo(color: Colors.white, fontSize: 13),
                            ),
                            Text(
                              "${settings.scrollSpeed.toStringAsFixed(1)}x",
                              style: GoogleFonts.cairo(
                                color: theme.secondaryAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: theme.secondaryAccent,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: theme.secondaryAccent,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: settings.scrollSpeed.clamp(0.5, 5.0),
                            min: 0.5,
                            max: 5.0,
                            divisions: 18,
                            onChanged: (val) => settingsNotifier.setScrollSpeed(val),
                          ),
                        ),
                        const Divider(color: Colors.white10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "تبديل أزرار الماوس (كليك شمال / يمين)",
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                          subtitle: Text(
                            settings.swapMouseButtons ? "الوضع الحالي: كليك يمين يساراً، كليك شمال يميناً" : "الوضع الطبيعي: كليك شمال يساراً، كليك يمين يميناً",
                            style: GoogleFonts.cairo(color: Colors.white38, fontSize: 10),
                          ),
                          value: settings.swapMouseButtons,
                          activeColor: theme.secondaryAccent,
                          onChanged: (_) => settingsNotifier.toggleSwapMouseButtons(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "عكس اتجاه التمرير الرأسي (Invert Scroll)",
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                          value: settings.invertScroll,
                          activeColor: theme.primaryColor,
                          onChanged: (_) => settingsNotifier.toggleInvertScroll(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "النقر باللمس الخفيف (Tap to Click)",
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                          value: settings.tapToClick,
                          activeColor: theme.primaryColor,
                          onChanged: (_) => settingsNotifier.toggleTapToClick(),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            "الاهتزاز اللمسي عند الضغط (Haptic Feedback)",
                            style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                          ),
                          value: settings.hapticsEnabled,
                          activeColor: theme.primaryColor,
                          onChanged: (_) => settingsNotifier.toggleHaptics(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Host Info Footer & Reconnect Shortcut
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      ConnectionModal.show(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering_rounded, color: theme.primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "الخادم المقترن: ${conn.hostIp.isNotEmpty ? conn.hostIp : '192.168.1.6'}",
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "المنفذ: ${conn.wsPort} • الاستجابة: ${conn.latencyMs} ms (انقر لتغيير السيرفر)",
                                  style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.primaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required ThemeConfig theme,
  }) {
    return Row(
      children: [
        Icon(icon, color: theme.primaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard({
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required AppThemeMode currentMode,
    required VoidCallback onSelect,
  }) {
    final isSelected = (mode == currentMode);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onSelect();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.18) : const Color(0x22131F37),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Colors.white12,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? accent : Colors.white60, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: isSelected ? accent : Colors.white38,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
