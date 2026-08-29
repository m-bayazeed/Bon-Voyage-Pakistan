import 'package:flutter/material.dart';
import '../models/food_place_model.dart';
import '../services/food_navigation_service.dart';
import '../services/food_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/food_place_card.dart';
import '../widgets/interactive_food_map.dart';
import '../widgets/theme_toggle.dart';

/// Premier Food & Dining screen for exploring culinary destinations across Pakistan.
class FoodDiningScreen extends StatefulWidget {
  const FoodDiningScreen({super.key});

  @override
  State<FoodDiningScreen> createState() => _FoodDiningScreenState();
}

class _FoodDiningScreenState extends State<FoodDiningScreen> {
  // Search & Filter State
  String _selectedCity = 'Islamabad';
  bool _useCurrentLocation = false;
  FoodCategory _selectedCategory = FoodCategory.all;
  FoodSortOption _selectedSort = FoodSortOption.rating;

  // Data & View State
  List<FoodPlace> _places = [];
  FoodPlace? _selectedPlace;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFoodPlaces();
  }

  Future<void> _loadFoodPlaces() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await FoodService.searchFoodPlaces(
        city: _selectedCity,
        useCurrentLocation: _useCurrentLocation,
        category: _selectedCategory,
        sortOption: _selectedSort,
      );

      if (mounted) {
        setState(() {
          _places = results;
          _isLoading = false;
          _selectedPlace = results.isNotEmpty ? results.first : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load food places. Please check your connection.';
        });
      }
    }
  }

  // ──────────────────────────────────────────
  // Location Selector Dialog
  // ──────────────────────────────────────────

  void _showLocationSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final cities = FoodService.getSupportedCities();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: onVar.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Food Destination',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 14),

            // Use Current Location (GPS) Tile
            Material(
              color: _useCurrentLocation
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : isDark
                      ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                      : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _useCurrentLocation = true;
                    _selectedCity = 'Current Location (GPS)';
                  });
                  _loadFoodPlaces();
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Use Current Location (GPS)',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Find top restaurants and dhabas nearest to you',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: onVar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_useCurrentLocation)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // City Options Header
            Text(
              'OR CHOOSE A CITY / REGION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: onVar,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // List of Cities
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: cities.length,
                itemBuilder: (_, i) {
                  final city = cities[i];
                  final isSelected = !_useCurrentLocation && _selectedCity == city;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        Icons.location_city_rounded,
                        color: isSelected ? AppTheme.primary : onVar,
                        size: 20,
                      ),
                      title: Text(
                        city,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppTheme.primary : onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _useCurrentLocation = false;
                          _selectedCity = city;
                        });
                        _loadFoodPlaces();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Food Details Modal Sheet
  // ──────────────────────────────────────────

  void _showPlaceDetailsSheet(FoodPlace place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: onVar.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Hero Image with Category Badge
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Image.network(
                      place.imageUrl,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 190,
                        color: isDark ? const Color(0xFF1E2816) : const Color(0xFFE2EBD8),
                        alignment: Alignment.center,
                        child: Icon(place.category.icon, size: 56, color: AppTheme.primary),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: place.category.color.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(place.category.icon, size: 13, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              place.category.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Title, Rating & Distance Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          place.cuisine,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: onVar,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          place.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Timing & Cost Chips
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                          : AppTheme.lightSurfaceVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          place.openingHours,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.5)
                          : AppTheme.lightSurfaceVariant.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      place.formattedCost,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: onSurface),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'About this Food Destination',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                place.description,
                style: TextStyle(
                  fontSize: 13,
                  color: onVar,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Signature Specialties
              if (place.specialties.isNotEmpty) ...[
                Text(
                  'Signature Dishes & Specialties',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: place.specialties.map((dish) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: place.category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: place.category.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '🍴 $dish',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Popular Review Snippet
              if (place.popularReview != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                        : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.format_quote_rounded, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'TRAVELER REVIEW HIGHLIGHT',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: onVar,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        place.popularReview!,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: onSurface,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling ${place.name}: ${place.phone}'),
                            backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.15),
                        ),
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
                        FoodNavigationService.showNavigationModal(context, place);
                      },
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text(
                        'Get Directions',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProviderScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar & Location Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      Material(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onBg),
                          ),
                        ),
                      ),

                      // City / Region Selector Pill
                      Material(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _showLocationSelector,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _useCurrentLocation
                                    ? Colors.green.withValues(alpha: 0.6)
                                    : AppTheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _useCurrentLocation ? Icons.my_location_rounded : Icons.location_on_rounded,
                                  size: 16,
                                  color: _useCurrentLocation ? Colors.green : AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    _useCurrentLocation ? 'Current Location (GPS)' : _selectedCity,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: _useCurrentLocation
                                          ? (isDark ? Colors.greenAccent : Colors.green[800])
                                          : onBg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: onVar),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Theme Toggle
                      ThemeToggle(isDark: tp.isDark, onToggle: () => tp.toggleTheme()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Food & Dining',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"Explore authentic Pakistani cuisines, street food gems & scenic mountain cafés."',
                    style: TextStyle(
                      color: onVar,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Dropdown Filters (Category & Sort)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  // Category Dropdown
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FoodCategory>(
                          value: _selectedCategory,
                          isExpanded: true,
                          dropdownColor: surface,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: onVar, size: 18),
                          items: FoodCategory.values.map((cat) {
                            return DropdownMenuItem<FoodCategory>(
                              value: cat,
                              child: Row(
                                children: [
                                  Icon(cat.icon, size: 14, color: cat.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cat.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: onBg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newCat) {
                            if (newCat != null && newCat != _selectedCategory) {
                              setState(() => _selectedCategory = newCat);
                              _loadFoodPlaces();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Sort Dropdown
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<FoodSortOption>(
                          value: _selectedSort,
                          isExpanded: true,
                          dropdownColor: surface,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: onVar, size: 18),
                          items: FoodSortOption.values.map((sort) {
                            return DropdownMenuItem<FoodSortOption>(
                              value: sort,
                              child: Row(
                                children: [
                                  Icon(sort.icon, size: 14, color: AppTheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      sort.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: onBg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (newSort) {
                            if (newSort != null && newSort != _selectedSort) {
                              setState(() => _selectedSort = newSort);
                              _loadFoodPlaces();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Main Content (Map & Results List)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                          SizedBox(height: 14),
                          Text(
                            'Discovering nearby food spots...',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: onVar),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadFoodPlaces,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: AppTheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _places.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.restaurant_rounded, size: 48, color: AppTheme.primary),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No food places found for $_selectedCity in ${_selectedCategory.displayName}.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, color: onVar),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategory = FoodCategory.all;
                                        });
                                        _loadFoodPlaces();
                                      },
                                      child: const Text('Show All Cuisines'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // Vector Map Section
                                InteractiveFoodMap(
                                  places: _places,
                                  selectedPlace: _selectedPlace,
                                  onPlaceSelected: (p) => setState(() => _selectedPlace = p),
                                  height: 220,
                                ),
                                const SizedBox(height: 16),

                                // Section Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Nearby Restaurants & Dhabas (${_places.length})',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: onBg,
                                      ),
                                    ),
                                    Text(
                                      _selectedSort.displayName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Food Cards List
                                ..._places.map((place) {
                                  final isSelected = _selectedPlace?.id == place.id;
                                  return FoodPlaceCard(
                                    place: place,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() => _selectedPlace = place);
                                      _showPlaceDetailsSheet(place);
                                    },
                                  );
                                }),
                                const SizedBox(height: 24),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
