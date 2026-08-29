import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable dark/light mode toggle button with sun/moon icons.
class ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const ThemeToggle({
    super.key,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkSurfaceVariant.withOpacity(0.6)
              : AppTheme.lightSurfaceVariant,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : AppTheme.primary.withOpacity(0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(isDark ? 0.15 : 0.08),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
            key: ValueKey<bool>(isDark),
            color: isDark ? const Color(0xFFFFB74D) : const Color(0xFF1E293B),
            size: 22,
          ),
        ),
      ),
    );
  }
}
