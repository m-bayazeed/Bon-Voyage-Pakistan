import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hotel_model.dart';
import '../theme/app_theme.dart';

/// Navigation intent result representation.
class NavigationActionInfo {
  final String title;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String googleMapsUrl;

  const NavigationActionInfo({
    required this.title,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.googleMapsUrl,
  });
}

/// Abstracted navigation service for launching directions, deep links,
/// or in-app directions dialogs without coupling UI to external packages.
class HotelNavigationService {
  /// Generate navigation intent info for a specific hotel.
  static NavigationActionInfo getNavigationInfo(Hotel hotel) {
    final encodedAddr = Uri.encodeComponent('${hotel.name}, ${hotel.address}');
    final mapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${hotel.latitude},${hotel.longitude}&query=$encodedAddr';

    return NavigationActionInfo(
      title: hotel.name,
      destinationAddress: hotel.address,
      destinationLat: hotel.latitude,
      destinationLng: hotel.longitude,
      googleMapsUrl: mapsUrl,
    );
  }

  /// Displays an interactive, responsive navigation and routing dialog.
  static void showNavigationModal(BuildContext context, Hotel hotel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final navInfo = getNavigationInfo(hotel);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppTheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: onVar.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route to ${hotel.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: onBg,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${hotel.distance} • ~${hotel.estimatedTravelTime} drive via main highway',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Address card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceVariant.withOpacity(0.4)
                    : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'DESTINATION ADDRESS',
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
                    hotel.address,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onBg,
                      height: 1.35,
                    ),
                  ),
                  if (hotel.landmarkNearby.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Landmark: ${hotel.landmarkNearby}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: onVar,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: '${hotel.latitude}, ${hotel.longitude}',
                      ));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                              SizedBox(width: 8),
                              Text('GPS Coordinates copied to clipboard'),
                            ],
                          ),
                          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy GPS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onBg,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Launching navigation to ${hotel.name} (${hotel.distance})...',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 17),
                    label: const Text(
                      'Start Turn-by-Turn',
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
    );
  }
}
