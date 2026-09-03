import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/travel_alert_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';


/// Splash screen displayed when the app opens.
///
/// Shows the Bon Voyage Pakistan logo with a reveal animation,
/// then checks the stored JWT and navigates accordingly:
/// - Valid token → HomeScreen
/// - No / expired token → OnboardingScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _titleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );

    _subtitleFade = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
    );

    _mainController.forward();
    // Refresh live notifications in background on app startup
    TravelAlertService.refreshAlertsInBackground();
    _checkAuthAndNavigate();
  }


  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    final user = await AuthService.verifyToken();

    if (!mounted) return;

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bg,
              isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoFade,
                child: Hero(
                  tag: 'app_logo',
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                      border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.18),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _titleFade,
              child: Column(
                children: [
                  Text(
                    'BON VOYAGE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: onBg,
                      letterSpacing: 6,
                    ),
                  ),
                  Text(
                    'PAKISTAN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: onBg.withOpacity(0.8),
                      letterSpacing: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FadeTransition(
              opacity: _subtitleFade,
              child: Text(
                'Your AI Travel Companion',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 60),
            FadeTransition(
              opacity: _subtitleFade,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
