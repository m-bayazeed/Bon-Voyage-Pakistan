import 'dart:math';
import 'package:flutter/material.dart';
import '../models/medical_facility_model.dart';
import '../theme/app_theme.dart';

/// Interactive medical map widget displaying user location, facility markers,
/// zoom/re-center controls, and a selected facility preview card.
/// Designed for drop-in replacement with Google Maps / Mapbox in the future.
class InteractiveMedicalMap extends StatefulWidget {
  final List<MedicalFacility> facilities;
  final MedicalFacility? selectedFacility;
  final ValueChanged<MedicalFacility>? onFacilitySelected;
  final VoidCallback? onRecenter;
  final bool isEmergencyActive;
  final double height;

  const InteractiveMedicalMap({
    super.key,
    required this.facilities,
    this.selectedFacility,
    this.onFacilitySelected,
    this.onRecenter,
    this.isEmergencyActive = false,
    this.height = 280,
  });

  @override
  State<InteractiveMedicalMap> createState() => _InteractiveMedicalMapState();
}

class _InteractiveMedicalMapState extends State<InteractiveMedicalMap>
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
          color: widget.isEmergencyActive
              ? Colors.redAccent.withOpacity(0.4)
              : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
          width: widget.isEmergencyActive ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isEmergencyActive
                ? Colors.redAccent.withOpacity(0.15)
                : AppTheme.primary.withOpacity(isDark ? 0.12 : 0.06),
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
                    painter: _VectorMapPainter(
                      isDark: isDark,
                      isEmergency: widget.isEmergencyActive,
                    ),
                  ),
                ),
              ),
            ),

            // ── Facility Markers Layer ──
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final center = Offset(
                    constraints.maxWidth / 2 + _panOffset.dx,
                    constraints.maxHeight / 2 + _panOffset.dy,
                  );

                  return Stack(
                    children: [
                      // User's Current GPS Location Pin
                      Positioned(
                        left: center.dx - 20,
                        top: center.dy - 20,
                        child: _UserLocationPin(
                          pulseAnimation: _pulseAnimation,
                          isEmergency: widget.isEmergencyActive,
                        ),
                      ),

                      // Nearby Facilities Pins
                      ..._buildFacilityPins(center, constraints),
                    ],
                  );
                },
              ),
            ),

            // ── Top Gradient Overlay (Map Tag & GPS Accuracy) ──
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.greenAccent,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Live Medical Radar • GPS High Accuracy',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Emergency status badge
                  if (widget.isEmergencyActive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, color: Colors.white, size: 11),
                          SizedBox(width: 3),
                          Text(
                            'SOS MODE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Right Side Map Controls (Zoom +, Zoom -, Re-center) ──
            Positioned(
              right: 12,
              bottom: widget.selectedFacility != null ? 80 : 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapControlBtn(
                    icon: Icons.add_rounded,
                    onTap: _zoomIn,
                    tooltip: 'Zoom In',
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.remove_rounded,
                    onTap: _zoomOut,
                    tooltip: 'Zoom Out',
                  ),
                  const SizedBox(height: 6),
                  _MapControlBtn(
                    icon: Icons.my_location_rounded,
                    onTap: _recenter,
                    tooltip: 'Re-center GPS',
                    highlight: true,
                  ),
                ],
              ),
            ),

            // ── Bottom Floating Facility Quick Card ──
            if (widget.selectedFacility != null)
              Positioned(
                left: 12,
                right: 58,
                bottom: 12,
                child: _SelectedFacilityQuickCard(
                  facility: widget.selectedFacility!,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFacilityPins(Offset center, BoxConstraints constraints) {
    // Generate deterministic relative coordinates around user center for demonstration
    final List<Widget> pinWidgets = [];

    for (int i = 0; i < widget.facilities.length; i++) {
      final facility = widget.facilities[i];
      final isSelected = widget.selectedFacility?.id == facility.id;

      // Deterministic radial offset based on index
      final angle = (i * (2 * pi / max(widget.facilities.length, 1))) + 0.35;
      final distanceRadius = 55.0 + (i % 3) * 35.0;

      final pinDx = center.dx + cos(angle) * distanceRadius * _zoomLevel;
      final pinDy = center.dy + sin(angle) * distanceRadius * _zoomLevel;

      // Only render pins inside reasonable viewport bounds
      if (pinDx < -40 || pinDx > constraints.maxWidth + 40 || pinDy < -40 || pinDy > constraints.maxHeight + 40) {
        continue;
      }

      pinWidgets.add(
        Positioned(
          left: pinDx - 16,
          top: pinDy - 32,
          child: GestureDetector(
            onTap: () {
              widget.onFacilitySelected?.call(facility);
            },
            child: _FacilityPin(
              facility: facility,
              isSelected: isSelected,
            ),
          ),
        ),
      );
    }

    return pinWidgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USER LOCATION GPS PIN WITH PULSING RADAR
// ─────────────────────────────────────────────────────────────────────────────
class _UserLocationPin extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final bool isEmergency;

  const _UserLocationPin({
    required this.pulseAnimation,
    this.isEmergency = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isEmergency ? Colors.redAccent : AppTheme.primary;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar pulse outer ring
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
                    color: color.withOpacity(0.22),
                    border: Border.all(
                      color: color.withOpacity(0.45),
                      width: 1.2,
                    ),
                  ),
                ),
              );
            },
          ),
          // User core dot
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
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
// FACILITY MARKER PIN
// ─────────────────────────────────────────────────────────────────────────────
class _FacilityPin extends StatelessWidget {
  final MedicalFacility facility;
  final bool isSelected;

