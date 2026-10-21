import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../models/macro_deck.dart';
import '../providers/clipboard_provider.dart';
import '../providers/macro_provider.dart';
import '../providers/file_explorer_provider.dart';

class StreamDeckScreen extends ConsumerStatefulWidget {
  const StreamDeckScreen({super.key});

  @override
  ConsumerState<StreamDeckScreen> createState() => _StreamDeckScreenState();
}

class _StreamDeckScreenState extends ConsumerState<StreamDeckScreen> {
  final TextEditingController _urlController = TextEditingController();

  IconData _resolveIcon(String iconName) {
    switch (iconName) {
      case 'live_tv': return Icons.live_tv_rounded;
      case 'fiber_manual_record': return Icons.fiber_manual_record_rounded;
      case 'mic_off': return Icons.mic_off_rounded;
      case 'headset_off': return Icons.headset_off_rounded;
      case 'crop': return Icons.crop_rounded;
      case 'volume_off': return Icons.volume_off_rounded;
      case 'dns': return Icons.dns_rounded;
      case 'delete_sweep': return Icons.delete_sweep_rounded;
      case 'terminal': return Icons.terminal_rounded;
      case 'insights': return Icons.insights_rounded;
      case 'folder_open': return Icons.folder_open_rounded;
      case 'content_paste': return Icons.content_paste_rounded;
      case 'add_box': return Icons.add_box_rounded;
      case 'close': return Icons.close_rounded;
      case 'restore': return Icons.restore_rounded;
      case 'refresh': return Icons.refresh_rounded;
      case 'zoom_in': return Icons.zoom_in_rounded;
      case 'zoom_out': return Icons.zoom_out_rounded;
      default: return Icons.bolt_rounded;
    }
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll("#", "");
      return Color(int.parse("FF$clean", radix: 16));
    } catch (_) {
      return AppTheme.cyanGlow;
    }
  }

  void _injectUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(fileExplorerProvider.notifier).openUrl(url);
      _urlController.clear();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("تم فتح الرابط في متصفح الكمبيوتر: $url"),
          backgroundColor: AppTheme.bgCard,
        ),
      );
    }
  }

  void _pushMobileClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      ref.read(clipboardProvider.notifier).pushToPc(data.text!);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إرسال حافظة الهاتف إلى الكمبيوتر بنجاح!"),
          backgroundColor: AppTheme.greenActive,
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final macroState = ref.watch(macroProvider);
    final macroNotifier = ref.read(macroProvider.notifier);
    final clipboard = ref.watch(clipboardProvider);
    final activeDeck = macroState.activeDeck;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // Section 1: Bidirectional Shared Clipboard Bar
            _buildClipboardCard(context, clipboard),
            const SizedBox(height: 14),

            // Section 2: Direct Link Injector Field
            _buildLinkInjectorBar(),
            const SizedBox(height: 18),

            // Section 3: Deck Category Switcher Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.cyanGlow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.dashboard_customize_rounded, color: AppTheme.cyanGlow, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "لوحة الاختصارات والماكرو",
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  activeDeck?.name ?? "اللوحات",
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Deck Tabs
            if (macroState.decks.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(macroState.decks.length, (index) {
                    final deck = macroState.decks[index];
                    final isSelected = index == macroState.selectedDeckIndex;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(deck.name),
                        selected: isSelected,
                        selectedColor: AppTheme.cyanGlow,
                        backgroundColor: AppTheme.bgCard,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.bgDark : AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.cyanGlow : AppTheme.borderSubtle,
                        ),
                        onSelected: (_) => macroNotifier.selectDeck(index),
                      ),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 14),

            // Macro Grid
            if (activeDeck == null || activeDeck.buttons.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.widgets_outlined, color: AppTheme.textMuted, size: 36),
                    SizedBox(height: 8),
                    Text(
                      "لا توجد أزرار اختصار مضافة في هذه اللوحة.",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activeDeck.buttons.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, idx) {
                  final btn = activeDeck.buttons[idx];
                  return _buildMacroTile(btn, macroNotifier);
                },
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildClipboardCard(BuildContext context, ClipboardState clipboard) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
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
                      color: AppTheme.purpleNeon.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sync_alt_rounded, color: AppTheme.purpleNeon, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "الحافظة المشتركة (كمبيوتر ⮂ هاتف)",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppTheme.cyanGlow, size: 20),
                    tooltip: "نسخ نص الكمبيوتر إلى الهاتف",
                    onPressed: () {
                      if (clipboard.text.isNotEmpty) {
                        ref.read(clipboardProvider.notifier).copyToMobile(clipboard.text);
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("تم نسخ نص الكمبيوتر إلى حافظة هاتفك!"),
                            backgroundColor: AppTheme.bgCard,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_rounded, color: AppTheme.orangeNeon, size: 20),
                    tooltip: "إرسال حافظة الهاتف إلى الكمبيوتر",
                    onPressed: _pushMobileClipboard,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              clipboard.text.isNotEmpty ? clipboard.text : "حافظة الكمبيوتر فارغة حالياً أو تحتوي وسائط.",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: clipboard.text.isNotEmpty ? AppTheme.textPrimary : AppTheme.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkInjectorBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: "فتح رابط مباشر في متصفح الكمبيوتر...",
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.cyanGlow, size: 18),
              filled: true,
              fillColor: AppTheme.bgSurface.withOpacity(0.85),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.cyanGlow),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => _injectUrl(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _injectUrl,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cyanGlow,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: EdgeInsets.zero,
          ),
          child: const Icon(Icons.open_in_browser_rounded, color: AppTheme.bgDark),
        ),
      ],
    );
  }

  Widget _buildMacroTile(MacroButton btn, MacroNotifier notifier) {
    final tileColor = _parseColor(btn.color);
    return InkWell(
      onTap: () {
        notifier.executeButton(btn);
        HapticFeedback.mediumImpact();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tileColor.withOpacity(0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: tileColor.withOpacity(0.12),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tileColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_resolveIcon(btn.icon), color: tileColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              btn.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
