import 'dart:async';
import 'package:flutter/material.dart';
import '../models/medical_facility_model.dart';

/// Service providing medical facility locator data, search, and emergency helplines.
/// Structured to allow future Maps API and Flask backend integration without UI modifications.
class MedicalAssistanceService {
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

  /// Comprehensive curated database of medical facilities across Pakistan.
  static final List<MedicalFacility> _allFacilities = [
    // ── ISLAMABAD / RAWALPINDI ──
    const MedicalFacility(
      id: 'FAC-PIMS-ISB',
      name: 'PIMS Hospital (Pakistan Institute of Medical Sciences)',
      type: FacilityType.tertiaryCare,
      latitude: 33.7058,
      longitude: 73.0560,
      address: 'G-8/3, Sector G-8, Islamabad',
      distance: '1.2 km',
      estimatedTravelTime: '4 mins',
      phone: '051-9261170',
      isEmergency: true,
      isOpen: true,
      rating: 4.6,
      reviewCount: 1420,
      services: [
        '24/7 Level 1 Trauma Center',
        'Burn Center',
        'Pediatric Emergency',
        'ICU / CCU',
        'Blood Bank',
        'Diagnostic Imaging (CT/MRI)',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: '24/7 Active',
      city: 'Islamabad',
      landmarkNearby: 'Centaurus Mall',
    ),
    const MedicalFacility(
      id: 'FAC-SHIFA-ISB',
      name: 'Shifa International Hospital',
      type: FacilityType.privateHospital,
      latitude: 33.6844,
      longitude: 73.0782,
      address: 'Pitras Bukhari Rd, Sector H-8/4, Islamabad',
      distance: '2.8 km',
      estimatedTravelTime: '7 mins',
      phone: '051-8463000',
      isEmergency: true,
      isOpen: true,
      rating: 4.8,
      reviewCount: 2180,
      services: [
        '24/7 Emergency & Critical Care',
        'Cardiac Emergency (Cath Lab)',
        'Stroke Center',
        'Helipad Transfer',
        '24/7 Pharmacy',
        'Multi-organ Transplant',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Available',
      city: 'Islamabad',
      landmarkNearby: 'Faizabad Interchange',
    ),
    const MedicalFacility(
      id: 'FAC-MARGALLA-AID',
      name: 'Margalla Trailhead First Aid Post',
      type: FacilityType.firstAid,
      latitude: 33.7431,
      longitude: 73.0612,
      address: 'Trail 3 & 5 Base, Margalla Hills National Park, Islamabad',
      distance: '3.4 km',
      estimatedTravelTime: '9 mins',
      phone: '051-9260555',
      isEmergency: false,
      isOpen: true,
      rating: 4.7,
      reviewCount: 310,
      services: [
        'Hiker Heat Exhaustion & Dehydration',
        'Sprain & Fracture Splinting',
        'Snakebite Antivenom Kit',
        'Rescue 1122 Mountain Evac',
      ],
      operatingHours: '6:00 AM - 9:00 PM',
      emergencyBedStatus: 'Rapid Response Active',
      city: 'Islamabad',
      landmarkNearby: 'Monal Road / Trail 3',
    ),
    const MedicalFacility(
      id: 'FAC-KULSUM-ISB',
      name: 'Kulsum International Hospital',
      type: FacilityType.secondaryCare,
      latitude: 33.7180,
      longitude: 73.0538,
      address: 'Kulsum Plaza, Blue Area, Jinnah Avenue, Islamabad',
      distance: '1.9 km',
      estimatedTravelTime: '5 mins',
      phone: '051-8446666',
      isEmergency: true,
      isOpen: true,
      rating: 4.6,
      reviewCount: 890,
      services: [
        '24/7 ER & Ambulance Service',
        'Cardiology & Angiography',
        'Inpatient Surgical Care',
        '24/7 Pathology & Ultrasound',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Available',
      city: 'Islamabad',
      landmarkNearby: 'Blue Area Metro Station',
    ),
    const MedicalFacility(
      id: 'FAC-D-WATSON-ISB',
      name: 'D.Watson Chemist & 24/7 Pharmacy',
      type: FacilityType.pharmacy,
      latitude: 33.7225,
      longitude: 73.0715,
      address: 'Super Market, School Rd, Sector F-6/1, Islamabad',
      distance: '2.1 km',
      estimatedTravelTime: '6 mins',
      phone: '051-2824747',
      isEmergency: false,
      isOpen: true,
      rating: 4.7,
      reviewCount: 1650,
      services: [
        '24/7 Emergency Medicine Dispensing',
        'First Aid & Dressing Supplies',
        'Travel Medical Kits & Altitude Sickness Meds',
        'Glucose & Blood Pressure Checks',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'In Stock',
      city: 'Islamabad',
      landmarkNearby: 'F-6 Super Market',
    ),
    const MedicalFacility(
      id: 'FAC-CDA-HOSP-ISB',
      name: 'Capital Hospital (CDA Hospital)',
      type: FacilityType.government,
      latitude: 33.7121,
      longitude: 73.0805,
      address: 'Sector G-6/2, Near Melody Market, Islamabad',
      distance: '3.1 km',
      estimatedTravelTime: '8 mins',
      phone: '051-9218270',
      isEmergency: true,
      isOpen: true,
      rating: 4.3,
      reviewCount: 650,
      services: [
        '24/7 Emergency Ward',
        'Government Subsidized Treatment',
        'General Surgery & Orthopedics',
        'Inpatient Wards',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Active',
      city: 'Islamabad',
      landmarkNearby: 'Melody Market G-6',
    ),
    const MedicalFacility(
      id: 'FAC-MEDICSI-CLINIC',
      name: 'Medicsi Specialist Clinic & Primary Care',
      type: FacilityType.primaryCare,
      latitude: 33.7104,
      longitude: 73.0388,
      address: 'Street 38, Sector F-8/1, Islamabad',
      distance: '2.5 km',
      estimatedTravelTime: '7 mins',
      phone: '051-2853888',
      isEmergency: false,
      isOpen: true,
      rating: 4.5,
      reviewCount: 420,
      services: [
        'Family Physician Consultations',
        'Minor Injury Suturing',
        'Travel Vaccination & Health Certificates',
        'Lab Sample Collection',
      ],
      operatingHours: '8:00 AM - 10:00 PM',
      emergencyBedStatus: 'OPD Active',
      city: 'Islamabad',
      landmarkNearby: 'F-8 Markaz',
    ),

    // ── GILGIT-BALTISTAN (NORTHERN TOURIST HUBS) ──
    const MedicalFacility(
      id: 'FAC-AKHS-HUNZA',
      name: 'Aga Khan Health Centre Karimabad',
      type: FacilityType.primaryCare,
      latitude: 36.3262,
      longitude: 74.6644,
      address: 'Main Bazaar Road, Karimabad, Hunza Valley',
      distance: '0.8 km',
      estimatedTravelTime: '3 mins',
      phone: '05813-457032',
      isEmergency: true,
      isOpen: true,
      rating: 4.9,
      reviewCount: 520,
      services: [
        '24/7 Acute Altitude Sickness Triage (AMS/HAPE)',
        'Oxygen Cylinder Refills & Inhalation Therapy',
        'Traveler Trauma Stabilization & Ambulance',
        'Maternal & Pediatric Primary Care',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Oxygen Beds Available',
      city: 'Hunza',
      landmarkNearby: 'Baltit Fort Karimabad',
    ),
    const MedicalFacility(
      id: 'FAC-DHQ-GILGIT',
      name: 'DHQ Hospital Gilgit (Provincial Trauma Center)',
      type: FacilityType.tertiaryCare,
      latitude: 35.9197,
      longitude: 74.3142,
      address: 'Hospital Road, Kashrote, Gilgit City',
      distance: '1.5 km',
      estimatedTravelTime: '5 mins',
      phone: '05811-920253',
      isEmergency: true,
      isOpen: true,
      rating: 4.5,
      reviewCount: 780,
      services: [
        '24/7 Specialized Trauma & Orthopedics',
        'Military & Civilian Air Ambulance Evac Coordination',
        'Intensive Care Unit (ICU)',
        'High Altitude Medical Research Unit',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: '24/7 Emergency Active',
      city: 'Gilgit',
      landmarkNearby: 'Gilgit Airport / River Bridge',
    ),
    const MedicalFacility(
      id: 'FAC-DHQ-SKARDU',
      name: 'DHQ Hospital Skardu & Karakoram High-Altitude Unit',
      type: FacilityType.secondaryCare,
      latitude: 35.2971,
      longitude: 75.6333,
      address: 'Airport Road, Skardu City, Baltistan',
      distance: '2.0 km',
      estimatedTravelTime: '6 mins',
      phone: '05815-920120',
      isEmergency: true,
      isOpen: true,
      rating: 4.7,
      reviewCount: 460,
      services: [
        'Expedition & Trekking Emergency Assistance',
        'Hyperbaric Chamber (Gamow Bag) Available',
        'Frostbite Treatment & Limb Salvage',
        '24/7 Emergency Surgery',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Active',
      city: 'Skardu',
      landmarkNearby: 'Skardu Fort / Bazaar',
    ),
    const MedicalFacility(
      id: 'FAC-BABUSAR-FIRSTAID',
      name: 'Babusar Pass Emergency Aid & Highway Post',
      type: FacilityType.firstAid,
      latitude: 35.1472,
      longitude: 74.0489,
      address: 'Babusar Top (13,700 ft), Naran-Chilas Highway',
      distance: '5.2 km',
      estimatedTravelTime: '15 mins',
      phone: '1122',
      isEmergency: true,
      isOpen: true,
      rating: 4.8,
      reviewCount: 230,
      services: [
        'Rapid Mountain Oxygen Dispenser',
        'Hypothermia Warming Blankets',
        'Rescue 1122 4x4 Mountain Ambulance',
      ],
      operatingHours: '6:00 AM - 8:00 PM (Summer)',
      emergencyBedStatus: 'Emergency Response Post',
      city: 'Naran / Kaghan',
      landmarkNearby: 'Babusar Top Crest',
    ),

    // ── LAHORE / PUNJAB ──
    const MedicalFacility(
      id: 'FAC-MAYO-LHR',
      name: 'Mayo Hospital Lahore (King Edward Medical)',
      type: FacilityType.government,
      latitude: 31.5746,
      longitude: 74.3128,
      address: 'Hospital Rd, Anarkali, Walled City, Lahore',
      distance: '2.3 km',
      estimatedTravelTime: '7 mins',
      phone: '042-99211100',
      isEmergency: true,
      isOpen: true,
      rating: 4.6,
      reviewCount: 3400,
      services: [
        'Largest Emergency Complex in Pakistan (300+ ER Beds)',
        'Level 1 Trauma & Burn Unit',
        'Pediatric Emergency',
        '24/7 Neurosurgery',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'High Capacity Active',
      city: 'Lahore',
      landmarkNearby: 'Anarkali Bazaar / Mall Road',
    ),
    const MedicalFacility(
      id: 'FAC-NATIONAL-LHR',
      name: 'National Hospital & Medical Centre DHA',
      type: FacilityType.privateHospital,
      latitude: 31.4789,
      longitude: 74.3792,
      address: 'Sector L, Phase 1, DHA, Lahore',
      distance: '3.0 km',
      estimatedTravelTime: '8 mins',
      phone: '042-111171819',
      isEmergency: true,
      isOpen: true,
      rating: 4.7,
      reviewCount: 1890,
      services: [
        '24/7 Emergency & Fast-Track Triage',
        'Advanced Cardiac ICU',
        '24/7 Pharmacy & In-House Blood Bank',
        'Executive Inpatient Suites',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Available',
      city: 'Lahore',
      landmarkNearby: 'DHA Phase 1 Commercial Market',
    ),
    const MedicalFacility(
      id: 'FAC-FAZAL-DIN-LHR',
      name: 'Fazal Din\'s Pharma Plus 24/7',
      type: FacilityType.pharmacy,
      latitude: 31.5204,
      longitude: 74.3587,
      address: 'Main Boulevard, Gulberg III, Lahore',
      distance: '1.4 km',
      estimatedTravelTime: '4 mins',
      phone: '042-35754444',
      isEmergency: false,
      isOpen: true,
      rating: 4.8,
      reviewCount: 2100,
      services: [
        '24/7 Temperature-Controlled Drug Dispensing',
        'Imported Traveler Vaccines',
        'Emergency Medical Equipment Rental',
        'Home Delivery in 30 Mins',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'In Stock',
      city: 'Lahore',
      landmarkNearby: 'Liberty Roundabout Gulberg',
    ),

    // ── SWAT & KP TOURIST ZONES ──
    const MedicalFacility(
      id: 'FAC-DHQ-SAIDU-SWAT',
      name: 'Saidu Teaching Hospital & Trauma Center',
      type: FacilityType.tertiaryCare,
      latitude: 34.7500,
      longitude: 72.3556,
      address: 'Hospital Road, Saidu Sharif, Swat Valley, KP',
      distance: '1.8 km',
      estimatedTravelTime: '5 mins',
      phone: '0946-9240131',
      isEmergency: true,
      isOpen: true,
      rating: 4.7,
      reviewCount: 940,
      services: [
        '24/7 Swat Valley Central Trauma Center',
        'Orthopedic & Head Injury Unit',
        'Tourist Emergency Fast Response Unit',
        'Rescue 1122 Station On-Premises',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: '24/7 Active',
      city: 'Swat / Mingora',
      landmarkNearby: 'Swat Museum / Saidu Sharif',
    ),
    const MedicalFacility(
      id: 'FAC-KALAM-FIRSTAID',
      name: 'Kalam Valley Tourist First Aid Station',
      type: FacilityType.firstAid,
      latitude: 35.4833,
      longitude: 72.5833,
      address: 'Main Kalam Bazaar, Upper Swat Valley',
      distance: '0.5 km',
      estimatedTravelTime: '2 mins',
      phone: '1122',
      isEmergency: true,
      isOpen: true,
      rating: 4.6,
      reviewCount: 380,
      services: [
        'Alpine Trekker Minor Trauma Care',
        'Highland Sickness Oxygen & Steroids',
        'River Incident Emergency Resuscitation',
      ],
      operatingHours: '24/7 Open',
      emergencyBedStatus: 'Available',
      city: 'Kalam',
      landmarkNearby: 'Swat River Kalam Bridge',
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

  /// Search and filter facilities by type, query keyword, city, and emergency status.
  static Future<List<MedicalFacility>> getFacilities({
    FacilityType? type,
    String? query,
    String? city,
    bool emergencyOnly = false,
    double? userLat,
    double? userLng,
  }) async {
    try {
      // Realistic simulation delay for API response
      await Future.delayed(const Duration(milliseconds: 350));

      List<MedicalFacility> results = List<MedicalFacility>.from(_allFacilities);

      // Filter by Emergency Priority
      if (emergencyOnly || type == FacilityType.emergency) {
        results = results.where((f) => f.isEmergency).toList();
      } else if (type != null) {
        results = results.where((f) => f.type == type).toList();
      }

      // Filter by City if specified and not "All Locations" or "Current Location"
      if (city != null &&
          city.isNotEmpty &&
          city != 'All Locations' &&
          !city.contains('Current Location')) {
        results = results
            .where((f) => (f.city ?? '').toLowerCase().contains(city.toLowerCase()))
            .toList();
      }

      // Search keyword filter (name, address, services, landmarks)
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        results = results.where((f) {
          final inName = f.name.toLowerCase().contains(q);
          final inAddress = f.address.toLowerCase().contains(q);
          final inCity = (f.city ?? '').toLowerCase().contains(q);
          final inLandmark = (f.landmarkNearby ?? '').toLowerCase().contains(q);
          final inServices = f.services.any((s) => s.toLowerCase().contains(q));
          final inType = f.type.displayName.toLowerCase().contains(q);
          return inName || inAddress || inCity || inLandmark || inServices || inType;
        }).toList();
      }

      // Sort: Emergency facilities first, then by rating
      results.sort((a, b) {
        if (a.isEmergency != b.isEmergency) {
          return a.isEmergency ? -1 : 1;
        }
        return b.rating.compareTo(a.rating);
      });

      return results;
    } catch (e, stackTrace) {
      debugPrint('MEDICAL FACILITIES FETCH ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Direct helper to fetch facilities for an emergency scenario.
  static Future<List<MedicalFacility>> getEmergencyFacilitiesOnly({String? city}) async {
    return getFacilities(
      emergencyOnly: true,
      city: city,
    );
  }
}
