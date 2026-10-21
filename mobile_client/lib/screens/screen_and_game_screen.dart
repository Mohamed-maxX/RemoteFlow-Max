import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme.dart';
import 'screen_mirror_screen.dart';
import 'gamepad_screen.dart';

class ScreenAndGameScreen extends StatefulWidget {
  const ScreenAndGameScreen({super.key});

  @override
  State<ScreenAndGameScreen> createState() => _ScreenAndGameScreenState();
}

class _ScreenAndGameScreenState extends State<ScreenAndGameScreen> {
  int _selectedMode = 0; // 0: Screen Mirror, 1: Virtual Gamepad

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface.withOpacity(0.85),
                border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildToggleTab("📺 بث الشاشة المباشر", 0),
                  const SizedBox(width: 12),
                  _buildToggleTab("🎮 يد تحكم الألعاب", 1),
                ],
              ),
            ),

            // Active View
            Expanded(
              child: IndexedStack(
                index: _selectedMode,
                children: const [
                  ScreenMirrorScreen(),
                  GamepadScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTab(String label, int index) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = index);
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyanGlow : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.cyanGlow : AppTheme.borderSubtle,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.cyanGlow.withOpacity(0.3),
                blurRadius: 10,
              )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.bgDark : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
