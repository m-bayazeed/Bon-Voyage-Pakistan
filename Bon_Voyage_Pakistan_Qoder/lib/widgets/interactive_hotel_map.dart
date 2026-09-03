import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/hotel_model.dart';
import '../theme/app_theme.dart';

/// Real Interactive Vector Tile Map with Geoapify OSM Cartography,
/// distinct User GPS beacon, exact Hotel markers, zoom controls, and quick card preview.
class InteractiveHotelMap extends StatefulWidget {
  final List<Hotel> hotels;
  final Hotel? selectedHotel;
  final double? centerLat;
  final double? centerLng;
  final double? userLat;
  final double? userLng;
  final ValueChanged<Hotel>? onHotelSelected;
  final VoidCallback? onRecenter;
  final double height;

  const InteractiveHotelMap({
    super.key,
    required this.hotels,
    this.selectedHotel,
    this.centerLat,
    this.centerLng,
    this.userLat,
    this.userLng,
    this.onHotelSelected,
    this.onRecenter,
    this.height = 300,
  });

  @override
  State<InteractiveHotelMap> createState() => _InteractiveHotelMapState();
}

class _InteractiveHotelMapState extends State<InteractiveHotelMap>
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
  void didUpdateWidget(covariant InteractiveHotelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When center changes or search destination updates, smoothly recenter map
    if (widget.centerLat != oldWidget.centerLat ||
        widget.centerLng != oldWidget.centerLng) {
      final lat = widget.centerLat ?? widget.userLat ?? 33.6844;
      final lng = widget.centerLng ?? widget.userLng ?? 73.0479;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(LatLng(lat, lng), 12.8);
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
    final lat = widget.centerLat ?? widget.userLat ?? (widget.hotels.isNotEmpty ? widget.hotels.first.latitude : 33.6844);
    final lng = widget.centerLng ?? widget.userLng ?? (widget.hotels.isNotEmpty ? widget.hotels.first.longitude : 73.0479);
    _mapController.move(LatLng(lat, lng), 13.0);
    widget.onRecenter?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchLat = widget.centerLat ?? widget.userLat ?? (widget.hotels.isNotEmpty ? widget.hotels.first.latitude : 33.6844);
    final searchLng = widget.centerLng ?? widget.userLng ?? (widget.hotels.isNotEmpty ? widget.hotels.first.longitude : 73.0479);
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
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(isDark ? 0.12 : 0.06),
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
                  urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=$_geoapifyApiKey',
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

                    // Hotel Accommodation Markers at Exact Coordinates
                    ...widget.hotels.map((hotel) {
                      final isSelected = widget.selectedHotel?.id == hotel.id;
                      return Marker(
                        point: LatLng(hotel.latitude, hotel.longitude),
                        width: 72,
                        height: 54,
                        alignment: Alignment.center,
                        child: _HotelRealMapMarker(
                          hotel: hotel,
                          isSelected: isSelected,
                          onTap: () {
                            _mapController.move(LatLng(hotel.latitude, hotel.longitude), 14.5);
                            widget.onHotelSelected?.call(hotel);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

            // ── 3. Top Left Live Stays Counter ──
            Positioned(
              top: 14,
              left: 14,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkSurface : Colors.white).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
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
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${widget.hotels.length} Stays Mapped • Tap pin for details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 4. Top Right Controls: Zoom & Recenter ──
            Positioned(
              top: 14,
              right: 14,
              child: Column(
                children: [
                  _MapControlBtn(
                    icon: Icons.add,
                    onTap: _zoomIn,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.remove,
                    onTap: _zoomOut,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.my_location_rounded,
                    onTap: _recenter,
                    isDark: isDark,
                    tooltip: 'Recenter Map',
                  ),
                ],
              ),
            ),

            // ── 5. Bottom Right Attribution ──
            Positioned(
              bottom: widget.selectedHotel != null ? 78 : 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black87 : Colors.white.withOpacity(0.85)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  'Powered by Geoapify | © OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 8.0,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ),

            // ── 6. Bottom Active Hotel Quick Preview Card ──
            if (widget.selectedHotel != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: _SelectedHotelQuickCard(
                  hotel: widget.selectedHotel!,
                  onTap: () => widget.onHotelSelected?.call(widget.selectedHotel!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CURRENT USER GPS MARKER
// ─────────────────────────────────────────────────────────────────────────────
class _CurrentUserGpsMarker extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _CurrentUserGpsMarker({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.3),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E88E5),
              border: Border.all(color: Colors.white, width: 3.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.6),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.navigation_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CENTER RADAR PIN
// ─────────────────────────────────────────────────────────────────────────────
class _SearchCenterRadarPin extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _SearchCenterRadarPin({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.25),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOTEL REAL MAP MARKER
// ─────────────────────────────────────────────────────────────────────────────
class _HotelRealMapMarker extends StatelessWidget {
  final Hotel hotel;
  final bool isSelected;
  final VoidCallback onTap;

  const _HotelRealMapMarker({
    required this.hotel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = hotel.category.color;
    final hasPrice = hotel.pricePerNightPkr != null && hotel.pricePerNightPkr! > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price pill badge or road distance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : catColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                hasPrice
                    ? 'PKR ${(hotel.pricePerNightPkr! / 1000).toStringAsFixed(0)}k'
                    : hotel.distance,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Pin Circle Icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : catColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  width: isSelected ? 2.5 : 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppTheme.primary : catColor).withOpacity(0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                hotel.category.icon,
                size: 15,
                color: isSelected ? AppTheme.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTED HOTEL QUICK CARD PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _SelectedHotelQuickCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onTap;

  const _SelectedHotelQuickCard({required this.hotel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasRating = hotel.rating != null && hotel.rating! > 0;
    final hasPrice = hotel.pricePerNightPkr != null && hotel.pricePerNightPkr! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF1E2422) : Colors.white).withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.4),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Category Icon Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hotel.category.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                hotel.category.icon,
                color: hotel.category.color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Hotel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hotel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (hasRating) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                        const SizedBox(width: 2),
                        Text(
                          hotel.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('•', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          hotel.distance,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '• ${hotel.badgeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Price badge or view badge
            if (hasPrice)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'PKR ${(hotel.pricePerNightPkr! / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP CONTROL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool highlight;
  final String? tooltip;

  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.highlight = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.primary
              : (isDark ? AppTheme.darkSurface : Colors.white).withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(
            color: highlight
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 17,
          color: highlight
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}
