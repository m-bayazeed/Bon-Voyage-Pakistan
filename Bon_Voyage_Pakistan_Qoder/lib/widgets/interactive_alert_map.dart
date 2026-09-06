import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/travel_alert_model.dart';
import '../theme/app_theme.dart';

/// Interactive vector radar map widget displaying active hazard & alert locations.
class InteractiveAlertMap extends StatefulWidget {
  final List<TravelAlert> alerts;
  final TravelAlert? selectedAlert;
  final ValueChanged<TravelAlert?> onAlertSelected;
  final double height;

  const InteractiveAlertMap({
    super.key,
    required this.alerts,
    this.selectedAlert,
    required this.onAlertSelected,
    this.height = 230,
  });

  @override
  State<InteractiveAlertMap> createState() => _InteractiveAlertMapState();
}

class _InteractiveAlertMapState extends State<InteractiveAlertMap>
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
      duration: const Duration(milliseconds: 1800),
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
    final geoAlerts = widget.alerts.where((a) => a.hasCoordinates).toList();

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF19120E) : const Color(0xFFFAF2EC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD84315).withValues(alpha: isDark ? 0.35 : 0.25),
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
                    painter: _AlertMapPainter(
                      alerts: geoAlerts,
                      selectedAlert: widget.selectedAlert,
                      pulseValue: _pulseAnimation.value,
                      isDark: isDark,
                      zoom: _zoom,
                      panOffset: _panOffset,
                    ),
                  );
                },
              ),
            ),

            // Top Status & Hazard Count Badge
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
                        color: Color(0xFFD84315),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${geoAlerts.length} Hazard Zones on Map',
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

            // Selected Alert Quick Info Pill (Bottom Overlay)
            if (widget.selectedAlert != null)
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
                      color: widget.selectedAlert!.severity.color.withValues(alpha: 0.5),
                      width: 1.5,
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
                      // Severity Icon Box
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.selectedAlert!.severity.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.selectedAlert!.severity.icon,
                          color: widget.selectedAlert!.severity.color,
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
                              widget.selectedAlert!.title,
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
                                Text(
                                  widget.selectedAlert!.severity.displayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: widget.selectedAlert!.severity.color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '•  ${widget.selectedAlert!.location}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: onVar,
                                    ),
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
                        onTap: () => widget.onAlertSelected(null),
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
          child: Icon(icon, size: 16, color: const Color(0xFFD84315)),
        ),
      ),
    );
  }
}

/// Custom Vector Canvas Painter for hazard radar grid & alert pins.
class _AlertMapPainter extends CustomPainter {
  final List<TravelAlert> alerts;
  final TravelAlert? selectedAlert;
  final double pulseValue;
  final bool isDark;
  final double zoom;
  final Offset panOffset;

  _AlertMapPainter({
    required this.alerts,
    required this.selectedAlert,
    required this.pulseValue,
    required this.isDark,
    required this.zoom,
    required this.panOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + panOffset;

    // 1. Draw Radar Grid Lines & Hazard Rings
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFFD84315) : const Color(0xFFD84315))
          .withValues(alpha: isDark ? 0.12 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [45.0, 90.0, 140.0, 190.0];
    for (final radius in rings) {
      canvas.drawCircle(center, radius * zoom, gridPaint);
    }

    // Grid crosshairs
    final crossHairPaint = Paint()
      ..color = const Color(0xFFD84315).withValues(alpha: isDark ? 0.07 : 0.09)
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

    // 2. User Center Location (Pulsing Green Pin)
    final pulsePaint = Paint()
      ..color = AppTheme.primary.withValues(alpha: (1.0 - pulseValue) * 0.35)
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

    // 3. Render Hazard Zone Pins
    if (alerts.isEmpty) return;

    double minLat = alerts.first.latitude!;
    double maxLat = alerts.first.latitude!;
    double minLng = alerts.first.longitude!;
    double maxLng = alerts.first.longitude!;

    for (final a in alerts) {
      if (a.latitude! < minLat) minLat = a.latitude!;
      if (a.latitude! > maxLat) maxLat = a.latitude!;
      if (a.longitude! < minLng) minLng = a.longitude!;
      if (a.longitude! > maxLng) maxLng = a.longitude!;
    }

    final latSpan = (maxLat - minLat).clamp(0.01, 10.0);
    final lngSpan = (maxLng - minLng).clamp(0.01, 10.0);

    for (int i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      final isSelected = selectedAlert?.id == alert.id;
      final isCriticalOrHigh = alert.severity == AlertSeverity.critical ||
          alert.severity == AlertSeverity.high;

      final normX = ((alert.longitude! - minLng) / lngSpan - 0.5) * 2.0;
      final normY = -((alert.latitude! - minLat) / latSpan - 0.5) * 2.0;

      final angle = (i * 1.1) % (2 * math.pi);
      final radius = (38.0 + (i % 4) * 34.0) * zoom;

      final pinX = center.dx + (normX * 85 * zoom) + (math.cos(angle) * radius * 0.5);
      final pinY = center.dy + (normY * 65 * zoom) + (math.sin(angle) * radius * 0.5);
      final pinPos = Offset(pinX, pinY);

      // Warning Pulse Ring for Critical & High Hazards
      if (isCriticalOrHigh) {
        final alertPulse = Paint()
          ..color = alert.severity.color.withValues(alpha: (1.0 - pulseValue) * 0.45)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pinPos, (10 + pulseValue * 16) * zoom, alertPulse);
      }

      // Pin Connecting Line to center
      final linePaint = Paint()
        ..color = alert.severity.color.withValues(alpha: isSelected ? 0.4 : 0.15)
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawLine(center, pinPos, linePaint);

      // Pin Outer Glow if selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = alert.severity.color.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pinPos, 18 * zoom, glowPaint);
      }

      // Pin Body
      final pinBodyPaint = Paint()
        ..color = alert.severity.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pinPos, (isSelected ? 11 : 9) * zoom, pinBodyPaint);

      // Pin White Border
      final pinBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(pinPos, (isSelected ? 11 : 9) * zoom, pinBorderPaint);

      // Label on top
      if (isSelected || alerts.length <= 5) {
        final textSpan = TextSpan(
          text: alert.title.length > 14 ? '${alert.title.substring(0, 13)}…' : alert.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 9.5 * zoom,
            fontWeight: FontWeight.w800,
            backgroundColor: (isDark ? const Color(0xFF261A14) : Colors.white)
                .withValues(alpha: 0.88),
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(pinPos.dx - textPainter.width / 2, pinPos.dy - 19 * zoom),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AlertMapPainter oldDelegate) => true;
}
