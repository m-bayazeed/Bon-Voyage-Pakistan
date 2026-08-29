import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';
import 'ai_tour_planning_screen.dart';
import 'first_aid_hospitals_screen.dart';
import 'food_dining_screen.dart';
import 'hotels_screen.dart';
import 'login_screen.dart';
import 'scan_search_screen.dart';
import 'settings_screen.dart';
import 'translator_screen.dart';
import 'travel_alerts_screen.dart';

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

  @override
  void initState() {
    super.initState();

    _loadUserName();

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
    _animationController.dispose();
    super.dispose();
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
  // SNACKBAR
  // =========================================================

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 105),
        backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Row(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature is coming soon!',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                        10,
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
                                    builder: (_) => const TravelAlertsScreen(),
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
                                      Icons.notifications_outlined,
                                      color:
                                          colorScheme.onSurfaceVariant,
                                    ),
                                    Positioned(
                                      top: 11,
                                      right: 11,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colorScheme.secondary,
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
                    // WELCOME TEXT
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        28,
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
                                fontSize: 30,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Plan smarter. Explore deeper. Travel better.',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =================================================
                    // SEARCH BAR
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        28,
                        24,
                        34,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color:
                                colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color:
                                  AppTheme.primary.withOpacity(0.14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTheme.primary.withOpacity(0.06),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 18),

                              Icon(
                                Icons.search_rounded,
                                color: AppTheme.primary,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: TextField(
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText:
                                        'Search destinations...',
                                    hintStyle: TextStyle(
                                      color: colorScheme.onSurfaceVariant
                                          .withOpacity(0.65),
                                      fontSize: 14,
                                    ),
                                  ),
                                  onSubmitted: (value) {
                                    if (value.trim().isNotEmpty) {
                                      _showComingSoon(
                                        'Search for "${value.trim()}"',
                                      );
                                    }
                                  },
                                ),
                              ),

                              Container(
                                margin: const EdgeInsets.all(6),
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _showComingSoon(
                                      'Advanced Search',
                                    );
                                  },
                                  icon: Icon(
                                    Icons.tune_rounded,
                                    color: AppTheme.onPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // AI TRIP PLANNER CARD
                    // =================================================

                    SliverPadding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: () {
                            _handleBottomNavigation(0);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(26),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primary.withOpacity(
                                    isDark ? 0.18 : 0.12,
                                  ),
                                  colorScheme
                                      .surfaceContainerHighest,
                                ],
                              ),
                              border: Border.all(
                                color:
                                    AppTheme.primary.withOpacity(0.22),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withOpacity(0.07),
                                  blurRadius: 30,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primary
                                        .withOpacity(0.16),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppTheme.primary,
                                    size: 28,
                                  ),
                                ),

                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Plan with AI',
                                        style: TextStyle(
                                          color:
                                              colorScheme.onSurface,
                                          fontSize: 18,
                                          fontWeight:
                                              FontWeight.w800,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        'Tell us your budget, dates and cities. We will help build your perfect Pakistan trip.',
                                        style: TextStyle(
                                          color: colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 12.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // =================================================
                    // SAFETY & EMERGENCY MEDICAL CARD
                    // =================================================

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      sliver: SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: () {
                            _handleBottomNavigation(6);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: colorScheme.surfaceContainerHighest,
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.redAccent.withOpacity(0.14),
                                  ),
                                  child: const Icon(
                                    Icons.health_and_safety_rounded,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Emergency & Medical Aid',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '24/7',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Hospitals, First Aid, Pharmacies & 1122 Helplines',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.redAccent,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
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
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Featured Escapes',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            TextButton(
                              onPressed: () {
                                _showComingSoon('All Destinations');
                              },
                              child: Text(
                                'See All',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =================================================
                    // DESTINATION CARDS
                    // =================================================

                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 360,
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          children: [
                            _DestinationCard(
                              title: 'Fairy Meadows',
                              location: 'Gilgit-Baltistan',
                              tag: 'Adventure',
                              icon: Icons.landscape_rounded,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1590076215668-97019effa016',
                              tagColor: const Color(0xFF8CCBB2),
                              onTap: () {
                                _showComingSoon('Fairy Meadows');
                              },
                            ),

                            const SizedBox(width: 16),

                            _DestinationCard(
                              title: 'Lahore Heritage',
                              location: 'Punjab',
                              tag: 'Culture',
                              icon: Icons.account_balance_rounded,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1584809837053-1f1f2eae0b1d',
                              tagColor: colorScheme.secondary,
                              onTap: () {
                                _showComingSoon('Lahore Heritage');
                              },
                            ),

                            const SizedBox(width: 16),

                            _DestinationCard(
                              title: 'Attabad Lake',
                              location: 'Hunza Valley',
                              tag: 'Nature',
                              icon: Icons.water_rounded,
                              imageUrl:
                                  'https://images.unsplash.com/photo-1609766857041-ed402ea8069a',
                              tagColor: const Color(0xFFA8E7CD),
                              onTap: () {
                                _showComingSoon('Attabad Lake');
                              },
                            ),
                          ],
                        ),
                      ),
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
// DESTINATION CARD
// =========================================================

class _DestinationCard extends StatelessWidget {
  final String title;
  final String location;
  final String tag;
  final IconData icon;
  final String imageUrl;
  final Color tagColor;
  final VoidCallback onTap;

  const _DestinationCard({
    required this.title,
    required this.location,
    required this.tag,
    required this.icon,
    required this.imageUrl,
    required this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 280,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Icon(
                      icon,
                      size: 70,
                      color: AppTheme.primary,
                    ),
                  );
                },
              ),

              // IMAGE GRADIENT
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x22000000),
                      Color(0xF0020305),
                    ],
                  ),
                ),
              ),

              // TAG
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // TEXT
              Positioned(
                left: 22,
                right: 22,
                bottom: 24,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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