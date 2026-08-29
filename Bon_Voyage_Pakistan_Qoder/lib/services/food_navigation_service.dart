import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_place_model.dart';
import '../theme/app_theme.dart';

/// Navigation action info for food locations.
class FoodNavigationInfo {
  final String title;
  final String address;
  final double latitude;
  final double longitude;
  final String mapsUrl;

  const FoodNavigationInfo({
    required this.title,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
  });
}

/// Abstracted navigation service for Food & Dining locations.
class FoodNavigationService {
  /// Generate navigation intent info for a food spot.
  static FoodNavigationInfo getNavigationInfo(FoodPlace place) {
    final encodedAddr = Uri.encodeComponent('${place.name}, ${place.address}');
    final mapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}&query=$encodedAddr';

    return FoodNavigationInfo(
      title: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
      mapsUrl: mapsUrl,
    );
  }

  /// Displays an interactive navigation modal with GPS copy and directions trigger.
  static void showNavigationModal(BuildContext context, FoodPlace place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

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
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
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
                  color: onVar.withValues(alpha: 0.3),
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
                    color: place.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    place.category.icon,
                    color: place.category.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route to ${place.name}',
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
                        '${place.distance} • ~${place.estimatedTravelTime} drive (${place.cuisine})',
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
                    ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                    : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
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
                        'RESTAURANT LOCATION',
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
                    place.address,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onBg,
                      height: 1.35,
                    ),
                  ),
                  if (place.landmarkNearby.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Landmark: ${place.landmarkNearby}',
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
                        text: '${place.latitude}, ${place.longitude}',
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Starting directions to ${place.name} (${place.distance})...',
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
                      'Start Navigation',
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
