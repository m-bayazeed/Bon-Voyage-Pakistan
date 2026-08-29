import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Onboarding flow with two cinematic pages.
///
/// Page 1: immersive Northern Pakistan background with glass bottom sheet.
/// Page 2: dark ambient scene with animated AI pulse and scanning line.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _page1Controller;
  late AnimationController _page2Controller;
  late Animation<double> _page1Fade;
  late Animation<Offset> _page1Slide;
  late Animation<double> _page2VisualScale;
  late Animation<double> _page2TextFade;

  @override
  void initState() {
    super.initState();

    _page1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _page1Fade = CurvedAnimation(
      parent: _page1Controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _page1Slide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _page1Controller,
      curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
    ));

    _page2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _page2VisualScale = CurvedAnimation(
      parent: _page2Controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );
    _page2TextFade = CurvedAnimation(
      parent: _page2Controller,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );

    _page1Controller.forward();

    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        if (page == 0) {
          _page1Controller.forward(from: 0);
          _page2Controller.reverse();
        } else {
          _page2Controller.forward(from: 0);
          _page1Controller.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _page1Controller.dispose();
    _page2Controller.dispose();
    super.dispose();
  }

  void _goToAuth() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _nextPage() {
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _goToAuth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            children: [
              _OnboardingPageOne(
                fade: _page1Fade,
                slide: _page1Slide,
                onSkip: _goToAuth,
                isDark: isDark,
              ),
              _OnboardingPageTwo(
                visualScale: _page2VisualScale,
                textFade: _page2TextFade,
                onSkip: _goToAuth,
                isDark: isDark,
              ),
            ],
          ),
          // Bottom progress + CTA anchored at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bg.withOpacity(0.0),
            bg.withOpacity(0.85),
            bg,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                final active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.primary
                        : (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // CTA button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _nextPage,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_currentPage == 0 ? 'Next' : 'Start Exploring'),
                    const SizedBox(width: 8),
                    Icon(
                      _currentPage == 0 ? Icons.arrow_forward_rounded : Icons.explore_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Onboarding Page 1 — Cinematic Northern Pakistan
// ──────────────────────────────────────────────
class _OnboardingPageOne extends StatelessWidget {
  final Animation<double> fade;
  final Animation<Offset> slide;
  final VoidCallback onSkip;
  final bool isDark;

  const _OnboardingPageOne({
    required this.fade,
    required this.slide,
    required this.onSkip,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image
        Image.asset(
          'assets/images/onboarding1.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.2),
                Colors.transparent,
                (isDark ? AppTheme.darkBackground : AppTheme.lightBackground).withOpacity(0.95),
                isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
              ],
              stops: const [0.0, 0.35, 0.72, 1.0],
            ),
          ),
        ),
        // Top actions
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Content near bottom (above anchored controls)
        Positioned(
          left: 24,
          right: 24,
          bottom: 145,
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Explore Pakistan\nLike Never Before',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: isDark ? AppTheme.darkOnBackground : Colors.white,
                            fontSize: 32,
                            height: 1.15,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover the untamed beauty of the Northern Areas with AI-powered itineraries, personalized recommendations, and deep cultural insights.',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: (isDark ? AppTheme.darkOnSurfaceVariant : Colors.white).withValues(alpha: 0.85),
                          fontSize: 14,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Onboarding Page 2 — Smart Travel Companion
// ──────────────────────────────────────────────
class _OnboardingPageTwo extends StatefulWidget {
  final Animation<double> visualScale;
  final Animation<double> textFade;
  final VoidCallback onSkip;
  final bool isDark;

  const _OnboardingPageTwo({
    required this.visualScale,
    required this.textFade,
    required this.onSkip,
    required this.isDark,
  });

  @override
  State<_OnboardingPageTwo> createState() => _OnboardingPageTwoState();
}

class _OnboardingPageTwoState extends State<_OnboardingPageTwo>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _scanPosition;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _pulseScale = Tween<double>(begin: 0.85, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanPosition = Tween<double>(begin: -0.05, end: 1.05).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Container(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient glows
          Positioned(
            top: -80,
            right: -80,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.22),
                    AppTheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            width: 240,
            height: 240,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withOpacity(0.18),
                    AppTheme.secondary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Digital texture overlay (subtle grid of dots)
          Opacity(
            opacity: 0.04,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/onboarding2.png'),
                  fit: BoxFit.cover,
                  opacity: 0.5,
                ),
              ),
            ),
          ),
          // Top actions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: widget.isDark
                          ? AppTheme.darkOnBackground
                          : AppTheme.lightOnBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Central visual
          Positioned(
            top: MediaQuery.of(context).size.height * 0.12,
            left: 0,
            right: 0,
            child: ScaleTransition(
              scale: widget.visualScale,
              child: Center(
                child: SizedBox(
                  width: min(240.0, MediaQuery.of(context).size.width * 0.65),
                  height: min(240.0, MediaQuery.of(context).size.width * 0.65),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // AI pulse rings
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 240 * _pulseScale.value,
                            height: 240 * _pulseScale.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: _pulseOpacity.value),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Main circular image
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.18),
                              blurRadius: 36,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/onboarding2.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Scanning line
                      AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + (160 * _scanPosition.value),
                            left: 24,
                            right: 24,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppTheme.primary.withValues(alpha: 0.9),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Floating food icon
                      Positioned(
                        right: -6,
                        top: 30,
                        child: _FloatingIcon(
                          icon: Icons.restaurant_rounded,
                          delay: 0,
                          isDark: widget.isDark,
                        ),
                      ),
                      // Floating translator icon
                      Positioned(
                        left: -6,
                        top: 90,
                        child: _FloatingIcon(
                          icon: Icons.translate_rounded,
                          delay: 400,
                          isDark: widget.isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Text content near bottom
          Positioned(
            left: 24,
            right: 24,
            bottom: 145,
            child: FadeTransition(
              opacity: widget.textFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Your Smart Travel Companion',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primary,
                            fontSize: 26,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan landmarks, translate instantly, discover hidden food gems, and access local assistance anytime.',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: widget.isDark
                              ? AppTheme.darkOnSurfaceVariant
                              : AppTheme.lightOnSurfaceVariant,
                          fontSize: 14,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Floating glass icon with subtle bob animation
// ──────────────────────────────────────────────
class _FloatingIcon extends StatefulWidget {
  final IconData icon;
  final int delay;
  final bool isDark;

  const _FloatingIcon({
    required this.icon,
    required this.delay,
    required this.isDark,
  });

  @override
  State<_FloatingIcon> createState() => _FloatingIconState();
}

class _FloatingIconState extends State<_FloatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _offset = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _offset.value),
          child: child,
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppTheme.darkSurfaceVariant.withOpacity(0.6)
              : Colors.white.withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.1),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(widget.icon, color: AppTheme.primary, size: 22),
      ),
    );
  }
}