  const _FacilityPin({
    required this.facility,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pinColor = facility.isEmergency
        ? const Color(0xFFD32F2F)
        : facility.type.color;

    return AnimatedScale(
      scale: isSelected ? 1.25 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : pinColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? pinColor : Colors.white,
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? pinColor : Colors.black).withOpacity(0.35),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              facility.type.icon,
              size: 14,
              color: isSelected ? pinColor : Colors.white,
            ),
          ),
          // Pin pointer tip
          CustomPaint(
            size: const Size(8, 5),
            painter: _PinTipPainter(color: isSelected ? Colors.white : pinColor),
          ),
        ],
      ),
    );
  }
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  _PinTipPainter({required this.color});

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
  bool shouldRepaint(covariant _PinTipPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTED FACILITY QUICK CARD ON MAP
// ─────────────────────────────────────────────────────────────────────────────
class _SelectedFacilityQuickCard extends StatelessWidget {
  final MedicalFacility facility;

  const _SelectedFacilityQuickCard({required this.facility});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E2422) : Colors.white).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: facility.isEmergency
              ? Colors.redAccent.withOpacity(0.5)
              : AppTheme.primary.withOpacity(0.3),
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
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (facility.isEmergency ? Colors.redAccent : AppTheme.primary)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              facility.type.icon,
              color: facility.isEmergency ? Colors.redAccent : AppTheme.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${facility.distance} • ${facility.estimatedTravelTime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (facility.isEmergency) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          '24/7 ER',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
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
// MAP CONTROL BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _MapControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool highlight;

  const _MapControlBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: highlight
              ? AppTheme.primary
              : (isDark ? const Color(0xFF222826) : Colors.white).withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: highlight
              ? AppTheme.onPrimary
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VECTOR MAP PAINTER (ROADS, GREENERY, RIVER, TOPOGRAPHY)
// ─────────────────────────────────────────────────────────────────────────────
class _VectorMapPainter extends CustomPainter {
  final bool isDark;
  final bool isEmergency;

  _VectorMapPainter({required this.isDark, required this.isEmergency});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background Grid & Terrain
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF141918) : const Color(0xFFF0F4F1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Green Park Spaces
    final parkPaint = Paint()
      ..color = (isDark ? const Color(0xFF1C271E) : const Color(0xFFD8E8D5)).withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final parkPath1 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.12, size.width * 0.28, size.height * 0.35),
        const Radius.circular(18),
      ));
    canvas.drawPath(parkPath1, parkPaint);

    final parkPath2 = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.52, size.width * 0.30, size.height * 0.38),
        const Radius.circular(22),
      ));
    canvas.drawPath(parkPath2, parkPaint);

    // 3. Water Body / Blue River Stream
    final waterPaint = Paint()
      ..color = isDark ? const Color(0xFF13222B) : const Color(0xFFCDE2ED)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.85,
        size.width * 0.6,
        size.height * 0.68,
        size.width,
        size.height * 0.82,
      );
    canvas.drawPath(riverPath, waterPaint);

    // 4. Secondary Roads Grid
    final secRoadPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (double x = 40; x < size.width; x += 60) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secRoadPaint);
    }
    for (double y = 40; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secRoadPaint);
    }

    // 5. Main Highways / Primary Arterials
    final mainRoadPaint = Paint()
      ..color = isDark ? const Color(0xFF26332B) : const Color(0xFFFFFFFF)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Diagonal Highway 1
    final road1 = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(size.width * 0.4, size.height * 0.38, size.width * 0.55, size.height * 0.55, size.width, size.height * 0.45);
    canvas.drawPath(road1, mainRoadPaint);

    // Main Avenue 2
    final road2 = Path()
      ..moveTo(size.width * 0.48, 0)
      ..lineTo(size.width * 0.48, size.height);
    canvas.drawPath(road2, mainRoadPaint);
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter old) =>
      old.isDark != isDark || old.isEmergency != isEmergency;
}
