import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/connection_provider.dart';

class KeyboardSheet extends ConsumerStatefulWidget {
  const KeyboardSheet({super.key});

  @override
  ConsumerState<KeyboardSheet> createState() => _KeyboardSheetState();
}

class _KeyboardSheetState extends ConsumerState<KeyboardSheet> {
  final TextEditingController _textController = TextEditingController();

  void _sendText() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      ref.read(connectionProvider.notifier).sendText(text);
      _textController.clear();
      HapticFeedback.lightImpact();
    }
  }

  void _sendKey(String key) {
    ref.read(connectionProvider.notifier).sendKey(key);
    HapticFeedback.selectionClick();
  }

  void _sendHotkey(List<String> keys) {
    ref.read(connectionProvider.notifier).sendHotkey(keys);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: const Border(
            top: BorderSide(color: AppTheme.cyanGlow, width: 2.0),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyanGlow.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -4),
            )
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 14,
          left: 16,
          right: 16,
        ),
        child: SingleChildScrollView(
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
                    color: AppTheme.borderHighlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
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
                        child: const Icon(Icons.keyboard_rounded, color: AppTheme.cyanGlow, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "لوحة مفاتيح الكمبيوتر والاختصارات",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 12),

              // Text Streamer Input Field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "اكتب هنا لإرسال النص مباشرة للكمبيوتر...",
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.cyanGlow),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sendText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyanGlow,
                      padding: const EdgeInsets.all(12),
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.send_rounded, color: AppTheme.bgDark, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hotkey Quick-Triggers Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildHotkeyPill("Ctrl + C", ["ctrl", "c"], Colors.blueAccent),
                    _buildHotkeyPill("Ctrl + V", ["ctrl", "v"], Colors.purpleAccent),
                    _buildHotkeyPill("Ctrl + Z", ["ctrl", "z"], Colors.orangeAccent),
                    _buildHotkeyPill("Ctrl + A", ["ctrl", "a"], Colors.tealAccent),
                    _buildHotkeyPill("Alt + Tab", ["alt", "tab"], Colors.pinkAccent),
                    _buildHotkeyPill("Win + D", ["win", "d"], Colors.greenAccent),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Essential PC Keys Grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildKeyButton("Esc", "esc", isHighlight: true),
                  _buildKeyButton("Tab", "tab"),
                  _buildKeyButton("Win", "win"),
                  _buildKeyButton("Alt", "alt"),
                  _buildKeyButton("Ctrl", "ctrl"),
                  _buildKeyButton("Backspace", "backspace"),
                  _buildKeyButton("Delete", "delete"),
                  _buildKeyButton("Enter ⏎", "enter", isAction: true),
                ],
              ),
              const SizedBox(height: 14),

              // Arrow Keys Cluster & Navigation
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildArrowButton(Icons.arrow_back_rounded, "left"),
                    Column(
                      children: [
                        _buildArrowButton(Icons.arrow_upward_rounded, "up"),
                        const SizedBox(height: 6),
                        _buildArrowButton(Icons.arrow_downward_rounded, "down"),
                      ],
                    ),
                    _buildArrowButton(Icons.arrow_forward_rounded, "right"),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // F-Keys Row
              Directionality(
                textDirection: TextDirection.ltr,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(12, (index) {
                      final fKey = "F${index + 1}";
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildSmallKeyButton(fKey, fKey.toLowerCase()),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHotkeyPill(String label, List<String> keys, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        onTap: () => _sendHotkey(keys),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.5)),
          ),
          child: Text(
            label,
            style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyButton(String label, String keyStr, {bool isHighlight = false, bool isAction = false}) {
    Color bg = AppTheme.bgCard;
    Color border = AppTheme.borderSubtle;
    Color text = AppTheme.textPrimary;

    if (isAction) {
      bg = AppTheme.cyanGlow;
      text = AppTheme.bgDark;
    } else if (isHighlight) {
      border = AppTheme.orangeNeon.withOpacity(0.6);
      text = AppTheme.orangeNeon;
    }

    return InkWell(
      onTap: () => _sendKey(keyStr),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSmallKeyButton(String label, String keyStr) {
    return InkWell(
      onTap: () => _sendKey(keyStr),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, String keyStr) {
    return InkWell(
      onTap: () => _sendKey(keyStr),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgCardHover,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Icon(icon, color: AppTheme.cyanGlow, size: 20),
      ),
    );
  }
}
