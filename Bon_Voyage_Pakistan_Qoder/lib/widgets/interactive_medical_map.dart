import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_facility_model.dart';
import '../services/hotel_location_service.dart';
import '../theme/app_theme.dart';

/// Real Interactive Vector Tile Map for First Aid & Medical Facilities
/// with Geoapify OSM Cartography, distinct User GPS beacon, exact facility markers,
/// zoom controls, and quick card preview.
class InteractiveMedicalMap extends StatefulWidget {
  final List<MedicalFacility> facilities;
  final MedicalFacility? selectedFacility;
  final double? centerLat;
  final double? centerLng;
  final double? userLat;
  final double? userLng;
  final ValueChanged<MedicalFacility>? onFacilitySelected;
  final void Function(MedicalFacility)? onDirectionsTap;
  final VoidCallback? onRecenter;
  final bool isEmergencyActive;
  final double height;

  const InteractiveMedicalMap({
    super.key,
    required this.facilities,
    this.selectedFacility,
    this.centerLat,
    this.centerLng,
    this.userLat,
    this.userLng,
    this.onFacilitySelected,
    this.onDirectionsTap,
    this.onRecenter,
    this.isEmergencyActive = false,
    this.height = 280,
  });

  @override
  State<InteractiveMedicalMap> createState() => _InteractiveMedicalMapState();
}

class _InteractiveMedicalMapState extends State<InteractiveMedicalMap>
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
  void didUpdateWidget(covariant InteractiveMedicalMap oldWidget) {
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
    } else if (widget.selectedFacility != null &&
        widget.selectedFacility?.id != oldWidget.selectedFacility?.id) {
      final sel = widget.selectedFacility!;
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
        (widget.facilities.isNotEmpty ? widget.facilities.first.latitude : 33.6844);
    final lng = widget.centerLng ??
        widget.userLng ??
        (widget.facilities.isNotEmpty ? widget.facilities.first.longitude : 73.0479);
    _mapController.move(LatLng(lat, lng), 13.0);
    widget.onRecenter?.call();
  }

  Future<void> _launchDirections(MedicalFacility facility) async {
    try {
      double originLat;
      double originLon;
      if (widget.userLat != null && widget.userLng != null) {
        originLat = widget.userLat!;
        originLon = widget.userLng!;
      } else {
        final gps = await HotelLocationService.getCurrentLocation();
        originLat = gps.latitude;
        originLon = gps.longitude;
      }

      final urlStr =
          'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLon&destination=${facility.latitude},${facility.longitude}&travelmode=driving';
      final uri = Uri.parse(urlStr);

      debugPrint('\n========== HELP NAVIGATION DEBUG ==========');
      debugPrint('Origin GPS: $originLat, $originLon');
      debugPrint('Destination: ${facility.name} (${facility.latitude}, ${facility.longitude})');
      debugPrint('Directions URL: $urlStr');
      debugPrint('============================================\n');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[HelpMap] Error launching directions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchLat = widget.centerLat ??
        widget.userLat ??
        (widget.facilities.isNotEmpty ? widget.facilities.first.latitude : 33.6844);
    final searchLng = widget.centerLng ??
        widget.userLng ??
        (widget.facilities.isNotEmpty ? widget.facilities.first.longitude : 73.0479);
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
          color: widget.isEmergencyActive
              ? const Color(0xFFE53935).withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
          width: widget.isEmergencyActive ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isEmergencyActive
                ? const Color(0xFFE53935).withValues(alpha: 0.25)
                : AppTheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
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

                    // Facility Markers at Exact Coordinates
                    ...widget.facilities.map((fac) {
                      final isSelected = widget.selectedFacility?.id == fac.id;
                      return Marker(
                        point: LatLng(fac.latitude, fac.longitude),
                        width: 76,
                        height: 56,
                        alignment: Alignment.center,
                        child: _FacilityRealMapMarker(
                          facility: fac,
                          isSelected: isSelected,
                          onTap: () {
                            _mapController.move(LatLng(fac.latitude, fac.longitude), 14.5);
                            widget.onFacilitySelected?.call(fac);
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
                        decoration: BoxDecoration(
                          color: widget.isEmergencyActive ? const Color(0xFFE53935) : AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${widget.facilities.length} Facilities • 30 km radius',
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

            // ── 5. Selected Facility Quick Card Preview ──
            if (widget.selectedFacility != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _FacilityQuickPreviewCard(
                  facility: widget.selectedFacility!,
                  isDark: isDark,
                  onClose: () => widget.onFacilitySelected?.call(widget.facilities.first),
                  onDirections: () {
                    widget.onDirectionsTap?.call(widget.selectedFacility!);
                    _launchDirections(widget.selectedFacility!);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Facility Marker on real map with icon, emergency indicator, and tap handler
class _FacilityRealMapMarker extends StatelessWidget {
  final MedicalFacility facility;
  final bool isSelected;
  final VoidCallback onTap;

  const _FacilityRealMapMarker({
    required this.facility,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmerg = facility.isEmergency;
    final pinColor = isEmerg ? const Color(0xFFE53935) : facility.type.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? pinColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : pinColor,
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
                    facility.type.icon,
                    size: 11,
                    color: isSelected ? Colors.white : pinColor,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isEmerg ? '24/7 ER' : facility.type.shortName,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF2D312E),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: const Size(8, 5),
              painter: _TrianglePainter(
                color: isSelected ? pinColor : Colors.white,
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

/// Quick preview card for selected medical facility on map
class _FacilityQuickPreviewCard extends StatelessWidget {
  final MedicalFacility facility;
  final bool isDark;
  final VoidCallback onClose;
  final VoidCallback onDirections;

  const _FacilityQuickPreviewCard({
    required this.facility,
    required this.isDark,
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
          color: facility.isEmergency
              ? const Color(0xFFE53935).withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08)),
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
          // Icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (facility.isEmergency ? const Color(0xFFE53935) : facility.type.color)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              facility.type.icon,
              color: facility.isEmergency ? const Color(0xFFE53935) : facility.type.color,
              size: 24,
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
                  facility.name,
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
                    Flexible(
                      child: Text(
                        '${facility.distance} (~${facility.estimatedTravelTime})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '•  ${facility.operatingHours}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: onVar),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  facility.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: onVar),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action buttons
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
                  backgroundColor: facility.isEmergency ? const Color(0xFFE53935) : AppTheme.primary,
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
