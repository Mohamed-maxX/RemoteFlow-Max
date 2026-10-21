import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../models/discovered_device.dart';
import '../providers/connection_provider.dart';
import '../services/discovery_service.dart';
import 'main_deck_screen.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.6");
  final TextEditingController _wsPortController = TextEditingController(text: "5056");
  final TextEditingController _udpPortController = TextEditingController(text: "5055");

  final DiscoveryService _discoveryService = DiscoveryService();
  StreamSubscription? _discoverySubscription;
  List<DiscoveredDevice> _discoveredDevices = [];
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() {
    _discoveryService.startDiscovery();
    _discoverySubscription = _discoveryService.devicesStream.listen((devices) {
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          if (devices.isNotEmpty && _ipController.text == "192.168.1.6") {
            _ipController.text = devices.first.ip;
          }
        });
      }
    });
  }

  Future<void> _connect(String ip, int wsPort, int udpPort) async {
    setState(() => _isConnecting = true);
    HapticFeedback.mediumImpact();

    final success = await ref.read(connectionProvider.notifier).connect(
          ip: ip,
          wsPort: wsPort,
          udpPort: udpPort,
        );

    if (!mounted) return;
    setState(() => _isConnecting = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainDeckScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("فشل الاتصال بـ $ip:$wsPort. تأكد من تشغيل السيرفر على الكمبيوتر."),
          backgroundColor: AppTheme.redAlert,
        ),
      );
    }
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _discoveryService.dispose();
    _ipController.dispose();
    _wsPortController.dispose();
    _udpPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Brand Logo & Header
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyanGlow.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // App Title
              Center(
                child: Column(
                  children: [
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: "REMOTEFLOW ",
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                          TextSpan(
                            text: "MAX",
                            style: TextStyle(
                              color: AppTheme.orangeNeon,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "منصة التحكم الشاملة بالكمبيوتر فائقة السرعة",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Auto-Discovered Devices Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "الأجهزة المكتشفة على الشبكة",
                    style: TextStyle(
                      color: AppTheme.cyanGlow,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary, size: 22),
                    onPressed: () => _discoveryService.sendProbe(),
                    tooltip: "إعادة البحث",
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_discoveredDevices.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.cyanGlow.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "جاري البحث عن خادم الكمبيوتر على شبكة الواي فاي...",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ..._discoveredDevices.map((device) => _buildDiscoveredCard(device)),

              const SizedBox(height: 28),

              // Manual IP Section
              const Text(
                "الاتصال اليدوي",
                style: TextStyle(
                  color: AppTheme.cyanGlow,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _ipController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "عنوان IP المحلي للكمبيوتر",
                        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.desktop_windows_rounded, color: AppTheme.cyanGlow, size: 20),
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.cyanGlow),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wsPortController,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "WS Port",
                                labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                filled: true,
                                fillColor: AppTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _udpPortController,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "UDP Port",
                                labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                filled: true,
                                fillColor: AppTheme.bgCard,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppTheme.borderSubtle),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Connect Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isConnecting
                            ? null
                            : () {
                                final ip = _ipController.text.trim();
                                final wsPort = int.tryParse(_wsPortController.text.trim()) ?? 5056;
                                final udpPort = int.tryParse(_udpPortController.text.trim()) ?? 5055;
                                _connect(ip, wsPort, udpPort);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.cyanGlow, AppTheme.purpleNeon],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.cyanGlow.withOpacity(0.35),
                                blurRadius: 16,
                              )
                            ],
                          ),
                          child: Center(
                            child: _isConnecting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "اتصال بالكمبيوتر الآن",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
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

  Widget _buildDiscoveredCard(DiscoveredDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cyanGlow.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyanGlow.withOpacity(0.08),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cyanGlow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.computer_rounded, color: AppTheme.cyanGlow),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${device.ip}  •  UDP:${device.udpPort}  WS:${device.wsPort}",
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _connect(device.ip, device.wsPort, device.udpPort),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cyanGlow,
              foregroundColor: AppTheme.bgDark,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("اقتران", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
