import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/food_place_model.dart';
import '../theme/app_theme.dart';

/// Interactive vector radar map widget for Food & Dining locations.
class InteractiveFoodMap extends StatefulWidget {
  final List<FoodPlace> places;
  final FoodPlace? selectedPlace;
  final ValueChanged<FoodPlace?> onPlaceSelected;
  final VoidCallback? onDirectionsTap;
  final double height;

  const InteractiveFoodMap({
    super.key,
    required this.places,
    this.selectedPlace,
    required this.onPlaceSelected,
    this.onDirectionsTap,
    this.height = 240,
  });

  @override
  State<InteractiveFoodMap> createState() => _InteractiveFoodMapState();
}

class _InteractiveFoodMapState extends State<InteractiveFoodMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double _zoom = 1.0;
  Offset _panOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _reCenter() {
    setState(() {
      _zoom = 1.0;
      _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13190E) : const Color(0xFFEFF5E6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Gesture Detector for Pan & Zoom
            GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _zoom = (_zoom * details.scale).clamp(0.7, 2.5);
                  _panOffset += details.focalPointDelta;
                });
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(double.infinity, widget.height),
                    painter: _FoodMapPainter(
                      places: widget.places,
                      selectedPlace: widget.selectedPlace,
                      pulseValue: _pulseAnimation.value,
                      isDark: isDark,
                      zoom: _zoom,
                      panOffset: _panOffset,
                    ),
                  );
                },
              ),
            ),

            // Top Status & Places Count Badge
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface.withValues(alpha: 0.9)
                      : AppTheme.lightSurface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.places.length} Food Spots on Map',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Map Controls (Zoom In, Zoom Out, Reset)
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _buildControlBtn(
                    icon: Icons.add_rounded,
                    onTap: () => setState(() => _zoom = (_zoom + 0.25).clamp(0.7, 2.5)),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildControlBtn(
                    icon: Icons.remove_rounded,
                    onTap: () => setState(() => _zoom = (_zoom - 0.25).clamp(0.7, 2.5)),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 6),
                  _buildControlBtn(
                    icon: Icons.my_location_rounded,
                    onTap: _reCenter,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Selected Food Place Quick Info Pill (Bottom Overlay)
            if (widget.selectedPlace != null)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Category Icon Box
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.selectedPlace!.category.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.selectedPlace!.category.icon,
                          color: widget.selectedPlace!.category.color,
                          size: 18,
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
                              widget.selectedPlace!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 13),
                                const SizedBox(width: 2),
                                Text(
                                  widget.selectedPlace!.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•  ${widget.selectedPlace!.distance}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•  ${widget.selectedPlace!.formattedCost}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    color: onVar,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close Preview
                      GestureDetector(
                        onTap: () => widget.onPlaceSelected(null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: onVar.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 14, color: onVar),
                        ),
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

  Widget _buildControlBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark
          ? AppTheme.darkSurface.withValues(alpha: 0.9)
          : AppTheme.lightSurface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
      ),
    );
  }
}

/// Custom Vector Canvas Painter for rendering topographic radar grid and food place pins.
class _FoodMapPainter extends CustomPainter {
  final List<FoodPlace> places;
  final FoodPlace? selectedPlace;
  final double pulseValue;
  final bool isDark;
  final double zoom;
  final Offset panOffset;

  _FoodMapPainter({
    required this.places,
    required this.selectedPlace,
    required this.pulseValue,
    required this.isDark,
    required this.zoom,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;

    // 1. Draw Radar Grid Lines & Concentric Distance Rings
    final gridPaint = Paint()
      ..color = isDark
          ? const Color(0xFF5A7328).withValues(alpha: 0.12)
          : const Color(0xFF5A7328).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [45.0, 90.0, 140.0, 190.0];
    for (final radius in rings) {
      canvas.drawCircle(center, radius * zoom, gridPaint);
    }

    // Grid crosshairs
    final crossHairPaint = Paint()
      ..color = isDark
          ? const Color(0xFF5A7328).withValues(alpha: 0.08)
          : const Color(0xFF5A7328).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx - 220 * zoom, center.dy),
      Offset(center.dx + 220 * zoom, center.dy),
      crossHairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 180 * zoom),
      Offset(center.dx, center.dy + 180 * zoom),
      crossHairPaint,
    );

    // 2. User Center Location (Pulsing GPS Pin)
    final pulsePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: (1.0 - pulseValue) * 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, (12 + pulseValue * 22) * zoom, pulsePaint);

    final userPinPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7 * zoom, userPinPaint);

    final userPinCore = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3 * zoom, userPinCore);

    // 3. Render Food Place Marker Pins
    if (places.isEmpty) return;

    // Find coordinate bounds to project pins relative to center
    double minLat = places.first.latitude;
    double maxLat = places.first.latitude;
    double minLng = places.first.longitude;
    double maxLng = places.first.longitude;

    for (final p in places) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latSpan = (maxLat - minLat).clamp(0.01, 10.0);
    final lngSpan = (maxLng - minLng).clamp(0.01, 10.0);

    for (int i = 0; i < places.length; i++) {
      final place = places[i];
      final isSelected = selectedPlace?.id == place.id;

      // Calculate radial pseudo-offset for pleasant scattering around user
      final normX = ((place.longitude - minLng) / lngSpan - 0.5) * 2.0;
      final normY = -((place.latitude - minLat) / latSpan - 0.5) * 2.0;

      final angle = (i * 0.95) % (2 * math.pi);
      final radius = (38.0 + (i % 4) * 36.0) * zoom;

      final pinX = center.dx + (normX * 85 * zoom) + (math.cos(angle) * radius * 0.5);
      final pinY = center.dy + (normY * 65 * zoom) + (math.sin(angle) * radius * 0.5);
      final pinPos = Offset(pinX, pinY);

      // Pin connecting line to center
      final linePaint = Paint()
        ..color = (isSelected ? AppTheme.primary : place.category.color)
            .withValues(alpha: isSelected ? 0.35 : 0.12)
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawLine(center, pinPos, linePaint);

      // Pin Outer Glow if selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = AppTheme.primary.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pinPos, 18 * zoom, glowPaint);
      }

      // Pin Body
      final pinBodyPaint = Paint()
        ..color = isSelected ? AppTheme.primary : place.category.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinPos, (isSelected ? 12 : 9) * zoom, pinBodyPaint);

      // Pin White Border
      final pinBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pinPos, (isSelected ? 12 : 9) * zoom, pinBorderPaint);

      // Rating / Price label on top of selected pin
      if (isSelected || places.length <= 6) {
        final textSpan = TextSpan(
          text: place.name.length > 12 ? '${place.name.substring(0, 11)}…' : place.name,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 10 * zoom,
            fontWeight: FontWeight.w700,
            backgroundColor: (isDark ? const Color(0xFF1E2816) : Colors.white)
                .withValues(alpha: 0.85),
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(pinPos.dx - textPainter.width / 2, pinPos.dy - 20 * zoom),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FoodMapPainter oldDelegate) => true;
}
