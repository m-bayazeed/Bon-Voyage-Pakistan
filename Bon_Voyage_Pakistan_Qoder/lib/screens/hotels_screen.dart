import 'package:flutter/material.dart';
import '../config/api_config.dart';
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
/// Features Real Interactive OpenStreetMap tiles, live Geoapify markers,
/// separate Device GPS vs Search Location state, Geoapify Route Matrix road distance & ETA,
/// and external Google Maps turn-by-turn navigation.
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
  // ── SEPARATE LOCATION CONCEPTS ──
  GeoPoint? _deviceGpsLocation; // Actual device GPS
  String _selectedLocationName = 'Current Location (GPS)';
  double? _selectedLatitude; // Search center latitude
  double? _selectedLongitude; // Search center longitude

  HotelCategory _selectedCategory = HotelCategory.all;
  HotelSortOption _selectedSort = HotelSortOption.nearness;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  List<Hotel> _hotels = [];
  Hotel? _selectedHotel;
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _selectedLocationName = widget.initialCity!;
    }
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
    _initializeLocation();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // Acquire current device GPS and resolve initial search center without auto-loading
    try {
      _deviceGpsLocation = await HotelLocationService.getCurrentLocation();

      final isGps = _selectedLocationName.contains('Current Location') || _selectedLocationName.contains('GPS');
      if (isGps && _deviceGpsLocation != null) {
        _selectedLatitude = _deviceGpsLocation!.latitude;
        _selectedLongitude = _deviceGpsLocation!.longitude;
        _selectedLocationName = 'Current Location (${_selectedLatitude!.toStringAsFixed(3)}, ${_selectedLongitude!.toStringAsFixed(3)})';
      } else {
        final point = await HotelLocationService.resolveDestination(_selectedLocationName);
        _selectedLatitude = point.latitude;
        _selectedLongitude = point.longitude;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadHotels() async {
    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isGps = _selectedLocationName.contains('Current Location') || _selectedLocationName.contains('GPS');
      final double? radius = isGps ? 20.0 : null;

      // Always refresh latest device GPS for routing
      _deviceGpsLocation = await HotelLocationService.getCurrentLocation();

      // Resolve search center coordinates
      if (isGps && _deviceGpsLocation != null) {
        _selectedLatitude = _deviceGpsLocation!.latitude;
        _selectedLongitude = _deviceGpsLocation!.longitude;
        _selectedLocationName = 'Current Location (${_selectedLatitude!.toStringAsFixed(3)}, ${_selectedLongitude!.toStringAsFixed(3)})';
      } else {
        final point = await HotelLocationService.resolveDestination(_selectedLocationName);
        _selectedLatitude = point.latitude;
        _selectedLongitude = point.longitude;
      }

      debugPrint('\n==================== CLIENT HOTEL SEARCH ====================');
      debugPrint('Selected Search Location: $_selectedLocationName');
      debugPrint('Search Center: ($_selectedLatitude, $_selectedLongitude)');
      debugPrint('Actual Device GPS: (${_deviceGpsLocation?.latitude}, ${_deviceGpsLocation?.longitude})');
      debugPrint('=============================================================\n');

      // Fetch nearby stays from backend (Geoapify Places + Route Matrix + Gemini)
      final results = await HotelService.getHotels(
        city: _selectedLocationName,
        category: _selectedCategory,
        sortBy: _selectedSort,
        searchQuery: _searchQuery,
        userLat: _selectedLatitude,
        userLng: _selectedLongitude,
        deviceGpsLat: _deviceGpsLocation?.latitude,
        deviceGpsLng: _deviceGpsLocation?.longitude,
        radiusKm: radius,
      );

      if (!mounted) return;

      setState(() {
        _hotels = results;
        _selectedHotel = results.isNotEmpty ? results.first : null;
        _isLoading = false;
      });

      debugPrint('[HotelsScreen] Loaded ${_hotels.length} stays. Center: ($_selectedLatitude, $_selectedLongitude)');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load stays: $e';
        _isLoading = false;
      });
    }
  }

  void _onCitySelected(String newLocation) async {
    final isGps = newLocation.contains('Current Location') || newLocation.contains('GPS');

    if (isGps) {
      final gps = await HotelLocationService.getCurrentLocation();
      _deviceGpsLocation = gps;
      final lat = gps.latitude;
      final lon = gps.longitude;

      setState(() {
        _selectedLocationName = 'Current Location (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})';
        _selectedLatitude = lat;
        _selectedLongitude = lon;
      });

      debugPrint('[HotelsScreen] GPS Location chosen: (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})');
      return;
    }

    final point = await HotelLocationService.resolveDestination(newLocation);
    setState(() {
      _selectedLocationName = newLocation;
      _selectedLatitude = point.latitude;
      _selectedLongitude = point.longitude;
    });

    debugPrint('[HotelsScreen] City chosen: "$newLocation" -> Center: (${point.latitude}, ${point.longitude})');
  }

  void _onCategoryChanged(HotelCategory category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onSortChanged(HotelSortOption sort) {
    setState(() {
      _selectedSort = sort;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _showLocationDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    final cities = await HotelService.getAvailableCities();
    if (!mounted) return;

    final customLocationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.location_city_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Choose Destination',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: onBg,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Location Search Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.5)
                            : AppTheme.lightSurfaceVariant.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: TextField(
                        controller: customLocationCtrl,
                        style: TextStyle(fontSize: 13, color: onBg),
                        decoration: InputDecoration(
                          hintText: 'Search city, valley, or landmark...',
                          hintStyle: TextStyle(fontSize: 12.5, color: onVar),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.primary),
                            onPressed: () {
                              final text = customLocationCtrl.text.trim();
                              if (text.isNotEmpty) {
                                Navigator.pop(ctx);
                                _onCitySelected(text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Selected "$text". Tap "Search Stays" to find stays.'),
                                    backgroundColor: AppTheme.primary,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            Navigator.pop(ctx);
                            _onCitySelected(text.trim());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Selected "${text.trim()}". Tap "Search Stays" to find stays.'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'POPULAR DESTINATIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: onVar,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // City List
                    ...cities.map((c) {
                      final isSelected = c == _selectedLocationName;
                      final isGps = c.contains('Current Location');

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          size: 18,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isGps ? Colors.green : AppTheme.primary)
                                      : (isGps ? (isDark ? Colors.greenAccent : Colors.green[800]) : onBg),
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
                                  'GPS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: isGps ? Colors.green : AppTheme.primary, size: 18)
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _onCitySelected(c);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHotelDetailsSheet(Hotel hotel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    final hasImage = hotel.imageUrl != null && hotel.imageUrl!.trim().isNotEmpty;
    final hasRating = hotel.rating != null && hotel.rating! > 0;
    final hasPrice = hotel.formattedPrice != null;

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
                    // Hero Image / Stylized Header
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: hasImage
                            ? Image.network(
                                hotel.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: isDark
                                      ? AppTheme.darkSurfaceVariant
                                      : AppTheme.lightSurfaceVariant,
                                  child: Icon(hotel.category.icon, size: 60, color: AppTheme.primary),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            const Color(0xFF1E2824),
                                            hotel.category.color.withOpacity(0.3),
                                            const Color(0xFF121715),
                                          ]
                                        : [
                                            const Color(0xFFE2EBE5),
                                            hotel.category.color.withOpacity(0.2),
                                            const Color(0xFFD3E0D8),
                                          ],
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(hotel.category.icon, size: 56, color: hotel.category.color),
                                      const SizedBox(height: 8),
                                      Text(
                                        hotel.badgeLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: onBg,
                                        ),
                                      ),
                                    ],
                                  ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hotel.name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: onBg,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (hotel.highlight != null && hotel.highlight!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      hotel.highlight!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (hasPrice) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              hotel.formattedPrice!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Rating, Category Badge & Distance Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hotel.category.color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hotel.badgeLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: hotel.category.color,
                            ),
                          ),
                        ),
                        if (hasRating) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '${hotel.rating!.toStringAsFixed(1)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hotel.distance,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Address Card
                    if (hotel.address.isNotEmpty) ...[
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
                              child: Text(
                                hotel.address,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

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

                    // Amenities Section
                    if (hotel.amenities.isNotEmpty || hotel.customAmenities.isNotEmpty) ...[
                      Text(
                        'Amenities & Features',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...hotel.amenities.map((a) {
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
                          }),
                          ...hotel.customAmenities.map((label) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkSurfaceVariant.withOpacity(0.6)
                                    : AppTheme.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onBg),
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Action Buttons (Call / Directions)
                    Row(
                      children: [
                        if (hotel.phone != null && hotel.phone!.isNotEmpty) ...[
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
                        ],
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              HotelNavigationService.launchGoogleMapsDirections(context, hotel);
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
        title: const Row(
          children: [
            Icon(Icons.phone_in_talk_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Contact Stay', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          'Connect with ${hotel.name} front desk at:\n\n${hotel.phone ?? "Phone unavailable"}',
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
                    // ── 1. Header with Region Selector & ThemeToggle ──
                    _buildHeader(),

                    const SizedBox(height: 16),

                    // ── 2. Search & Category Filter ──
                    _buildSearchAndFilters(),

                    const SizedBox(height: 14),

                    // ── 3. Sorting Selector ──
                    _buildSortSelector(),

                    const SizedBox(height: 16),

                    // ── 4. Prominent Manual "Search Stays" Button ──
                    _buildSearchActionButton(),

                    const SizedBox(height: 20),

                    // ── 5. Real Interactive Geographic Map (Geoapify OSM Tiles) ──
                    InteractiveHotelMap(
                      hotels: _hotels,
                      selectedHotel: _selectedHotel,
                      centerLat: _selectedLatitude,
                      centerLng: _selectedLongitude,
                      userLat: _deviceGpsLocation?.latitude,
                      userLng: _deviceGpsLocation?.longitude,
                      height: 300,
                      onHotelSelected: (hotel) {
                        setState(() => _selectedHotel = hotel);
                        _showHotelDetailsSheet(hotel);
                      },
                      onRecenter: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Map centered on $_selectedLocationName (${_selectedLatitude?.toStringAsFixed(3)}, ${_selectedLongitude?.toStringAsFixed(3)}).'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── 6. Results List Header ──
                    _buildListHeader(),

                    const SizedBox(height: 14),

                    // ── 7. Results List / State Handlers ──
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
    final isGpsSelected = _selectedLocationName.contains('Current Location');

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

            // City / Location Selector Pill
            GestureDetector(
              onTap: _showLocationDialog,
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
                        _selectedLocationName,
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
          '"Discover premier mountain resorts, boutique lodges & heritage stays in Pakistan."',
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
  // 2. CATEGORY FILTER & SEARCH
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSearchAndFilters() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Column(
      children: [
        // Text Search Field
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: 13, color: onBg),
            decoration: InputDecoration(
              hintText: 'Search keyword for $_selectedLocationName...',
              hintStyle: TextStyle(fontSize: 12.5, color: onVar),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 12),

        // Stay Category Filter Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedCategory != HotelCategory.all
                  ? AppTheme.primary.withOpacity(0.5)
                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
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
                          color: cat.color.withOpacity(0.14),
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
        ),
      ],
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
  // 4. MANUAL SEARCH STAYS ACTION BUTTON
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSearchActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _loadHotels,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.travel_explore_rounded, size: 20),
        label: Text(
          _isLoading ? 'Finding Stays...' : 'Search Stays in $_selectedLocationName',
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: AppTheme.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. LIST HEADER
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
          _hasSearched
              ? '${_hotels.length} ${_hotels.length == 1 ? 'stay' : 'stays'} found'
              : 'Select Category & Tap Search',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onVar),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. RESULTS LIST / STATE HANDLERS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildResultsContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_hasSearched && !_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.travel_explore_rounded, size: 38, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Discover Stays in $_selectedLocationName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your preferred accommodation category and sorting option above, then tap "Search Stays" to find verified properties with live road distance and route ETA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadHotels,
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                'Search Stays in $_selectedLocationName',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
              const SizedBox(height: 12),
              Text(
                'Finding stays near $_selectedLocationName...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
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
              'No stays found in this area.',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              'Try expanding category filters or searching another destination.',
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
              child: const Text('Reset Category Filters'),
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
            HotelNavigationService.launchGoogleMapsDirections(context, hotel);
          },
          onCall: () {
            _showCallDialog(hotel);
          },
        );
      },
    );
  }
}
