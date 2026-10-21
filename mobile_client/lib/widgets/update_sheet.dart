import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../providers/connection_provider.dart';
import '../providers/live_ui_provider.dart';

class UpdateSheet extends ConsumerStatefulWidget {
  const UpdateSheet({super.key});

  @override
  ConsumerState<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<UpdateSheet> {
  bool _isChecking = false;
  String? _serverVersion;
  String? _downloadUrl;
  String? _releaseNotes;
  int _apkSize = 0;
  String? _errorMessage;
  bool _hasChecked = false;

  final String _currentVersion = "1.0.0";

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });
    HapticFeedback.lightImpact();

    const githubReleaseUrl = "https://github.com/Mohamed-maxX/RemoteFlow-Max/releases/latest/download/RemoteFlowMax.apk";
    final conn = ref.read(connectionProvider);
    final hostIp = conn.hostIp.isNotEmpty ? conn.hostIp : "192.168.1.6";
    final url = Uri.parse("http://$hostIp:5058/api/update/check");

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _serverVersion = data["version"] as String? ?? "1.0.0";
          _downloadUrl = data["download_url"] as String? ?? githubReleaseUrl;
          _releaseNotes = data["release_notes"] as String? ?? "تحديث فوري لـ RemoteFlow Max (OTA)";
          _apkSize = (data["size"] as int?) ?? 29000000;
          _hasChecked = true;
          _isChecking = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback: Check GitHub Releases directly
    try {
      final ghUrl = Uri.parse("https://api.github.com/repos/Mohamed-maxX/RemoteFlow-Max/releases/latest");
      final ghRes = await http.get(ghUrl, headers: {"User-Agent": "RemoteFlow-Max"}).timeout(const Duration(seconds: 4));
      if (ghRes.statusCode == 200) {
        final ghData = jsonDecode(ghRes.body) as Map<String, dynamic>;
        final tag = ghData["tag_name"] as String? ?? "1.0.0";
        final cleanVer = tag.replaceAll("v", "");
        final body = ghData["body"] as String? ?? "تحديث رسمي متاح عبر GitHub Releases.";
        setState(() {
          _serverVersion = cleanVer;
          _downloadUrl = githubReleaseUrl;
          _releaseNotes = body;
          _apkSize = 29000000;
          _hasChecked = true;
          _isChecking = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _serverVersion = "1.0.0";
      _downloadUrl = githubReleaseUrl;
      _releaseNotes = "تحديث من مستودع GitHub الرسمي (RemoteFlow-Max).";
      _apkSize = 29000000;
      _hasChecked = true;
      _isChecking = false;
    });
  }

  Future<void> _startDownloadAndInstall() async {
    HapticFeedback.heavyImpact();
    final success = await ref.read(liveUIProvider.notifier).downloadAndInstallApk(directUrl: _downloadUrl);
    if (!success) {
      // Fallback to browser download if internal OTA fails
      if (_downloadUrl != null) {
        try {
          final uri = Uri.parse(_downloadUrl!);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkForUpdates());
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);
    final hostIp = conn.hostIp.isNotEmpty ? conn.hostIp : "192.168.1.6";
    final liveUI = ref.watch(liveUIProvider);
    final isNewer = _serverVersion != null && _serverVersion != _currentVersion;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(top: BorderSide(color: AppTheme.cyanNeon, width: 1.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyanNeon.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cyanNeon.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cyanNeon.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.system_update_rounded, color: AppTheme.cyanNeon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "التحديثات والتثبيت الذاتي (OTA)",
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "تحديث تلقائي بدون أسلاك أو نقل يدوي للملفات",
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Version Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text("الإصدار الحالي", style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("v$_currentVersion", style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      Text("إصدار السيرفر", style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        _serverVersion != null ? "v$_serverVersion" : "جاري الفحص...",
                        style: GoogleFonts.cairo(
                          color: isNewer ? AppTheme.orangeNeon : AppTheme.cyanNeon,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 30, color: Colors.white12),
                  Column(
                    children: [
                      Text("السيرفر", style: GoogleFonts.cairo(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(hostIp, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Status or Error Message
            if (_isChecking)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanNeon),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "جاري فحص التحديثات من سيرفر الكمبيوتر...",
                      style: GoogleFonts.cairo(color: AppTheme.cyanNeon, fontSize: 12),
                    ),
                  ],
                ),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.redAlert.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.redAlert.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.redAlert, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.cairo(color: AppTheme.redAlert, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else if (_hasChecked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isNewer ? AppTheme.orangeNeon : AppTheme.greenActive).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (isNewer ? AppTheme.orangeNeon : AppTheme.greenActive).withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isNewer ? Icons.new_releases_rounded : Icons.check_circle_rounded,
                          color: isNewer ? AppTheme.orangeNeon : AppTheme.greenActive,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isNewer
                                ? "يتوفر إصدار جديد جاهز للترقية: v$_serverVersion"
                                : "التطبيق محدث إلى أحدث إصدار متاح (v$_serverVersion)",
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_apkSize > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        "حجم حزمة التثبيت: ${(_apkSize / (1024 * 1024)).toStringAsFixed(1)} ميجابايت",
                        style: GoogleFonts.cairo(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                    if (_releaseNotes != null && _releaseNotes!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        "ملاحظات التحديث:",
                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cyanNeon),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _releaseNotes!,
                        style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),

            // In-App Download Progress Indicator
            if (liveUI.isDownloading) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cyanNeon.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "جاري تحميل التحديث...",
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          "${(liveUI.downloadProgress * 100).toStringAsFixed(0)}%",
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w900, color: AppTheme.cyanNeon, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: liveUI.downloadProgress > 0 ? liveUI.downloadProgress : null,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyanNeon),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "سيتم فتح شاشة التثبيت تلقائياً فور اكتمال التحميل",
                      style: GoogleFonts.cairo(fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],

            if (liveUI.downloadError != null && !liveUI.isDownloading) ...[
              const SizedBox(height: 10),
              Text(
                liveUI.downloadError!,
                style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.redAlert),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text("إعادة الفحص", style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cyanNeon,
                      side: const BorderSide(color: AppTheme.cyanNeon),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isChecking || liveUI.isDownloading ? null : _checkForUpdates,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 5,
                  child: ElevatedButton.icon(
                    icon: liveUI.isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.system_update_alt_rounded, size: 20),
                    label: Text(
                      liveUI.isDownloading
                          ? "جاري التنزيل..."
                          : (isNewer ? "تثبيت التحديث الآن" : "تنزيل الـ APK مجدداً"),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNewer ? AppTheme.orangeNeon : AppTheme.cyanNeon,
                      foregroundColor: isNewer ? Colors.white : AppTheme.bgDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: (_downloadUrl != null && !liveUI.isDownloading) ? _startDownloadAndInstall : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
