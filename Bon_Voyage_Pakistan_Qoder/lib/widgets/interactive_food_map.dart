import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/food_place_model.dart';
import '../services/food_navigation_service.dart';
import '../theme/app_theme.dart';

/// Real Interactive Vector Tile Map for Food & Dining locations with Geoapify OSM Cartography,
/// distinct User GPS beacon, exact Restaurant markers, zoom controls, and quick card preview.
class InteractiveFoodMap extends StatefulWidget {
  final List<FoodPlace> places;
  final FoodPlace? selectedPlace;
  final double? centerLat;
  final double? centerLng;
  final double? userLat;
  final double? userLng;
  final ValueChanged<FoodPlace?> onPlaceSelected;
  final VoidCallback? onDirectionsTap;
  final VoidCallback? onRecenter;
  final double height;

  const InteractiveFoodMap({
    super.key,
    required this.places,
    this.selectedPlace,
    this.centerLat,
    this.centerLng,
    this.userLat,
    this.userLng,
    required this.onPlaceSelected,
    this.onDirectionsTap,
    this.onRecenter,
    this.height = 260,
  });

  @override
  State<InteractiveFoodMap> createState() => _InteractiveFoodMapState();
}

class _InteractiveFoodMapState extends State<InteractiveFoodMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String _geoapifyApiKey = '454af56eb7eb4805ab7fc12bd150891a';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant InteractiveFoodMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centerLat != oldWidget.centerLat ||
        widget.centerLng != oldWidget.centerLng) {
      final lat = widget.centerLat ?? widget.userLat ?? 33.6844;
      final lng = widget.centerLng ?? widget.userLng ?? 73.0479;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(lat, lng), 12.8);
        } catch (_) {}
      });
    } else if (widget.selectedPlace != null &&
        widget.selectedPlace?.id != oldWidget.selectedPlace?.id) {
      final sel = widget.selectedPlace!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(sel.latitude, sel.longitude), 14.5);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final center = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(center, (currentZoom + 1).clamp(4.0, 18.0));
  }

  void _zoomOut() {
    final center = _mapController.camera.center;
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(center, (currentZoom - 1).clamp(4.0, 18.0));
  }

  void _recenter() {
    final lat = widget.centerLat ??
        widget.userLat ??
        (widget.places.isNotEmpty ? widget.places.first.latitude : 33.6844);
    final lng = widget.centerLng ??
        widget.userLng ??
        (widget.places.isNotEmpty ? widget.places.first.longitude : 73.0479);
    _mapController.move(LatLng(lat, lng), 13.0);
    widget.onRecenter?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchLat = widget.centerLat ??
        widget.userLat ??
        (widget.places.isNotEmpty ? widget.places.first.latitude : 33.6844);
    final searchLng = widget.centerLng ??
        widget.userLng ??
        (widget.places.isNotEmpty ? widget.places.first.longitude : 73.0479);
    final searchCenterPoint = LatLng(searchLat, searchLng);

    final hasUserGps = widget.userLat != null && widget.userLng != null;
    final userGpsPoint = hasUserGps ? LatLng(widget.userLat!, widget.userLng!) : null;
    final isSearchSameAsGps = hasUserGps &&
        (searchLat - widget.userLat!).abs() < 0.001 &&
        (searchLng - widget.userLng!).abs() < 0.001;

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141918) : const Color(0xFFE8ECE9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ── 1. Real Geoapify OSM-Bright Map Tiles ──
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: searchCenterPoint,
                initialZoom: 12.5,
                minZoom: 4.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=$_geoapifyApiKey',
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bonvoyage.pakistan',
                  maxZoom: 19,
                ),

                // ── 2. Real Geoapify Markers Layer ──
                MarkerLayer(
                  markers: [
                    // Search Center Anchor (when distinct from user GPS)
                    if (!isSearchSameAsGps)
                      Marker(
                        point: searchCenterPoint,
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: _SearchCenterRadarPin(pulseAnimation: _pulseAnimation),
                      ),

                    // Current Device Location GPS Pin
                    if (userGpsPoint != null)
                      Marker(
                        point: userGpsPoint,
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: _CurrentUserGpsMarker(pulseAnimation: _pulseAnimation),
                      ),

                    // Food Place Markers at Exact Coordinates
                    ...widget.places.map((place) {
                      final isSelected = widget.selectedPlace?.id == place.id;
                      return Marker(
                        point: LatLng(place.latitude, place.longitude),
                        width: 76,
                        height: 56,
                        alignment: Alignment.center,
                        child: _FoodRealMapMarker(
                          place: place,
                          isSelected: isSelected,
                          onTap: () {
                            _mapController.move(LatLng(place.latitude, place.longitude), 14.5);
                            widget.onPlaceSelected(place);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // ── 3. Top Info Pill ──
            Positioned(
              top: 12,
              left: 14,
              right: 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E2624) : Colors.white).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE65100), // Rich food orange
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${widget.places.length} Food Spots • 30 km radius',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4. Map Control Buttons (Recenter & Zoom) ──
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapIconButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Recenter Map',
                    isDark: isDark,
                    onTap: _recenter,
                  ),
                  const SizedBox(height: 6),
                  _MapIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom In',
                    isDark: isDark,
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 6),
                  _MapIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom Out',
                    isDark: isDark,
                    onTap: _zoomOut,
                  ),
                ],
              ),
            ),

            // ── 5. Selected Food Place Quick Card Preview ──
            if (widget.selectedPlace != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _FoodQuickPreviewCard(
                  place: widget.selectedPlace!,
                  isDark: isDark,
                  userLat: widget.userLat,
                  userLng: widget.userLng,
                  onClose: () => widget.onPlaceSelected(null),
                  onDirections: () {
                    widget.onDirectionsTap?.call();
                    FoodNavigationService.launchGoogleMapsDirections(
                      context,
                      widget.selectedPlace!,
                      userLat: widget.userLat,
                      userLng: widget.userLng,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Food Marker on real map with price, category color, rating, and interactive tap
class _FoodRealMapMarker extends StatelessWidget {
  final FoodPlace place;
  final bool isSelected;
  final VoidCallback onTap;

  const _FoodRealMapMarker({
    required this.place,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = place.category.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pill tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE65100) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : catColor,
                  width: isSelected ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    place.category.icon,
                    size: 11,
                    color: isSelected ? Colors.white : catColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '★ ${place.rating.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF2D312E),
                    ),
                  ),
                ],
              ),
            ),
            // Pin Triangle
            CustomPaint(
              size: const Size(8, 5),
              painter: _TrianglePainter(
                color: isSelected ? const Color(0xFFE65100) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User GPS Marker beacon
class _CurrentUserGpsMarker extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _CurrentUserGpsMarker({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38 * pulseAnimation.value,
              height: 38 * pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2196F3).withValues(alpha: (0.4 / pulseAnimation.value).clamp(0.0, 0.4)),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Search Center Radar Pin
class _SearchCenterRadarPin extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _SearchCenterRadarPin({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 34 * pulseAnimation.value,
              height: 34 * pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: (0.3 / pulseAnimation.value).clamp(0.0, 0.3)),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Quick preview card for selected food spot on map
class _FoodQuickPreviewCard extends StatelessWidget {
  final FoodPlace place;
  final bool isDark;
  final double? userLat;
  final double? userLng;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  const _FoodQuickPreviewCard({
    required this.place,
    required this.isDark,
    this.userLat,
    this.userLng,
    required this.onClose,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? Colors.white : const Color(0xFF1C1B1F);
    final onVar = isDark ? const Color(0xFFCAC4D0) : const Color(0xFF49454F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E2624) : Colors.white).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Restaurant thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 54,
              height: 54,
              child: place.imageUrl.isNotEmpty
                  ? Image.network(
                      place.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: place.category.color.withValues(alpha: 0.2),
                        child: Icon(place.category.icon, color: place.category.color, size: 24),
                      ),
                    )
                  : Container(
                      color: place.category.color.withValues(alpha: 0.2),
                      child: Icon(place.category.icon, color: place.category.color, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: onBg,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB300)),
                    const SizedBox(width: 2),
                    Text(
                      place.rating.toStringAsFixed(1),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: onBg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '•  ${place.distance} (~${place.estimatedTravelTime})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  place.cuisine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: onVar),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Direction button & Close button
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onClose,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Icon(Icons.close_rounded, size: 16, color: onVar),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: onDirections,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_rounded, size: 13),
                    SizedBox(width: 3),
                    Text('Go', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _MapIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E2624) : Colors.white).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF2D312E),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      color != oldDelegate.color;
}
