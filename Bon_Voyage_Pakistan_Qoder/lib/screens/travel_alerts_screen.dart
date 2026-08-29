import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/travel_alert_model.dart';
import '../services/travel_alert_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/travel_alert_card.dart';

/// Travel Notifications & Emergency Alerts Screen for Bon Voyage Pakistan.
class TravelAlertsScreen extends StatefulWidget {
  final String? initialCity;

  const TravelAlertsScreen({super.key, this.initialCity});

  @override
  State<TravelAlertsScreen> createState() => _TravelAlertsScreenState();
}

class _TravelAlertsScreenState extends State<TravelAlertsScreen> {
  // Search & Filter State
  String _selectedCity = 'All Pakistan';
  bool _useCurrentLocation = false;
  AlertCategory _selectedCategory = AlertCategory.all;
  AlertSeverity? _selectedSeverity;

  // Data State
  List<TravelAlert> _alerts = [];
  TravelAlert? _selectedAlert;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCity != null) {
      _selectedCity = widget.initialCity!;
    }
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await TravelAlertService.getAlerts(
        city: _selectedCity,
        useCurrentLocation: _useCurrentLocation,
        category: _selectedCategory,
        severity: _selectedSeverity,
      );

      if (mounted) {
        setState(() {
          _alerts = results;
          _isLoading = false;
          _selectedAlert = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to fetch travel advisories. Please check your network.';
        });
      }
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    await TravelAlertService.markAllAsRead(_alerts);
    _loadAlerts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.done_all_rounded, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text('All travel alerts marked as read'),
            ],
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkSurface
              : AppTheme.lightSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ──────────────────────────────────────────
  // Location Selector Dialog
  // ──────────────────────────────────────────

  void _showLocationSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final cities = TravelAlertService.getSupportedCities();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Text(
              'Select Alert Region',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 14),

            // Use Current Location (GPS) Option
            Material(
              color: _useCurrentLocation
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : isDark
                      ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                      : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _useCurrentLocation = true;
                    _selectedCity = 'Current Location (GPS)';
                  });
                  _loadAlerts();
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Device Location (GPS)',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Filter road blocks and weather hazards near you',
                              style: TextStyle(fontSize: 11.5, color: onVar),
                            ),
                          ],
                        ),
                      ),
                      if (_useCurrentLocation)
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Supported Cities Header
            Text(
              'OR SELECT BY PROVINCE / CORRIDOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: onVar,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Cities List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: cities.length,
                itemBuilder: (_, i) {
                  final city = cities[i];
                  final isSelected = !_useCurrentLocation && _selectedCity == city;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: Icon(
                        city == 'All Pakistan'
                            ? Icons.public_rounded
                            : Icons.location_on_rounded,
                        color: isSelected ? AppTheme.primary : onVar,
                        size: 20,
                      ),
                      title: Text(
                        city,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppTheme.primary : onSurface,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: AppTheme.primary, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _useCurrentLocation = false;
                          _selectedCity = city;
                        });
                        _loadAlerts();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Alert Detail Modal Sheet
  // ──────────────────────────────────────────

  void _showAlertDetailSheet(TravelAlert alert) {
    // Automatically mark as read
    TravelAlertService.markAsRead(alert.id);
    _loadAlerts();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final onSurface = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(
              color: alert.severity.color.withValues(alpha: 0.4),
              width: 2.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
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

            // Top Badges Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: alert.severity.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(alert.severity.icon, size: 14, color: alert.severity.color),
                      const SizedBox(width: 5),
                      Text(
                        alert.severity.displayName.toUpperCase(),
                        style: TextStyle(
                          color: alert.severity.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: alert.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    alert.type.displayName,
                    style: TextStyle(
                      color: alert.type.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  alert.timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onVar,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              alert.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Affected Location Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurfaceVariant.withValues(alpha: 0.4)
                    : AppTheme.lightSurfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AFFECTED ROUTE / LOCATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: onVar,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.location,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Description
            Text(
              'Advisory Summary',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              alert.description,
              style: TextStyle(
                fontSize: 13,
                color: onVar,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            // Recommended Action Box
            if (alert.recommendedAction != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alert.severity == AlertSeverity.critical
                      ? Colors.red.withValues(alpha: 0.12)
                      : AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: alert.severity == AlertSeverity.critical
                        ? Colors.red.withValues(alpha: 0.3)
                        : AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: alert.severity == AlertSeverity.critical
                              ? Colors.red
                              : AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RECOMMENDED TRAVEL ACTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: alert.severity == AlertSeverity.critical
                                ? Colors.red
                                : AppTheme.primary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.recommendedAction!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Source Agency Tag
            Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Issued by: ${alert.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onVar,
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
                      Clipboard.setData(ClipboardData(
                        text: '⚠️ TRAVEL ALERT: ${alert.title}\n📍 ${alert.location}\n📝 ${alert.description}\n🛡️ Action: ${alert.recommendedAction ?? "Take caution"}\n- Source: ${alert.source}',
                      ));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.copy_rounded, color: AppTheme.primary, size: 18),
                              SizedBox(width: 8),
                              Text('Advisory copied to clipboard'),
                            ],
                          ),
                          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text('Share / Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Understood',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tp = ThemeProviderScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onSurface = onBg;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final surface = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    final criticalCount = _alerts.where((a) => a.severity == AlertSeverity.critical).length;
    final highCount = _alerts.where((a) => a.severity == AlertSeverity.high).length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar & Location Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      Material(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onBg),
                          ),
                        ),
                      ),

                      // City / Region Selector Pill
                      Material(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _showLocationSelector,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _useCurrentLocation
                                    ? Colors.green.withValues(alpha: 0.6)
                                    : AppTheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _useCurrentLocation ? Icons.my_location_rounded : Icons.location_on_rounded,
                                  size: 16,
                                  color: _useCurrentLocation ? Colors.green : AppTheme.primary,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    _useCurrentLocation ? 'Current Location (GPS)' : _selectedCity,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: _useCurrentLocation
                                          ? (isDark ? Colors.greenAccent : Colors.green[800])
                                          : onBg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: onVar),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Theme Toggle
                      ThemeToggle(isDark: tp.isDark, onToggle: () => tp.toggleTheme()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Travel Alerts',
                    style: TextStyle(
                      color: onBg,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"Stay updated with live NDMA, PMD weather warnings & Motorway road conditions."',
                    style: TextStyle(
                      color: onVar,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Alert Statistics & Mark as Read Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  // Total Count Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications_rounded, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${_alerts.length} Total',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: onBg),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Critical Count Chip
                  if (criticalCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dangerous_rounded, size: 13, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '$criticalCount Critical',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // High Count Chip
                  if (highCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_rounded, size: 13, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '$highCount High',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),

                  // Mark All As Read Button
                  if (_alerts.any((a) => !a.isRead))
                    GestureDetector(
                      onTap: _handleMarkAllAsRead,
                      child: const Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 14, color: AppTheme.primary),
                          SizedBox(width: 4),
                          Text(
                            'Mark all read',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 3. Category Dropdown Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AlertCategory>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: surface,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: onVar, size: 20),
                    items: AlertCategory.values.map((cat) {
                      return DropdownMenuItem<AlertCategory>(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: onBg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newCat) {
                      if (newCat != null && newCat != _selectedCategory) {
                        setState(() => _selectedCategory = newCat);
                        _loadAlerts();
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 4. Main Feed (Alert Cards)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                          SizedBox(height: 14),
                          Text(
                            'Fetching live travel advisories...',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, color: onVar),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadAlerts,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: AppTheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _alerts.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 48,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'All Routes Clear',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'No active weather warnings or road blocks reported for $_selectedCity in ${_selectedCategory.displayName}.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: onVar),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategory = AlertCategory.all;
                                          _selectedCity = 'All Pakistan';
                                        });
                                        _loadAlerts();
                                      },
                                      child: const Text('View All National Alerts'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              physics: const BouncingScrollPhysics(),
                              children: [

                                // Feed Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Active Bulletins (${_alerts.length})',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: onBg,
                                      ),
                                    ),
                                    Text(
                                      'Live NDMA / PMD Feed',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: onVar,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Alert Cards
                                ..._alerts.map((alert) {
                                  final isSelected = _selectedAlert?.id == alert.id;
                                  return TravelAlertCard(
                                    alert: alert,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() => _selectedAlert = alert);
                                      _showAlertDetailSheet(alert);
                                    },
                                  );
                                }),
                                const SizedBox(height: 24),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
