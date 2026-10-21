import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../services/ws_service.dart';
import '../providers/connection_provider.dart';
import '../providers/security_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/live_ui_provider.dart';
import '../widgets/connection_modal.dart';
import '../widgets/pin_auth_dialog.dart';
import '../widgets/settings_modal.dart';
import '../widgets/update_sheet.dart';
import 'touchpad_screen.dart';
import 'audio_deck_screen.dart';
import 'stream_deck_screen.dart';
import 'file_explorer_screen.dart';
import 'screen_and_game_screen.dart';
import 'system_deck_screen.dart';

class MainDeckScreen extends ConsumerStatefulWidget {
  const MainDeckScreen({super.key});

  @override
  ConsumerState<MainDeckScreen> createState() => _MainDeckScreenState();
}

class _MainDeckScreenState extends ConsumerState<MainDeckScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TouchpadScreen(),
    AudioDeckScreen(),
    StreamDeckScreen(),
    FileExplorerScreen(),
    ScreenAndGameScreen(),
    SystemDeckScreen(),
  ];

  // Smart concise titles: guaranteed zero text truncation
  final List<({String title, IconData icon})> _navItems = const [
    (title: "الماوس", icon: Icons.mouse_rounded),
    (title: "الصوت", icon: Icons.volume_up_rounded),
    (title: "الماكرو", icon: Icons.grid_view_rounded),
    (title: "الملفات", icon: Icons.folder_rounded),
    (title: "الألعاب", icon: Icons.sports_esports_rounded),
    (title: "النظام", icon: Icons.speed_rounded),
  ];

  void _openSettingsModal() {
    SettingsModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);
    final theme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final liveUI = ref.watch(liveUIProvider);

    // Auto-prompt PIN dialog if host requires PIN and not yet authenticated
    ref.listen<SecurityState>(securityProvider, (prev, next) {
      if (next.pinRequired && !next.isAuthenticated) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PinAuthDialog(),
        );
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.bgDark,
        body: Stack(
          children: [
            // Deep Luxury Fluid Background Mesh
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(gradient: theme.bgGradient),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/bg_glassmorphism.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

            SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // Active Deck Screen (IndexedStack preserves tabs state completely)
                  Column(
                    children: [
                      _buildTopStatusBar(conn, theme, themeNotifier, liveUI),
                      if (liveUI.hasNewApk) _buildOTABanner(liveUI, theme),
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: _screens,
                        ),
                      ),
                    ],
                  ),

                  // Floating Frosted-Glass Navigation Bar
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildFloatingNavBar(theme, liveUI),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTABanner(LiveUIState liveUI, ThemeConfig theme) {
    final ver = liveUI.apkMetadata?['version'] ?? 'جديد';
    final isDownloading = liveUI.isDownloading;
    final progress = (liveUI.downloadProgress * 100).toInt();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFF6A1B9A)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orangeNeon.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isDownloading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                value: liveUI.downloadProgress > 0 ? liveUI.downloadProgress : null,
                color: Colors.white,
              ),
            )
          else
            const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (isDownloading) return;
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const UpdateSheet(),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDownloading
                        ? "جاري تحميل التحديث: $progress%"
                        : "تحديث جديد متوفر (v$ver) - انقر هنا",
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isDownloading
                        ? "سيتم تشغيل مثبت التحديث تلقائياً..."
                        : "انقر للتنزيل والتثبيت الفوري بدون كابلات",
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isDownloading) ...[
            IconButton(
              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              tooltip: "تثبيت الآن",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                HapticFeedback.heavyImpact();
                ref.read(liveUIProvider.notifier).downloadAndInstallApk();
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              tooltip: "إخفاء",
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(liveUIProvider.notifier).dismissApkAlert();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopStatusBar(
    ConnectionStateModel conn,
    ThemeConfig theme,
    ThemeNotifier themeNotifier,
    LiveUIState liveUI,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardFillColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.cardBorderColor,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // App Logo Mini Badge
          GestureDetector(
            onTap: _openSettingsModal,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Center(
                child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Host / Status Button
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                ConnectionModal.show(context);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          conn.serverName ?? "RemoteFlow Host",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down_rounded, color: theme.primaryColor, size: 18),
                    ],
                  ),
                  Text(
                    conn.hostIp.isNotEmpty ? conn.hostIp : "192.168.1.6",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Latency & Connection Status Pill
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (!conn.isConnected) {
                // Immediate explicit reconnect to the current server address
                ref.read(connectionProvider.notifier).connect(
                  ip: conn.hostIp,
                  wsPort: conn.wsPort,
                  udpPort: conn.udpPort,
                );
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'جاري الاتصال فوراً بـ ${conn.hostIp}...',
                          style: GoogleFonts.cairo(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                    backgroundColor: theme.bgSurface,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                  ),
                );
              } else {
                ConnectionModal.show(context);
              }
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              ConnectionModal.show(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (conn.isConnected ? AppTheme.emeraldNeon : AppTheme.redAlert).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (conn.isConnected ? AppTheme.emeraldNeon : AppTheme.redAlert).withOpacity(0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: conn.isConnected ? AppTheme.emeraldNeon : AppTheme.redAlert,
                      boxShadow: [
                        if (conn.isConnected)
                          BoxShadow(
                            color: AppTheme.emeraldNeon.withOpacity(0.6),
                            blurRadius: 6,
                          )
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    conn.isConnected
                        ? "${conn.latencyMs} ms"
                        : (conn.status == ConnectionStatus.connecting ? "جاري..." : "غير متصل"),
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: conn.isConnected
                          ? AppTheme.emeraldNeon
                          : (conn.status == ConnectionStatus.connecting ? theme.primaryColor : AppTheme.redAlert),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Quick Theme Switcher Button
          IconButton(
            icon: Icon(theme.icon, color: theme.primaryColor, size: 20),
            tooltip: "تبديل الثيم: ${theme.title}",
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              HapticFeedback.lightImpact();
              themeNotifier.cycleNext();
              final current = ref.read(themeProvider);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "تم التبديل إلى: ${current.title}",
                    style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: current.bgSurface,
                  duration: const Duration(milliseconds: 1400),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
          const SizedBox(width: 2),

          // Settings & Updates Button
          IconButton(
            icon: liveUI.hasNewApk
                ? const Badge(
                    backgroundColor: AppTheme.orangeNeon,
                    smallSize: 8,
                    child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                  )
                : const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
            tooltip: liveUI.hasNewApk ? "يتوفر تحديث جديد!" : "الضبط والتحديثات",
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              HapticFeedback.lightImpact();
              _openSettingsModal();
            },
          ),
          const SizedBox(width: 2),

          // Quick Lock Button
          IconButton(
            icon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 18),
            tooltip: "قفل الكمبيوتر (Win + L)",
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              HapticFeedback.heavyImpact();
              ref.read(connectionProvider.notifier).sendHotkey(["win", "l"]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("تم إرسال أمر قفل الشاشة للكمبيوتر", style: GoogleFonts.cairo()),
                  backgroundColor: theme.accentColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeConfig theme, LiveUIState liveUI) {
    final strings = liveUI.config.strings;
    final titles = [
      strings.navMouse,
      strings.navAudio,
      strings.navMacro,
      strings.navFiles,
      strings.navGame,
      strings.navSystem,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      height: 66,
      decoration: BoxDecoration(
        color: theme.cardFillColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.cardBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = _currentIndex == index;
              final dynamicTitle = index < titles.length ? titles[index] : item.title;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentIndex = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.all(isSelected ? 6 : 4),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.primaryColor.withOpacity(0.18) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            item.icon,
                            color: isSelected ? theme.primaryColor : Colors.white54,
                            size: isSelected ? 22 : 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dynamicTitle,
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.cairo(
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? theme.primaryColor : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
