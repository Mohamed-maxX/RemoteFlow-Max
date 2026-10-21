import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_theme.dart';
import '../providers/security_provider.dart';

class PinAuthDialog extends ConsumerStatefulWidget {
  const PinAuthDialog({super.key});

  @override
  ConsumerState<PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends ConsumerState<PinAuthDialog> {
  String _enteredPin = "";

  void _onDigit(String digit) {
    if (_enteredPin.length < 6) {
      setState(() => _enteredPin += digit);
      HapticFeedback.selectionClick();
      if (_enteredPin.length == 4) {
        // Auto-submit 4-digit PIN
        ref.read(securityProvider.notifier).sendPin(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = ref.watch(securityProvider);

    // If authenticated, auto dismiss
    if (sec.isAuthenticated) {
      Future.microtask(() {
        if (context.mounted) Navigator.of(context).pop(true);
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cyanGlow.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded, color: AppTheme.cyanGlow, size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                "رمز الحماية PIN مطلوب",
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "أدخل الرمز المكون من 4 أرقام المعروض في شاشة السيرفر على الكمبيوتر:",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // PIN Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppTheme.cyanGlow : AppTheme.bgCard,
                      border: Border.all(
                        color: filled ? AppTheme.cyanGlow : AppTheme.borderSubtle,
                      ),
                      boxShadow: [
                        if (filled)
                          BoxShadow(
                            color: AppTheme.cyanGlow.withOpacity(0.5),
                            blurRadius: 8,
                          )
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              if (sec.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    sec.errorMessage!,
                    style: const TextStyle(color: AppTheme.redAlert, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),

              // Keypad
              Directionality(
                textDirection: TextDirection.ltr,
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    for (var i = 1; i <= 9; i++) _buildKeypadBtn("$i", () => _onDigit("$i")),
                    _buildKeypadBtn("مسح", () => setState(() => _enteredPin = ""), isAction: true),
                    _buildKeypadBtn("0", () => _onDigit("0")),
                    _buildKeypadBtn("⌫", _onBackspace, isAction: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadBtn(String label, VoidCallback onTap, {bool isAction = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isAction ? AppTheme.bgCardHover : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isAction ? AppTheme.orangeNeon : AppTheme.textPrimary,
              fontSize: label.length > 2 ? 14 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
