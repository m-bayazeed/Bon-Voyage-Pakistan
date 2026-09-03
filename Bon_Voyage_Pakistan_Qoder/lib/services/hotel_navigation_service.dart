import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hotel_model.dart';
import '../services/hotel_location_service.dart';
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
/// or in-app directions dialogs with live device GPS as origin.
class HotelNavigationService {
  /// Generate navigation intent info for a specific hotel.
  static Future<NavigationActionInfo> getNavigationInfo(Hotel hotel) async {
    final gps = await HotelLocationService.getCurrentLocation();
    final mapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=${gps.latitude},${gps.longitude}&destination=${hotel.latitude},${hotel.longitude}&travelmode=driving';

    return NavigationActionInfo(
      title: hotel.name,
      destinationAddress: hotel.address,
      destinationLat: hotel.latitude,
      destinationLng: hotel.longitude,
      googleMapsUrl: mapsUrl,
    );
  }

  /// Launch external Google Maps turn-by-turn driving navigation from current device GPS to hotel.
  static Future<void> launchGoogleMapsDirections(BuildContext context, Hotel hotel) async {
    try {
      final gps = await HotelLocationService.getCurrentLocation();
      final urlStr =
          'https://www.google.com/maps/dir/?api=1&origin=${gps.latitude},${gps.longitude}&destination=${hotel.latitude},${hotel.longitude}&travelmode=driving';
      final uri = Uri.parse(urlStr);

      debugPrint('\n========== DIRECTIONS DEBUG ==========');
      debugPrint('Current GPS: ${gps.latitude}, ${gps.longitude}');
      debugPrint('Hotel: ${hotel.name}');
      debugPrint('Destination: ${hotel.latitude}, ${hotel.longitude}');
      debugPrint('Generated Google Maps URL: $urlStr');
      debugPrint('=======================================\n');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[Directions] Error launching Google Maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to launch Google Maps: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Displays an interactive, responsive navigation and routing dialog.
  static void showNavigationModal(BuildContext context, Hotel hotel) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final navInfo = await getNavigationInfo(hotel);

    if (!context.mounted) return;

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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Directions & Route',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: onBg,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Live road distance & driving route from your GPS',
                        style: TextStyle(
                          fontSize: 12,
                          color: onVar,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Destination card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.5) : AppTheme.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: hotel.category.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hotel.badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: hotel.category.color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hotel.distance,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hotel.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: onBg,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: onVar),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotel.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: onVar),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Route details chips
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.3) : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.straighten_rounded, color: AppTheme.primary, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          'Road Distance',
                          style: TextStyle(fontSize: 10, color: onVar),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hotel.distance,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: onBg),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.3) : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: Colors.teal, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          'Driving ETA',
                          style: TextStyle(fontSize: 10, color: onVar),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hotel.estimatedTravelTime,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: onBg),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '${hotel.latitude}, ${hotel.longitude}'));
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
                      launchGoogleMapsDirections(context, hotel);
                    },
                    icon: const Icon(Icons.navigation_rounded, size: 17),
                    label: const Text(
                      'Open Google Maps',
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
