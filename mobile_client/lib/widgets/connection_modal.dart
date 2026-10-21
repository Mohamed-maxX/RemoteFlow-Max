import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_theme.dart';
import '../models/discovered_device.dart';
import '../providers/connection_provider.dart';
import '../services/discovery_service.dart';
import '../services/ws_service.dart';

class ConnectionModal extends ConsumerStatefulWidget {
  const ConnectionModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConnectionModal(),
    );
  }

  @override
  ConsumerState<ConnectionModal> createState() => _ConnectionModalState();
}

class _ConnectionModalState extends ConsumerState<ConnectionModal> {
  late TextEditingController _ipController;
  late TextEditingController _wsPortController;
  late TextEditingController _udpPortController;

  final DiscoveryService _discoveryService = DiscoveryService();
  List<DiscoveredDevice> _discoveredDevices = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final conn = ref.read(connectionProvider);
    _ipController = TextEditingController(text: conn.hostIp);
    _wsPortController = TextEditingController(text: conn.wsPort.toString());
    _udpPortController = TextEditingController(text: conn.udpPort.toString());

    _startDiscovery();
  }

  void _startDiscovery() {
    setState(() => _isSearching = true);
    _discoveryService.startDiscovery();
    _discoveryService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _handleConnect(String ip, int wsPort, int udpPort) async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final success = await ref.read(connectionProvider.notifier).connect(
          ip: ip,
          wsPort: wsPort,
          udpPort: udpPort,
        );

    if (!mounted) return;

    if (success) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "تم الاتصال بالكمبيوتر بنجاح!",
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.emeraldNeon,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "فشل الاتصال بـ $ip:$wsPort - تأكد من تشغيل السيرفر وجدار الحماية",
            style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppTheme.redAlert,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    _ipController.dispose();
    _wsPortController.dispose();
    _udpPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(connectionProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1427),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppTheme.cyanNeon.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyanNeon.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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

          // Header with Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.cyanGlowGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: AppTheme.bgDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "إعدادات الاتصال بالكمبيوتر",
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      conn.isConnected
                          ? "متصل حالياً • الاستجابة ${conn.latencyMs}ms"
                          : conn.status == ConnectionStatus.connecting
                              ? "جاري محاولة الاتصال..."
                              : "غير متصل بالسيرفر",
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: conn.isConnected
                            ? AppTheme.emeraldNeon
                            : conn.status == ConnectionStatus.connecting
                                ? AppTheme.cyanNeon
                                : AppTheme.redAlert,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // IP Address Field
          Text(
            "عنوان IP لجهاز الكمبيوتر (Host IP)",
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: AppTheme.glassDecoration(
              fillColor: const Color(0xFF131F37),
              borderColor: AppTheme.cyanNeon.withOpacity(0.4),
              borderRadius: 14,
            ),
            child: TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                hintText: "192.168.1.6",
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.desktop_windows_rounded, color: AppTheme.cyanNeon),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ports Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "منفذ الأوامر (WebSocket)",
                      style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: AppTheme.glassDecoration(
                        fillColor: const Color(0xFF131F37),
                        borderRadius: 12,
                      ),
                      child: TextField(
                        controller: _wsPortController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "منفذ الماوس (UDP)",
                      style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: AppTheme.glassDecoration(
                        fillColor: const Color(0xFF131F37),
                        borderRadius: 12,
                      ),
                      child: TextField(
                        controller: _udpPortController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Connect Action Button
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.cyanGlowGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyanNeon.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final ip = _ipController.text.trim();
                  final ws = int.tryParse(_wsPortController.text.trim()) ?? 5056;
                  final udp = int.tryParse(_udpPortController.text.trim()) ?? 5055;
                  _handleConnect(ip, ws, udp);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on_rounded, color: AppTheme.bgDark),
                      const SizedBox(width: 8),
                      Text(
                        conn.status == ConnectionStatus.connecting
                            ? "جاري الاتصال..."
                            : "اتصال الآن",
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.bgDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Disconnect or Re-discover
          if (conn.isConnected)
            TextButton.icon(
              onPressed: () {
                ref.read(connectionProvider.notifier).disconnect();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.link_off_rounded, color: AppTheme.redAlert),
              label: Text(
                "قطع الاتصال بالكمبيوتر",
                style: GoogleFonts.cairo(color: AppTheme.redAlert, fontWeight: FontWeight.bold),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            // Auto-Discovery Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "الأجهزة المكتشفة تلقائياً:",
                  style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                GestureDetector(
                  onTap: _startDiscovery,
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.cyanNeon),
                      const SizedBox(width: 4),
                      Text(
                        "إعادة البحث",
                        style: GoogleFonts.cairo(fontSize: 12, color: AppTheme.cyanNeon, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_discoveredDevices.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: AppTheme.glassDecoration(
                  fillColor: Colors.white.withOpacity(0.04),
                  borderRadius: 12,
                ),
                child: Row(
                  children: [
                    if (_isSearching)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyanNeon),
                      )
                    else
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.white38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isSearching
                            ? "جاري البحث عن الكمبيوتر عبر الشبكة المحلية (UDP Beacon)..."
                            : "لم يتم اكتشاف أجهزة تلقائياً. تأكد من اتصال الهاتف والكمبيوتر بنفس شبكة Wi-Fi.",
                        style: GoogleFonts.cairo(fontSize: 11, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...(_discoveredDevices.map(
                (d) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: AppTheme.glassDecoration(
                    borderColor: AppTheme.emeraldNeon.withOpacity(0.4),
                    fillColor: AppTheme.emeraldNeon.withOpacity(0.06),
                    borderRadius: 12,
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.computer_rounded, color: AppTheme.emeraldNeon),
                    title: Text(
                      d.name,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: Text(
                      "${d.ip} • منافذ: ${d.wsPort}/${d.udpPort}",
                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldNeon,
                        foregroundColor: AppTheme.bgDark,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {
                        _ipController.text = d.ip;
                        _handleConnect(d.ip, d.wsPort, d.udpPort);
                      },
                      child: Text(
                        "اتصال",
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }
}
