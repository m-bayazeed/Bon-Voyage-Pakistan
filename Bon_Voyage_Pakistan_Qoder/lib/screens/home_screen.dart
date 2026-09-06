import 'dart:async';
import 'package:flutter/material.dart';

import '../models/trip_checklist_item_model.dart';
import '../models/trip_plan_model.dart';
import '../services/auth_service.dart';
import '../services/trip_checklist_service.dart';
import '../services/trip_history_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/featured_escapes_carousel.dart';
import 'ai_tour_planning_screen.dart';
import 'first_aid_hospitals_screen.dart';
import 'food_dining_screen.dart';
import 'hotels_screen.dart';
import 'login_screen.dart';
import 'scan_search_screen.dart';
import 'settings_screen.dart';
import 'translator_screen.dart';
import 'travel_alerts_screen.dart';
import 'trip_checklist_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  // 0 = Plan
  // 1 = Scan
  // 2 = Translate
  // 3 = Home
  // 4 = Food
  // 5 = Hotels
  // 6 = Help
  int _selectedIndex = 3;

  String _userName = 'Traveler';
  bool _isLoggingOut = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Scroll Controller for scroll-driven logo animation
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // Plan & Checklist state
  TripPlan? _latestFinalizedPlan;
  int _pendingChecklistCount = 0;
  StreamSubscription<List<TripChecklistItem>>? _checklistSubscription;

  @override
  void initState() {
    super.initState();

    _loadUserName();
    _loadDashboardData();

    _scrollController.addListener(() {
      final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
      if ((offset - _scrollOffset).abs() > 0.5) {
        setState(() {
          _scrollOffset = offset;
        });
      }
    });

    _checklistSubscription = TripChecklistService.checklistStream.listen((items) {
      if (mounted) {
        setState(() {
          _pendingChecklistCount = items.where((i) => !i.isCompleted).length;
        });
      }
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _checklistSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final plan = await TripHistoryService.getLatestFinalizedPlan();
      final items = await TripChecklistService.getActiveChecklist();
      if (mounted) {
        setState(() {
          _latestFinalizedPlan = plan;
          _pendingChecklistCount = items.where((i) => !i.isCompleted).length;
        });
      }
    } catch (_) {}
  }


  // =========================================================
  // LOAD USER NAME
  // =========================================================

  Future<void> _loadUserName() async {
    try {
      final name = await AuthService.getUserName();

      if (!mounted) return;

      if (name != null && name.trim().isNotEmpty) {
        setState(() {
          _userName = name.trim();
        });
      }
    } catch (_) {
      // Keep default name if user information cannot be loaded.
    }
  }



  // =========================================================
  // BOTTOM NAVIGATION
  // =========================================================

  void _handleBottomNavigation(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AiTourPlanningScreen(),
          ),
        );
        break;

      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ScanSearchScreen(),
          ),
        );
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TranslatorScreen(),
          ),
        );
        break;

      case 3:
        // Already on the Home screen.
        break;

      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FoodDiningScreen(),
          ),
        );
        break;

      case 5:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HotelsScreen(),
          ),
        );
        break;

      case 6:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FirstAidHospitalsScreen(),
          ),
        );
        break;
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;

    final colorScheme = Theme.of(context).colorScheme;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Log Out?',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to log out of Bon Voyage Pakistan?',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });
    }
  }

  // =========================================================
  // PROFILE BOTTOM SHEET
  // =========================================================

  void _showProfileMenu() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DRAG HANDLE
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 24),

                // PROFILE HEADER
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withOpacity(0.15),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bon Voyage Explorer',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Divider(
                  color:
                      colorScheme.onSurfaceVariant.withOpacity(0.15),
                ),

                // SETTINGS
                _ProfileMenuTile(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ).then((_) {
                      _loadUserName();
                    });
                  },
                ),

                // HISTORY
                _ProfileMenuTile(
                  icon: Icons.history_rounded,
                  title: 'My Activity & History',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiTourPlanningScreen(
                          openHistoryDirectly: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,

      body: Stack(
        children: [
          // =====================================================
          // MAIN CONTENT
          // =====================================================

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // =================================================
                    // TOP BAR
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        4,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            // PROFILE BUTTON
                            GestureDetector(
                              onTap: _showProfileMenu,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      colorScheme.surfaceContainerHighest,
                                  border: Border.all(
                                    color:
                                        AppTheme.primary.withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),

                            // APP NAME
                            Flexible(
                              child: Text(
                                'Bon Voyage Pakistan',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),

                            // NOTIFICATION BUTTON
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WeatherScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      colorScheme.surfaceContainerHighest,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.wb_sunny_outlined,
                                      color:
                                          const Color(0xFF0284C7),
                                      size: 22,
                                    ),
                                    Positioned(
                                      top: 11,
                                      right: 11,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme
                                                .surfaceContainerHighest,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =================================================
                    // SCROLL-DRIVEN ANIMATED APP LOGO
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8, bottom: 0),
                      sliver: SliverToBoxAdapter(
                        child: Builder(
                          builder: (context) {
                            final logoProgress = (_scrollOffset / 120.0).clamp(0.0, 1.0);
                            final logoScale = 1.0 - (logoProgress * 0.42); // Shrinks smoothly
                            final logoRotation = -0.12 * logoProgress; // Smooth subtle rotation
                            final logoTranslateY = -8.0 * logoProgress; // Moves upward towards header

                            return Center(
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..translate(0.0, logoTranslateY)
                                  ..scale(logoScale)
                                  ..rotateZ(logoRotation),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 68,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // =================================================
                    // WELCOME TEXT
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        16,
                        24,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pakistan is waiting\nfor you, $_userName.',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 28,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Plan smarter. Explore deeper. Travel better.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =================================================
                    // 2×2 QUICK ACTION DASHBOARD GRID
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            // ROW 1: AI Planning & Emergency Aid
                            Row(
                              children: [
                                // CARD 1: AI PLANNING
                                Expanded(
                                  child: _buildActionCard(
                                    title: 'AI Planning',
                                    subtitle: 'Custom Tour Route',
                                    icon: Icons.auto_awesome_rounded,
                                    accentColor: AppTheme.primary,
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AiTourPlanningScreen(),
                                        ),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // CARD 2: EMERGENCY & MEDICAL AID
                                Expanded(
                                  child: _buildActionCard(
                                    title: 'Emergency Aid',
                                    subtitle: 'Hospitals & 1122',
                                    icon: Icons.health_and_safety_rounded,
                                    accentColor: Colors.redAccent,
                                    badgeText: '24/7',
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const FirstAidHospitalsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ROW 2: Latest Finalized Plan & Trip Checklist & Notes
                            Row(
                              children: [
                                // CARD 3: LATEST FINALIZED TRIP PLAN
                                Expanded(
                                  child: _buildPlanCard(
                                    plan: _latestFinalizedPlan,
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => _latestFinalizedPlan != null
                                              ? AiTourPlanningScreen(initialPlan: _latestFinalizedPlan)
                                              : const AiTourPlanningScreen(),
                                        ),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // CARD 4: TRIP CHECKLIST & NOTES
                                Expanded(
                                  child: _buildChecklistCard(
                                    pendingCount: _pendingChecklistCount,
                                    hasPlan: _latestFinalizedPlan != null,
                                    planDays: _latestFinalizedPlan?.days,
                                    isDark: isDark,
                                    colorScheme: colorScheme,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const TripChecklistScreen(),
                                        ),
                                      );
                                      _loadDashboardData();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),


                    // =================================================
                    // FEATURED HEADER
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        38,
                        24,
                        18,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Featured Escapes',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // DESTINATION CARDS
                    // =================================================

                    const SliverToBoxAdapter(
                      child: FeaturedEscapesCarousel(),
                    ),

                    // =================================================
                    // BOTTOM SPACE
                    // =================================================

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 125),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // CUSTOM 6-FEATURE BOTTOM NAVIGATION
          // 3 LEFT + HOME + 3 RIGHT
          // =====================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.97),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  border: Border(
                    top: BorderSide(
                      color:
                          colorScheme.onSurface.withOpacity(0.06),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          AppTheme.primary.withOpacity(0.08),
                      blurRadius: 25,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // LEFT SIDE
                    Expanded(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _BottomNavItem(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Plan',
                            active: _selectedIndex == 0,
                            onTap: () =>
                                _handleBottomNavigation(0),
                          ),

                          _BottomNavItem(
                            icon: Icons.document_scanner_outlined,
                            label: 'Scan',
                            active: _selectedIndex == 1,
                            onTap: () =>
                                _handleBottomNavigation(1),
                          ),

                          _BottomNavItem(
                            icon: Icons.mic_rounded,
                            label: 'Translate',
                            active: _selectedIndex == 2,
                            onTap: () =>
                                _handleBottomNavigation(2),
                          ),
                        ],
                      ),
                    ),

                    // CENTER HOME
                    GestureDetector(
                      onTap: () {
                        _handleBottomNavigation(3);
                      },
                      child: Transform.translate(
                        offset: const Offset(0, -20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary
                                        .withOpacity(0.30),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.home_filled,
                                color: AppTheme.onPrimary,
                                size: 27,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              'Home',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // RIGHT SIDE
                    Expanded(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _BottomNavItem(
                            icon: Icons.restaurant_rounded,
                            label: 'Food',
                            active: _selectedIndex == 4,
                            onTap: () =>
                                _handleBottomNavigation(4),
                          ),

                          _BottomNavItem(
                            icon: Icons.hotel_rounded,
                            label: 'Hotels',
                            active: _selectedIndex == 5,
                            onTap: () =>
                                _handleBottomNavigation(5),
                          ),

                          _BottomNavItem(
                            icon:
                                Icons.medical_services_outlined,
                            label: 'Help',
                            active: _selectedIndex == 6,
                            onTap: () =>
                                _handleBottomNavigation(6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // LOGOUT LOADING OVERLAY
          if (_isLoggingOut)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // =========================================================
  // 2×2 DASHBOARD CARD BUILDERS
  // =========================================================

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? badgeText,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.25 : 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.15),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: accentColor.withOpacity(0.7),
                    size: 16,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required TripPlan? plan,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final hasPlan = plan != null;
    final accentColor = const Color(0xFF0288D1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.28 : 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    hasPlan ? Icons.map_rounded : Icons.add_location_alt_outlined,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                if (hasPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${plan.days}D Plan',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'No Plan',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPlan ? plan.title : 'No trip plan yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPlan
                      ? '📍 ${plan.destinationCity}'
                      : 'Plan your trip first ➔',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasPlan ? colorScheme.onSurfaceVariant : AppTheme.primary,
                    fontSize: 11,
                    fontWeight: hasPlan ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistCard({
    required int pendingCount,
    required bool hasPlan,
    int? planDays,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final accentColor = const Color(0xFF5A7328);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.28 : 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    Icons.checklist_rounded,
                    color: accentColor,
                    size: 21,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: pendingCount > 0
                        ? accentColor.withOpacity(0.15)
                        : (hasPlan ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: pendingCount > 0
                          ? accentColor.withOpacity(0.3)
                          : (hasPlan ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
                    ),
                  ),
                  child: Text(
                    pendingCount > 0
                        ? '$pendingCount Left'
                        : (hasPlan ? 'All Done' : 'Setup'),
                    style: TextStyle(
                      color: pendingCount > 0
                          ? accentColor
                          : (hasPlan ? Colors.green : colorScheme.onSurfaceVariant),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Checklist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPlan
                      ? (planDays != null ? 'By $planDays itinerary days' : 'Plan-aware organizer')
                      : 'Create plan to activate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

// =========================================================
// PROFILE MENU TILE
// =========================================================

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: AppTheme.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}



// =========================================================
// BOTTOM NAVIGATION ITEM
// =========================================================

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active
                  ? AppTheme.primary
                  : colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 4),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight:
                    active ? FontWeight.w800 : FontWeight.w500,
                color: active
                    ? AppTheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}