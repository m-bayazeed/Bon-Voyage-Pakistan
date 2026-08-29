import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Manages the app's light/dark theme mode and persists the choice locally.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  /// Load the saved theme mode from SharedPreferences.
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _themeMode = ThemeMode.values.byName(saved);
      notifyListeners();
    }
  }

  /// Toggle between light and dark mode and persist the selection.
  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _themeMode.name);
    notifyListeners();
  }

  /// Explicitly set the theme mode.
  Future<void> setTheme(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _themeMode.name);
    notifyListeners();
  }

  /// Returns the active theme based on current mode.
  ThemeData get theme => isDark ? AppTheme.dark() : AppTheme.light();
}

/// InheritedWidget that exposes the ThemeProvider to descendants.
class ThemeProviderScope extends InheritedNotifier<ThemeProvider> {
  const ThemeProviderScope({
    super.key,
    required ThemeProvider super.notifier,
    required super.child,
  });

  static ThemeProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeProviderScope>();
    assert(scope != null, 'No ThemeProviderScope found in context');
    return scope!.notifier!;
  }
}
