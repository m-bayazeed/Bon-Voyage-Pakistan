import 'package:flutter/material.dart';

/// Enum representing the classification of medical facilities.
enum FacilityType {
  emergency,
  firstAid,
  primaryCare,
  secondaryCare,
  tertiaryCare,
  government,
  privateHospital,
  pharmacy,
  clinic,
}

extension FacilityTypeExtension on FacilityType {
  String get displayName {
    switch (this) {
      case FacilityType.emergency:
        return 'Emergency (24/7)';
      case FacilityType.firstAid:
        return 'First Aid Station';
      case FacilityType.primaryCare:
        return 'Primary Care';
      case FacilityType.secondaryCare:
        return 'Secondary Care';
      case FacilityType.tertiaryCare:
        return 'Tertiary Care';
      case FacilityType.government:
        return 'Govt Hospital';
      case FacilityType.privateHospital:
        return 'Private Hospital';
      case FacilityType.pharmacy:
        return '24/7 Pharmacy';
      case FacilityType.clinic:
        return 'Clinic / Diagnostic';
    }
  }

  String get shortName {
    switch (this) {
      case FacilityType.emergency:
        return 'Emergency';
      case FacilityType.firstAid:
        return 'First Aid';
      case FacilityType.primaryCare:
        return 'Primary Care';
      case FacilityType.secondaryCare:
        return 'Secondary Care';
      case FacilityType.tertiaryCare:
        return 'Tertiary Care';
      case FacilityType.government:
        return 'Government';
      case FacilityType.privateHospital:
        return 'Private';
      case FacilityType.pharmacy:
        return 'Pharmacy';
      case FacilityType.clinic:
        return 'Clinic';
    }
  }

  IconData get icon {
    switch (this) {
      case FacilityType.emergency:
        return Icons.emergency_rounded;
      case FacilityType.firstAid:
        return Icons.healing_rounded;
      case FacilityType.primaryCare:
        return Icons.local_hospital_rounded;
      case FacilityType.secondaryCare:
        return Icons.domain_add_rounded;
      case FacilityType.tertiaryCare:
        return Icons.apartment_rounded;
      case FacilityType.government:
        return Icons.account_balance_rounded;
      case FacilityType.privateHospital:
        return Icons.medical_services_rounded;
      case FacilityType.pharmacy:
        return Icons.medication_rounded;
      case FacilityType.clinic:
        return Icons.health_and_safety_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FacilityType.emergency:
        return const Color(0xFFD32F2F);
      case FacilityType.firstAid:
        return const Color(0xFFE65100);
      case FacilityType.primaryCare:
        return const Color(0xFF2E7D32);
      case FacilityType.secondaryCare:
        return const Color(0xFF0277BD);
      case FacilityType.tertiaryCare:
        return const Color(0xFF6A1B9A);
      case FacilityType.government:
        return const Color(0xFF37474F);
      case FacilityType.privateHospital:
        return const Color(0xFF1565C0);
      case FacilityType.pharmacy:
        return const Color(0xFF00897B);
      case FacilityType.clinic:
        return const Color(0xFF455A64);
    }
  }
}

/// Data model representing a medical facility or hospital.
class MedicalFacility {
  final String id;
  final String name;
  final FacilityType type;
  final double latitude;
  final double longitude;
  final String address;
  final String distance;
  final String estimatedTravelTime;
  final String phone;
  final bool isEmergency;
  final bool isOpen;
  final double rating;
  final int reviewCount;
  final List<String> services;
  final String operatingHours;
  final String emergencyBedStatus;
  final String? city;
  final String? landmarkNearby;

  const MedicalFacility({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.distance,
    required this.estimatedTravelTime,
    required this.phone,
    required this.isEmergency,
    required this.isOpen,
    required this.rating,
    required this.reviewCount,
    required this.services,
    required this.operatingHours,
    required this.emergencyBedStatus,
    this.city,
    this.landmarkNearby,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'distance': distance,
      'estimatedTravelTime': estimatedTravelTime,
      'phone': phone,
      'isEmergency': isEmergency ? 1 : 0,
      'isOpen': isOpen ? 1 : 0,
      'rating': rating,
      'reviewCount': reviewCount,
      'services': services,
      'operatingHours': operatingHours,
      'emergencyBedStatus': emergencyBedStatus,
      'city': city,
      'landmarkNearby': landmarkNearby,
    };
  }

