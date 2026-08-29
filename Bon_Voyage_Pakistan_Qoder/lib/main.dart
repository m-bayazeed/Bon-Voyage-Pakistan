import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'screens/splash_screen.dart';

/// Entry point for Bon Voyage Pakistan.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BonVoyageApp());
}

/// Root widget of the application.
///
/// Provides theme management with light/dark mode persistence and wraps the
/// app in a premium cinematic design system.
class BonVoyageApp extends StatefulWidget {
  const BonVoyageApp({super.key});

  @override
  State<BonVoyageApp> createState() => _BonVoyageAppState();
}

class _BonVoyageAppState extends State<BonVoyageApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ThemeProviderScope(
      notifier: _themeProvider,
      child: ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, child) {
          return MaterialApp(
            title: 'Bon Voyage Pakistan',
            debugShowCheckedModeBanner: false,
            themeMode: _themeProvider.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: child,
          );
        },
        child: const SplashScreen(),
      ),
    );
  }
}
