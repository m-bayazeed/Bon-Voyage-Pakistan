import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/medical_facility_model.dart';
import 'hotel_location_service.dart';

/// Service providing medical facility locator data, search, and emergency helplines.
/// Structured to allow future Maps API and Flask backend integration without UI modifications.
class MedicalAssistanceService {
  static String? _cachedWorkingHost;
  static int? _cachedWorkingPort;

  /// Emergency helplines configured for Pakistan with national coverage.
  static const List<HelplineItem> _defaultHelplines = [
    HelplineItem(
      id: 'HELP-1122',
      name: 'Rescue 1122 Emergency',
      description: 'National 24/7 Ambulance, Fire & Disaster Response',
      phoneNumber: '1122',
      type: HelplineType.rescue,
      agency: 'Punjab & KP Emergency Management Service',
      icon: Icons.health_and_safety_rounded,
      badgeColor: Color(0xFFD32F2F),
    ),
    HelplineItem(
      id: 'HELP-15',
      name: 'Police Emergency Helpline',
      description: 'Immediate Police Assistance, Crime & Security Support',
      phoneNumber: '15',
      type: HelplineType.police,
      agency: 'Pakistan Police Service',
      icon: Icons.local_police_rounded,
      badgeColor: Color(0xFF1565C0),
    ),
    HelplineItem(
      id: 'HELP-115',
      name: 'Edhi Ambulance Network',
      description: 'Largest nationwide emergency ambulance & relief network',
      phoneNumber: '115',
      type: HelplineType.ambulance,
      agency: 'Edhi Foundation Pakistan',
      icon: Icons.emergency_rounded,
      badgeColor: Color(0xFFE65100),
    ),
    HelplineItem(
      id: 'HELP-130',
      name: 'Motorway & Tourist Highway Patrol',
      description: 'Emergency roadside aid, mountain breakdown & highway rescue',
      phoneNumber: '130',
      type: HelplineType.highwayPatrol,
      agency: 'National Highway & Motorway Police (NHMP)',
      icon: Icons.directions_car_rounded,
      badgeColor: Color(0xFF5A7328),
    ),
    HelplineItem(
      id: 'HELP-1020',
      name: 'Chhipa Emergency Service',
      description: '24/7 Rapid ambulance dispatch & trauma transport',
      phoneNumber: '1020',
      type: HelplineType.ambulance,
      agency: 'Chhipa Welfare Association',
      icon: Icons.emergency_rounded,
      badgeColor: Color(0xFFC2185B),
    ),
    HelplineItem(
      id: 'HELP-1422',
      name: 'Tourist Police & Facilitation',
      description: 'Dedicated travel safety, route advisory & foreign tourist aid',
      phoneNumber: '1422',
      type: HelplineType.touristPolice,
      agency: 'KP / Gilgit-Baltistan Tourist Police',
      icon: Icons.support_agent_rounded,
      badgeColor: Color(0xFF00897B),
    ),
    HelplineItem(
      id: 'HELP-1070',
      name: 'NDMA Disaster & Landslide Aid',
      description: 'Severe weather, road blockage & emergency evacuation',
      phoneNumber: '1070',
      type: HelplineType.disasterRelief,
      agency: 'National Disaster Management Authority',
      icon: Icons.warning_amber_rounded,
      badgeColor: Color(0xFF6A1B9A),
    ),
    HelplineItem(
      id: 'HELP-16',
      name: 'Fire Brigade Emergency',
      description: 'Urban and structural fire response units',
      phoneNumber: '16',
      type: HelplineType.fireBrigade,
      agency: 'Civil Defense & Fire Department',
      icon: Icons.local_fire_department_rounded,
      badgeColor: Color(0xFFD84315),
    ),
  ];