  factory MedicalFacility.fromMap(Map<String, dynamic> map) {
    FacilityType parseType(String? val) {
      if (val == null) return FacilityType.primaryCare;
      try {
        return FacilityType.values.firstWhere((e) => e.name == val);
      } catch (_) {
        return FacilityType.primaryCare;
      }
    }

    return MedicalFacility(
      id: map['id'] as String? ?? 'FAC-${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Medical Center',
      type: parseType(map['type'] as String?),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 33.6844,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 73.0479,
      address: map['address'] as String? ?? '',
      distance: map['distance'] as String? ?? '1.2 km',
      estimatedTravelTime: map['estimatedTravelTime'] as String? ?? '5 mins',
      phone: map['phone'] as String? ?? '1122',
      isEmergency: map['isEmergency'] == 1 || map['isEmergency'] == true,
      isOpen: map['isOpen'] == 1 || map['isOpen'] == true,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 100,
      services: map['services'] is List ? List<String>.from(map['services'] as List) : <String>[],
      operatingHours: map['operatingHours'] as String? ?? '24/7 Open',
      emergencyBedStatus: map['emergencyBedStatus'] as String? ?? 'Available',
      city: map['city'] as String?,
      landmarkNearby: map['landmarkNearby'] as String?,
    );
  }
}

/// Enum representing classification of emergency helplines.
enum HelplineType {
  ambulance,
  police,
  rescue,
  touristPolice,
  disasterRelief,
  fireBrigade,
  highwayPatrol,
}

/// Data model representing an emergency helpline.
class HelplineItem {
  final String id;
  final String name;
  final String description;
  final String phoneNumber;
  final HelplineType type;
  final String agency;
  final IconData icon;
  final Color badgeColor;

  const HelplineItem({
    required this.id,
    required this.name,
    required this.description,
    required this.phoneNumber,
    required this.type,
    required this.agency,
    required this.icon,
    required this.badgeColor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'phoneNumber': phoneNumber,
      'type': type.name,
      'agency': agency,
    };
  }

  factory HelplineItem.fromMap(Map<String, dynamic> map) {
    HelplineType parseType(String? val) {
      if (val == null) return HelplineType.ambulance;
      try {
        return HelplineType.values.firstWhere((e) => e.name == val);
      } catch (_) {
        return HelplineType.ambulance;
      }
    }

    final t = parseType(map['type'] as String?);
    IconData icon;
    Color color;

    switch (t) {
      case HelplineType.ambulance:
        icon = Icons.airport_shuttle_rounded;
        color = const Color(0xFFD32F2F);
        break;
      case HelplineType.rescue:
        icon = Icons.health_and_safety_rounded;
        color = const Color(0xFFE65100);
        break;
      case HelplineType.police:
        icon = Icons.local_police_rounded;
        color = const Color(0xFF1565C0);
        break;
      case HelplineType.touristPolice:
        icon = Icons.shield_rounded;
        color = const Color(0xFF00897B);
        break;
      case HelplineType.highwayPatrol:
        icon = Icons.traffic_rounded;
        color = const Color(0xFF5A7328);
        break;
      case HelplineType.disasterRelief:
        icon = Icons.warning_amber_rounded;
        color = const Color(0xFF6A1B9A);
        break;
      case HelplineType.fireBrigade:
        icon = Icons.local_fire_department_rounded;
        color = const Color(0xFFC2185B);
        break;
    }

    return HelplineItem(
      id: map['id'] as String? ?? 'HELP-${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? 'Emergency Helpline',
      description: map['description'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '1122',
      type: t,
      agency: map['agency'] as String? ?? 'Govt of Pakistan',
      icon: icon,
      badgeColor: color,
    );
  }
}
