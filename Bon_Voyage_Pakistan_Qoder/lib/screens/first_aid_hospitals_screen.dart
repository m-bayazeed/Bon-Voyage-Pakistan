import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medical_facility_model.dart';
import '../services/medical_assistance_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/interactive_medical_map.dart';
import '../widgets/theme_toggle.dart';

/// Comprehensive First Aid, Hospitals & Emergency Medical Assistance Screen.
class FirstAidHospitalsScreen extends StatefulWidget {
  final FacilityType? initialType;
  final bool initialEmergencyMode;

  const FirstAidHospitalsScreen({
    super.key,
    this.initialType,
    this.initialEmergencyMode = false,
  });

  @override
  State<FirstAidHospitalsScreen> createState() => _FirstAidHospitalsScreenState();
}

class _FirstAidHospitalsScreenState extends State<FirstAidHospitalsScreen>
    with TickerProviderStateMixin {
  // ── Filters & Search State ──
  FacilityType? _selectedType;
  bool _isEmergencyMode = false;
  String _selectedCity = 'Islamabad';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Data State ──
  List<MedicalFacility> _facilities = [];
  List<HelplineItem> _helplines = [];
  MedicalFacility? _selectedMapFacility;

  bool _isLoading = true;
  bool _isHelplinesLoading = true;
  String? _errorMessage;

  // ── Animations ──
  late AnimationController _entranceCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _isEmergencyMode = widget.initialEmergencyMode || widget.initialType == FacilityType.emergency;

    _setupAnimations();
    _entranceCtrl.forward();

    _loadData();
  }

  void _setupAnimations() {
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final helplinesFuture = MedicalAssistanceService.getEmergencyHelplines();
      final facilitiesFuture = MedicalAssistanceService.getFacilities(
        type: _selectedType,
        query: _searchQuery,
        city: _selectedCity,
        emergencyOnly: _isEmergencyMode,
      );

      final helplines = await helplinesFuture;
      final facilities = await facilitiesFuture;

      if (!mounted) return;

      setState(() {
        _helplines = helplines;
        _isHelplinesLoading = false;
        _facilities = facilities;
        _isLoading = false;
        if (_facilities.isNotEmpty) {
          _selectedMapFacility = _facilities.first;
        } else {
          _selectedMapFacility = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint('LOAD MEDICAL DATA ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isHelplinesLoading = false;
          _errorMessage = 'Unable to fetch medical facilities. Please check your connection and retry.';
        });
      }
    }
  }

  void _onCategorySelected(FacilityType? type) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedType == type && type != FacilityType.emergency) {
        _selectedType = null;
        _isEmergencyMode = false;
      } else {
        _selectedType = type;
        _isEmergencyMode = (type == FacilityType.emergency);
      }
    });
    _loadData();
  }

  void _onCityChanged(String newCity) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCity = newCity;
    });
    _loadData();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadData();
  }

  void _triggerCallDialog(String title, String phone, String description) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Colors.redAccent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.redAccent,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSnackbar('Dialing $phone ($title)...');
                      },
                      icon: const Icon(Icons.call_rounded),
                      label: Text('Call $phone Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNavigationDirectionsModal(MedicalFacility facility) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car_rounded, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route to ${facility.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${facility.distance} away • Est. ${facility.estimatedTravelTime}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.4) : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        facility.address,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showSnackbar('Launching GPS Navigation to ${facility.name}...');
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Start Navigation (Google Maps / Waze)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFacilityDetailsModal(MedicalFacility facility) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.84,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 25,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Header Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: facility.isEmergency
                              ? [const Color(0xFFD32F2F), const Color(0xFF8B0000)]
                              : [AppTheme.primary, const Color(0xFF42551A)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: (facility.isEmergency ? Colors.redAccent : AppTheme.primary).withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(facility.type.icon, color: Colors.white, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      facility.type.displayName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${facility.rating} (${facility.reviewCount})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            facility.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.near_me_rounded, color: Colors.white70, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                '${facility.distance} • ${facility.estimatedTravelTime} drive',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                facility.operatingHours,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Quick Action Buttons (Call & Navigate)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _triggerCallDialog(facility.name, facility.phone, facility.address);
                            },
                            icon: const Icon(Icons.phone_rounded, size: 18),
                            label: const Text('Call Facility'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showNavigationDirectionsModal(facility);
                            },
                            icon: const Icon(Icons.directions_rounded, size: 18),
                            label: const Text('Get Route'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: AppTheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Address & Landmark
                    Text('Location & Access',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceVariant.withOpacity(0.4)
                            : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  facility.address,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (facility.landmarkNearby != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.tour_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Near ${facility.landmarkNearby}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Medical Services & Specialties
                    Text('Available Services & Facilities',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: facility.services.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222B24) : const Color(0xFFEAF1E7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 22),

                    // Emergency Status & Bed Availability
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: facility.isEmergency
                            ? Colors.redAccent.withOpacity(0.12)
                            : AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (facility.isEmergency ? Colors.redAccent : AppTheme.primary).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            facility.isEmergency ? Icons.emergency_rounded : Icons.bed_rounded,
                            color: facility.isEmergency ? Colors.redAccent : AppTheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Triage & Bed Status',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${facility.emergencyBedStatus} • Fast-Track Traveler Triage',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: facility.isEmergency ? Colors.redAccent : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  void _showCitySelectionDialog() {
    final cities = MedicalAssistanceService.getAvailableCities();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.location_city_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'Select Region',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cities.length,
            itemBuilder: (_, i) {
              final c = cities[i];
              final isSelected = c == _selectedCity;
              final isGps = c.contains('Current Location');

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: isSelected
                    ? (isGps ? Colors.green.withOpacity(0.18) : AppTheme.primary.withOpacity(0.15))
                    : (isGps ? Colors.green.withOpacity(0.08) : Colors.transparent),
                leading: Icon(
                  isGps
                      ? Icons.my_location_rounded
                      : (c == 'All Locations' ? Icons.public_rounded : Icons.location_on_rounded),
                  color: isSelected
                      ? (isGps ? Colors.green : AppTheme.primary)
                      : (isGps ? Colors.green : (isDark ? Colors.white60 : Colors.black45)),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isGps ? Colors.green : AppTheme.primary)
                              : (isGps ? (isDark ? Colors.greenAccent : Colors.green[800]) : (isDark ? Colors.white : Colors.black87)),
                        ),
                      ),
                    ),
                    if (isGps)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE GPS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: isGps
                    ? Text(
                        'Auto-detect device coordinates & nearest aid',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: isGps ? Colors.green : AppTheme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _onCityChanged(c);
                  if (isGps) {
                    _showSnackbar('Live GPS coordinates acquired. Showing nearest medical facilities.');
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBackground : AppTheme.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppTheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Section ──
                    _buildHeader(),

                    const SizedBox(height: 18),

                    // ── Emergency Helplines Section (8x1 Grid / Stack) ──
                    _buildEmergencyHelplinesSection(),

                    const SizedBox(height: 22),

                    // ── Medical Assistance Category Dropdown (Above Map Radar) ──
                    _buildCategorySelector(),

                    const SizedBox(height: 22),

                    // ── Interactive Map Section ──
                    _buildMapSection(),

                    const SizedBox(height: 22),

                    // ── Nearby Facilities List Header & Search ──
                    _buildFacilitiesListHeader(),

                    const SizedBox(height: 14),

                    // ── Facilities List or State Widgets ──
                    _buildFacilitiesContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. HEADER WIDGET
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;
    final onVar = isDark ? AppTheme.darkOnSurfaceVariant : AppTheme.lightOnSurfaceVariant;
    final tp = ThemeProviderScope.of(context);
    final isGpsSelected = _selectedCity.contains('Current Location');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: onBg, size: 18),
              ),
            ),

            // City / Region Selector Pill
            GestureDetector(
              onTap: _showCitySelectionDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isGpsSelected
                        ? Colors.green.withOpacity(0.6)
                        : AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGpsSelected ? Icons.my_location_rounded : Icons.location_on_rounded,
                      color: isGpsSelected ? Colors.green : AppTheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        _selectedCity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isGpsSelected ? (isDark ? Colors.greenAccent : Colors.green[800]) : onBg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, color: onVar, size: 16),
                  ],
                ),
              ),
            ),

            // Theme toggle
            ThemeToggle(isDark: tp.isDark, onToggle: () => tp.toggleTheme()),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'First Aid & Hospitals',
          style: TextStyle(
            color: onBg,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '"Locate immediate trauma care, clinics & emergency helplines anywhere in Pakistan."',
          style: TextStyle(
            color: onVar,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. MEDICAL ASSISTANCE CATEGORY DROPDOWN (JUST ABOVE INTERACTIVE MAP)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategorySelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onBg = isDark ? AppTheme.darkOnBackground : AppTheme.lightOnBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Select Assistance Needed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (_selectedType != null)
              GestureDetector(
                onTap: () => _onCategorySelected(null),
                child: const Text(
                  'Reset Filter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _selectedType == FacilityType.emergency
                  ? Colors.redAccent.withOpacity(0.5)
                  : (_selectedType != null
                      ? AppTheme.primary.withOpacity(0.5)
                      : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))),
              width: _selectedType != null ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FacilityType?>(
              value: _selectedType,
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
              borderRadius: BorderRadius.circular(18),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
              items: [
                DropdownMenuItem<FacilityType?>(
                  value: null,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.medical_services_rounded, color: AppTheme.primary, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'All Facilities & Services',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: onBg,
                        ),
                      ),
                    ],
                  ),
                ),
                ...FacilityType.values.map((type) {
                  final isEmergency = type == FacilityType.emergency;
                  return DropdownMenuItem<FacilityType?>(
                    value: type,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (isEmergency ? Colors.redAccent : type.color).withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            type.icon,
                            color: isEmergency ? Colors.redAccent : type.color,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            type.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isEmergency ? Colors.redAccent : onBg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                _onCategorySelected(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. EMERGENCY HELPLINES SECTION (8x1 GRID)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmergencyHelplinesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: Colors.redAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Emergency Helplines',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Verified Toll-Free',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isHelplinesLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _helplines.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final h = _helplines[i];
                return _HelplineCard(
                  helpline: h,
                  onCall: () => _triggerCallDialog(h.name, h.phoneNumber, h.description),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. INTERACTIVE MAP SECTION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMapSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Interactive Medical Radar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '${_facilities.length} pins nearby',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InteractiveMedicalMap(
          facilities: _facilities,
          selectedFacility: _selectedMapFacility,
          isEmergencyActive: _isEmergencyMode,
          height: 290,
          onFacilitySelected: (f) {
            setState(() => _selectedMapFacility = f);
            _showFacilityDetailsModal(f);
          },
          onRecenter: () {
            _showSnackbar('GPS Location re-centered on $_selectedCity.');
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. FACILITIES LIST HEADER & SEARCH
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFacilitiesListHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nearby Facilities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (_isEmergencyMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Emergency Wards Only',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.redAccent),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Search text field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search hospital, pharmacy, or trauma care...',
              hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. FACILITIES CONTENT (LIST / LOADING / ERROR / EMPTY STATES)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFacilitiesContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Loading state
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
              SizedBox(height: 12),
              Text('Scanning nearby medical facilities...',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            Text(
              'Unable to Load Facilities',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state
    if (_facilities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Icon(Icons.location_off_rounded, color: AppTheme.primary, size: 42),
            const SizedBox(height: 10),
            Text(
              'No Matching Facilities Found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your filters, expanding your search term, or switching the selected city.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                _onCategorySelected(null);
                _onCityChanged('All Locations');
              },
              child: const Text('Reset All Filters', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    // Results found: Render list of facility cards
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _facilities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        final facility = _facilities[i];
        return _FacilityCard(
          facility: facility,
          onTap: () => _showFacilityDetailsModal(facility),
          onCall: () => _triggerCallDialog(facility.name, facility.phone, facility.address),
          onNavigate: () => _showNavigationDirectionsModal(facility),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT: HELPLINE CARD (SOS BANNER STYLE IN 8x1 GRID)
// ─────────────────────────────────────────────────────────────────────────────
class _HelplineCard extends StatelessWidget {
  final HelplineItem helpline;
  final VoidCallback onCall;

  const _HelplineCard({required this.helpline, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final darkerTone = Color.lerp(helpline.badgeColor, Colors.black, 0.38) ?? helpline.badgeColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [helpline.badgeColor, darkerTone],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: helpline.badgeColor.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(helpline.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  helpline.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  helpline.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: onCall,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: helpline.badgeColor,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call, size: 13),
                const SizedBox(width: 3),
                Text(
                  helpline.phoneNumber,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
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
// COMPONENT: FACILITY RESULT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _FacilityCard extends StatelessWidget {
  final MedicalFacility facility;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onNavigate;

  const _FacilityCard({
    required this.facility,
    required this.onTap,
    required this.onCall,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: facility.isEmergency
              ? Colors.redAccent.withOpacity(0.35)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
          width: facility.isEmergency ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type Badge + Distance / Open Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: (facility.isEmergency ? Colors.redAccent : facility.type.color).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            facility.type.icon,
                            size: 13,
                            color: facility.isEmergency ? Colors.redAccent : facility.type.color,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            facility.type.displayName,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: facility.isEmergency ? Colors.redAccent : facility.type.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: facility.isOpen ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          facility.isOpen ? 'Open Now' : 'Closed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: facility.isOpen ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Name & Rating
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        facility.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          facility.rating.toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Address & Travel Distance
                Row(
                  children: [
                    const Icon(Icons.near_me_rounded, color: AppTheme.primary, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${facility.distance} • ${facility.estimatedTravelTime}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        facility.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Services tags preview
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: facility.services.take(3).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceVariant.withOpacity(0.4) : AppTheme.lightSurfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Action Buttons (Call, Navigate, Details)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCall,
                        icon: const Icon(Icons.call, size: 15, color: Colors.redAccent),
                        label: const Text('Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.directions_rounded, size: 15, color: AppTheme.primary),
                        label: const Text('Directions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primary, size: 14),
                        onPressed: onTap,
                        tooltip: 'View Details',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
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