  /// Get list of supported emergency helplines.
  static Future<List<HelplineItem>> getEmergencyHelplines({String? region}) async {
    try {
      // Simulate quick async lookup for future backend readiness
      await Future.delayed(const Duration(milliseconds: 100));
      return List<HelplineItem>.from(_defaultHelplines);
    } catch (e, stackTrace) {
      debugPrint('HELPLINE FETCH ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      return List<HelplineItem>.from(_defaultHelplines);
    }
  }

  /// Get available cities/regions in the dataset.
  static List<String> getAvailableCities() {
    return [
      'Current Location (GPS)',
      'All Locations',
      'Islamabad',
      'Hunza',
      'Gilgit',
      'Skardu',
      'Lahore',
      'Swat / Mingora',
      'Kalam',
      'Naran / Kaghan',
    ];
  }

  /// Search and discover live medical facilities using Google Places (New) 30km radius & Google Routes API.
  /// Falls back to curated offline facilities if backend is unreachable.
  static Future<List<MedicalFacility>> getFacilities({
    FacilityType? type,
    String? query,
    String? city,
    bool emergencyOnly = false,
    double? userLat,
    double? userLng,
    double? searchLat,
    double? searchLng,
  }) async {
    final locationName = city ?? 'Current Location (GPS)';
    final isGpsMode = locationName.contains('Current Location') || locationName.contains('GPS');

    // 1. Resolve search center coordinates
    double centerLat;
    double centerLon;

    if (isGpsMode) {
      if (searchLat != null && searchLng != null) {
        centerLat = searchLat;
        centerLon = searchLng;
      } else if (userLat != null && userLng != null) {
        centerLat = userLat;
        centerLon = userLng;
      } else {
        final gps = await HotelLocationService.getCurrentLocation();
        centerLat = gps.latitude;
        centerLon = gps.longitude;
      }
    } else {
      if (searchLat != null && searchLng != null) {
        centerLat = searchLat;
        centerLon = searchLng;
      } else {
        final point = await HotelLocationService.resolveDestination(locationName);
        centerLat = point.latitude;
        centerLon = point.longitude;
      }
    }

    // 2. Resolve user device GPS origin for routing
    double? gpsOriginLat = userLat;
    double? gpsOriginLon = userLng;

    if (gpsOriginLat == null || gpsOriginLon == null) {
      if (isGpsMode) {
        gpsOriginLat = centerLat;
        gpsOriginLon = centerLon;
      }
    }

    final isEmerg = emergencyOnly || type == FacilityType.emergency;
    final payload = {
      'city': locationName,
      'location_name': locationName,
      'latitude': centerLat,
      'longitude': centerLon,
      'user_latitude': gpsOriginLat,
      'user_longitude': gpsOriginLon,
      'radius_km': 30.0,
      'assistance_type': type?.name,
      'emergency_only': isEmerg,
      'search_query': query,
    };

    debugPrint('\n=================== HELP API REQUEST ===================');
    debugPrint('Location: $locationName');
    debugPrint('Search Center: $centerLat, $centerLon (Radius: 30 km)');
    debugPrint('User Device GPS: $gpsOriginLat, $gpsOriginLon');
    debugPrint('Assistance Type: ${type?.name} | Emergency Only: $isEmerg');
    debugPrint('========================================================\n');

    final candidateHosts = List<String>.from(ApiConfig.candidateHosts);
    if (_cachedWorkingHost != null && !candidateHosts.contains(_cachedWorkingHost)) {
      candidateHosts.insert(0, _cachedWorkingHost!);
    } else if (_cachedWorkingHost != null) {
      candidateHosts.remove(_cachedWorkingHost);
      candidateHosts.insert(0, _cachedWorkingHost!);
    }

    final ports = _cachedWorkingPort != null
        ? [_cachedWorkingPort!, if (_cachedWorkingPort == 5000) 8000 else 5000]
        : [5000, 8000];

    for (final host in candidateHosts) {
      for (final port in ports) {
        final url = Uri.parse('http://$host:$port/api/v1/help/search');
        try {
          debugPrint('[Help] POST $url (Payload: $payload)...');
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['success'] == true) {
              _cachedWorkingHost = host;
              _cachedWorkingPort = port;
              final rawFacilities = data['facilities'] as List<dynamic>? ?? [];
              final facilities = rawFacilities
                  .map((item) => MedicalFacility.fromMap(item as Map<String, dynamic>))
                  .toList();

              debugPrint('[Help] Live API returned ${facilities.length} facilities for $locationName from $host:$port');
              return facilities;
            }
          }
        } catch (e) {
          debugPrint('[Help] Host $host:$port unreachable: $e');
        }
      }
    }

    debugPrint('[Help] All backend hosts unreachable.');
    throw Exception('Unable to load nearby places. Please try again.');
  }

  /// Direct helper to fetch facilities for an emergency scenario.
  static Future<List<MedicalFacility>> getEmergencyFacilitiesOnly({
    String? city,
    double? userLat,
    double? userLng,
    double? searchLat,
    double? searchLng,
  }) async {
    return getFacilities(
      emergencyOnly: true,
      city: city,
      userLat: userLat,
      userLng: userLng,
      searchLat: searchLat,
      searchLng: searchLng,
    );
  }
}
