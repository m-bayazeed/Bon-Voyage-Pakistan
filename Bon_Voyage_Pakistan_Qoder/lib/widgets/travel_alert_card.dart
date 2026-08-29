import 'package:flutter/material.dart';
import '../models/travel_alert_model.dart';
import '../theme/app_theme.dart';

/// Responsive card displaying a travel notification or emergency advisory.
class TravelAlertCard extends StatelessWidget {
  final TravelAlert alert;
  final VoidCallback onTap;
  final bool isSelected;

  const TravelAlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: alert.severity.color.withValues(alpha: isDark ? 0.45 : 0.38),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: alert.severity.color.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row (Severity Badge, Category Icon, Unread Dot, Time)
                Row(
                  children: [
                    // Severity Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: alert.severity.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(alert.severity.icon, size: 11, color: alert.severity.color),
                          const SizedBox(width: 4),
                          Text(
                            alert.severity.displayName.toUpperCase(),
                            style: TextStyle(
                              color: alert.severity.color,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Category Tag
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: alert.type.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          alert.type.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: alert.type.color,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Unread Indicator Dot
                    if (!alert.isRead) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],

                    // Time Ago
                    Text(
                      alert.timeAgo,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: onVar,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 5),

                // Description Snippet
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: onVar,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // Location & Source Footer
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Details ›',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
