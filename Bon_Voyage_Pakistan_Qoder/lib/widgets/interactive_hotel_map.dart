import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hotel_model.dart';
import '../theme/app_theme.dart';

/// Interactive vector map widget displaying user location, hotel pins with prices,
/// zoom/re-center controls, and a selected hotel preview quick card.
/// Designed for easy drop-in replacement with Google Maps / Mapbox in the future.
class InteractiveHotelMap extends StatefulWidget {
  final List<Hotel> hotels;
  final Hotel? selectedHotel;
  final ValueChanged<Hotel>? onHotelSelected;
  final VoidCallback? onRecenter;
  final double height;

  const InteractiveHotelMap({
    super.key,
    required this.hotels,
    this.selectedHotel,
    this.onHotelSelected,
    this.onRecenter,
    this.height = 290,
  });

  @override
  State<InteractiveHotelMap> createState() => _InteractiveHotelMapState();
}

class _InteractiveHotelMapState extends State<InteractiveHotelMap>
    with SingleTickerProviderStateMixin {
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = min(_zoomLevel + 0.25, 2.5);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = max(_zoomLevel - 0.25, 0.75);
    });
  }

  void _recenter() {
    setState(() {
      _panOffset = Offset.zero;
      _zoomLevel = 1.0;
    });
    widget.onRecenter?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            // ── Interactive Map Canvas ──
            GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _panOffset += details.delta;
                });
              },
              child: Transform.translate(
                offset: _panOffset,
                child: Transform.scale(
                  scale: _zoomLevel,
                  child: CustomPaint(
                    size: Size(double.infinity, widget.height),
                    painter: _HotelVectorMapPainter(isDark: isDark),
                  ),
                ),
              ),
            ),

            // ── Hotel Markers Layer ──
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final center = Offset(
                    constraints.maxWidth / 2 + _panOffset.dx,
                    constraints.maxHeight / 2 + _panOffset.dy,
                  );

                  return Stack(
                    children: [
                      // User GPS Location Pin
                      Positioned(
                        left: center.dx - 20,
                        top: center.dy - 20,
                        child: _UserLocationPin(pulseAnimation: _pulseAnimation),
                      ),

                      // Nearby Hotels Pins
                      ...widget.hotels.take(8).map((hotel) {
                        final index = widget.hotels.indexOf(hotel);
                        final markerOffset = _calculateMarkerOffset(
                          index: index,
                          total: min(widget.hotels.length, 8),
                          center: center,
                          zoom: _zoomLevel,
                        );

                        final isSelected = widget.selectedHotel?.id == hotel.id;

                        return Positioned(
                          left: markerOffset.dx - 24,
                          top: markerOffset.dy - 24,
                          child: _HotelMapMarker(
                            hotel: hotel,
                            isSelected: isSelected,
                            onTap: () => widget.onHotelSelected?.call(hotel),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),

            // ── Top Left Live Radar / Filter Badge ──
            Positioned(
              top: 14,
              left: 14,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkSurface : Colors.white)
                      .withOpacity(0.92),
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

            // ── Top Right Controls: Zoom & Recenter ──
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
                    highlight: true,
                  ),
                ],
              ),
            ),

            // ── Bottom Active Hotel Quick Preview Card ──
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

  Offset _calculateMarkerOffset({
    required int index,
    required int total,
    required Offset center,
    required double zoom,
  }) {
    if (total == 0) return center;
    final angle = (2 * pi * index) / total + (pi / 6);
    final distance = (60.0 + (index % 3) * 35.0) * zoom;
    return Offset(
      center.dx + distance * cos(angle),
      center.dy + distance * sin(angle) * 0.75,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER LOCATION PIN WITH RADAR PULSE
// ─────────────────────────────────────────────────────────────────────────────
class _UserLocationPin extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _UserLocationPin({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
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
// HOTEL MAP MARKER PIN WITH PRICE BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _HotelMapMarker extends StatelessWidget {
  final Hotel hotel;
  final bool isSelected;
  final VoidCallback onTap;

  const _HotelMapMarker({
    required this.hotel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = hotel.category.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price pill badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : catColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'PKR ${(hotel.pricePerNightPkr / 1000).toStringAsFixed(0)}k',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Marker Icon Circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : catColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.white,
                  width: isSelected ? 2.5 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSelected ? AppTheme.primary : catColor).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                hotel.category.icon,
                size: 16,
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
// SELECTED HOTEL QUICK PREVIEW CARD OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class _SelectedHotelQuickCard extends StatelessWidget {
  final Hotel hotel;
  final VoidCallback onTap;

  const _SelectedHotelQuickCard({required this.hotel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        '${hotel.rating} (${hotel.reviewCount})',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• ${hotel.distance}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Price badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hotel.formattedPrice.replaceAll(' / night', ''),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
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
// MAP CONTROL BUTTON (ZOOM / RECENTER)
// ─────────────────────────────────────────────────────────────────────────────
class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool highlight;

  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VECTOR MAP CANVAS PAINTER (PAKISTAN TOPOGRAPHY & ROADS)
// ─────────────────────────────────────────────────────────────────────────────
class _HotelVectorMapPainter extends CustomPainter {
  final bool isDark;

  _HotelVectorMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF141918) : const Color(0xFFE9EEEA);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF232C2A) : const Color(0xFFD6DDD8)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final highwayPaint = Paint()
      ..color = isDark ? const Color(0xFF2F3B38) : const Color(0xFFC7D3CB)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final riverPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1B3834).withOpacity(0.6)
          : const Color(0xFFBFE0DA).withOpacity(0.8)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke;

    // Scenic river / lake path
    final riverPath = Path();
    riverPath.moveTo(0, size.height * 0.2);
    riverPath.cubicTo(
      size.width * 0.35,
      size.height * 0.3,
      size.width * 0.6,
      size.height * 0.7,
      size.width,
      size.height * 0.85,
    );
    canvas.drawPath(riverPath, riverPaint);

    // Highway (KKH / Motorway representation)
    final highwayPath = Path();
    highwayPath.moveTo(size.width * 0.1, 0);
    highwayPath.cubicTo(
      size.width * 0.4,
      size.height * 0.35,
      size.width * 0.55,
      size.height * 0.65,
      size.width * 0.9,
      size.height,
    );
    canvas.drawPath(highwayPath, highwayPaint);

    // Secondary city roads
    final r1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.45);
    final r2 = Path()
      ..moveTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.25, size.height);
    canvas.drawPath(r1, roadPaint);
    canvas.drawPath(r2, roadPaint);

    // Radar distance concentric rings
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 50, ringPaint);
    canvas.drawCircle(center, 100, ringPaint);
    canvas.drawCircle(center, 150, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _HotelVectorMapPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
