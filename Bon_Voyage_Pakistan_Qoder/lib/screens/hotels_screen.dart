import 'package:flutter/material.dart';
import '../models/hotel_model.dart';
import '../services/hotel_location_service.dart';
import '../services/hotel_navigation_service.dart';
import '../services/hotel_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/hotel_card.dart';
import '../widgets/interactive_hotel_map.dart';
import '../widgets/theme_toggle.dart';

/// Premier Hotels & Stays Discovery Screen for Bon Voyage Pakistan.
class HotelsScreen extends StatefulWidget {
  final String? initialCity;
  final HotelCategory? initialCategory;

  const HotelsScreen({
    super.key,
    this.initialCity,
    this.initialCategory,
  });

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCity = 'Islamabad';
  HotelCategory _selectedCategory = HotelCategory.all;
  HotelSortOption _selectedSort = HotelSortOption.nearness;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<Hotel> _hotels = [];
  Hotel? _selectedHotel;
  bool _isLoading = true;
  String? _errorMessage;

  // Active user GPS coordinates
  double? _userLat;
  double? _userLng;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null) {
      _selectedCity = widget.initialCity!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
    _loadHotels();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHotels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // If GPS mode selected, acquire device coordinates
      if (_selectedCity.contains('Current Location')) {
        final loc = await HotelLocationService.getCurrentLocation();
        _userLat = loc.latitude;
        _userLng = loc.longitude;
      } else {
        final cityCenter = HotelLocationService.getCityCenter(_selectedCity);
        _userLat = cityCenter.latitude;
        _userLng = cityCenter.longitude;
      }

      final results = await HotelService.getHotels(
        city: _selectedCity,
        category: _selectedCategory,
        sortBy: _selectedSort,
        searchQuery: _searchQuery,
        userLat: _userLat,
        userLng: _userLng,
      );

      if (!mounted) return;

      setState(() {
        _hotels = results;
        _selectedHotel = results.isNotEmpty ? results.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load hotels: $e';
        _isLoading = false;
      });
    }
  }

  void _onCityChanged(String newCity) {
    setState(() {
      _selectedCity = newCity;
    });
    _loadHotels();
  }

  void _onCategoryChanged(HotelCategory category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadHotels();
  }

  void _onSortChanged(HotelSortOption sort) {
    setState(() {
      _selectedSort = sort;
    });
    _loadHotels();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadHotels();
  }

  void _showCityDialog() {
    final cities = HotelService.getAvailableCities();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.location_city_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Select Destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cities.length,
            itemBuilder: (_, i) {
              final c = cities[i];
              final isSelected = c == _selectedCity;
              final isGps = c.contains('Current Location');

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isSelected
                    ? (isGps ? Colors.green.withOpacity(0.18) : AppTheme.primary.withOpacity(0.15))
                    : (isGps ? Colors.green.withOpacity(0.08) : Colors.transparent),
                leading: Icon(
                  isGps
                      ? Icons.my_location_rounded
                      : (c == 'All Locations' ? Icons.public_rounded : Icons.place_rounded),
                  color: isSelected
                      ? (isGps ? Colors.green : AppTheme.primary)
                      : (isGps ? Colors.green : (isDark ? Colors.white60 : Colors.black45)),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isGps ? Colors.green : AppTheme.primary)
                              : (isGps ? (isDark ? Colors.greenAccent : Colors.green[800]) : (isDark ? Colors.white : Colors.black87)),
                        ),
                      ),
                    ),
                    if (isGps)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE GPS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: isGps
                    ? Text(
                        'Find hotels closest to your device coordinates',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: isGps ? Colors.green : AppTheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onCityChanged(c);
                  if (isGps) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Acquiring GPS coordinates... Searching nearest stays.'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showHotelDetailsSheet(Hotel hotel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(
                color: AppTheme.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
          ),
          child: Column(
            children: [
              // Top Bar Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: onVar.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  children: [
                    // Hero Image with Category Badge
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 220,
                        width: double.infinity,
                        child: Image.network(
                          hotel.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: isDark ? AppTheme.darkSurfaceVariant : AppTheme.lightSurfaceVariant,
                            child: Icon(hotel.category.icon, size: 60, color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Title & Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            hotel.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: onBg,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            hotel.formattedPrice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Rating & Distance Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${hotel.rating}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${hotel.reviewCount} verified reviews)',
                          style: TextStyle(fontSize: 12.5, color: onVar),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(
                          hotel.distance,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Address Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.4)
                            : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hotel.address,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
                                ),
                                if (hotel.landmarkNearby.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Near: ${hotel.landmarkNearby}',
                                    style: TextStyle(fontSize: 11.5, color: onVar),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'About this stay',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hotel.description,
                      style: TextStyle(fontSize: 13.5, color: onVar, height: 1.45),
                    ),
                    const SizedBox(height: 20),

                    // Popular review highlight
                    if (hotel.popularReviewSnippet != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded, color: AppTheme.primary, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '"${hotel.popularReviewSnippet}"',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: onBg,
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Amenities Section
                    Text(
                      'Amenities & Features',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hotel.amenities.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceVariant.withOpacity(0.6)
                                : AppTheme.lightSurfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(a.icon, size: 15, color: AppTheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                a.displayName,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onBg),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons (Call / Directions)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCallDialog(hotel);
                            },
                            icon: const Icon(Icons.call, size: 17),
                            label: const Text('Call Desk', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              HotelNavigationService.showNavigationModal(context, hotel);
                            },
                            icon: const Icon(Icons.directions_rounded, size: 18),
                            label: const Text('Get Directions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
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

  void _showCallDialog(Hotel hotel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text('Contact Concierge', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        content: Text(
          'Connect with ${hotel.name} front desk at:\n\n${hotel.phone}',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dialing ${hotel.phone}...'),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.call, size: 16),
            label: const Text('Dial Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: RefreshIndicator(
              onRefresh: _loadHotels,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Header with Back Button, Region Selector & ThemeToggle ──
                    _buildHeader(),

                    const SizedBox(height: 16),

                    // ── 2. Search & Category Filter ──
                    _buildSearchAndFilters(),

                    const SizedBox(height: 16),

                    // ── 3. Sorting Selector ──
                    _buildSortSelector(),

                    const SizedBox(height: 20),

                    // ── 4. Interactive Map Section ──
                    InteractiveHotelMap(
                      hotels: _hotels,
                      selectedHotel: _selectedHotel,
                      height: 290,
                      onHotelSelected: (hotel) {
                        setState(() => _selectedHotel = hotel);
                        _showHotelDetailsSheet(hotel);
                      },
                      onRecenter: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Map re-centered on $_selectedCity.'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── 5. Results List Header ──
                    _buildListHeader(),

                    const SizedBox(height: 14),

                    // ── 6. Results List / State Handlers ──
                    _buildResultsContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. HEADER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final tp = ThemeProviderScope.of(context);
    final isGpsSelected = _selectedCity.contains('Current Location');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: onBg, size: 18),
              ),
            ),

            // City / Region Selector Pill
            GestureDetector(
              onTap: _showCityDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGpsSelected ? Colors.green.withOpacity(0.6) : AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGpsSelected ? Icons.my_location_rounded : Icons.location_on_rounded,
                      color: isGpsSelected ? Colors.green : AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        _selectedCity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isGpsSelected ? (isDark ? Colors.greenAccent : Colors.green[800]) : onBg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: onVar, size: 16),
                  ],
                ),
              ),
            ),

            // Theme toggle
            ThemeToggle(isDark: tp.isDark, onToggle: () => tp.toggleTheme()),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Hotels & Stays',
          style: TextStyle(
            color: onBg,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '"Discover premier mountain resorts, boutique lodges & heritage palaces in Pakistan."',
          style: TextStyle(
            color: onVar,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. CATEGORY FILTER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedCategory != HotelCategory.all
              ? AppTheme.primary.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: _selectedCategory != HotelCategory.all ? 1.4 : 1.0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HotelCategory>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
          items: HotelCategory.values.map((cat) {
            return DropdownMenuItem<HotelCategory>(
              value: cat,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    cat.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: onBg,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _onCategoryChanged(val);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. SORT SELECTOR
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSortSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Row(
      children: [
        Icon(Icons.sort_rounded, size: 16, color: onVar),
        const SizedBox(width: 6),
        Text(
          'Sort by:',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: onVar),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HotelSortOption>(
                value: _selectedSort,
                isExpanded: true,
                dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(14),
                icon: const Icon(Icons.unfold_more_rounded, size: 16, color: AppTheme.primary),
                items: HotelSortOption.values.map((sort) {
                  return DropdownMenuItem<HotelSortOption>(
                    value: sort,
                    child: Row(
                      children: [
                        Icon(sort.icon, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          sort.displayName,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onBg),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) _onSortChanged(val);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. LIST HEADER
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildListHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Available Stays',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg),
        ),
        Text(
          '${_hotels.length} ${_hotels.length == 1 ? 'stay' : 'stays'} found',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onVar),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. RESULTS LIST / STATE HANDLERS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildResultsContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Searching premier verified stays in Pakistan...',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            Text(
              'Unable to Load Stays',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadHotels,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    if (_hotels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.hotel_class_outlined, size: 44, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 12),
            Text(
              'No Stays Matching Criteria',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your destination city, resetting category filters, or clearing search keywords.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = HotelCategory.all;
                });
                _loadHotels();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _hotels.length,
      itemBuilder: (context, index) {
        final hotel = _hotels[index];
        return HotelCard(
          hotel: hotel,
          onTap: () {
            setState(() => _selectedHotel = hotel);
            _showHotelDetailsSheet(hotel);
          },
          onDirections: () {
            HotelNavigationService.showNavigationModal(context, hotel);
          },
          onCall: () {
            _showCallDialog(hotel);
          },
        );
      },
    );
  }
}
