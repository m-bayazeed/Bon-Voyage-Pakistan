import 'package:flutter/material.dart';

/// Categories of hotels and accommodations available across Pakistan.
enum HotelCategory {
  all,
  luxury,
  resort,
  boutique,
  budget,
  glamping,
}

extension HotelCategoryExtension on HotelCategory {
  String get displayName {
    switch (this) {
      case HotelCategory.all:
        return 'All Stays';
      case HotelCategory.luxury:
        return '5-Star Luxury';
      case HotelCategory.resort:
        return 'Resorts & Retreats';
      case HotelCategory.boutique:
        return 'Boutique & Lodge';
      case HotelCategory.budget:
        return 'Guest House / Budget';
      case HotelCategory.glamping:
        return 'Campsite / Glamping';
    }
  }

  IconData get icon {
    switch (this) {
      case HotelCategory.all:
        return Icons.hotel_rounded;
      case HotelCategory.luxury:
        return Icons.star_rounded;
      case HotelCategory.resort:
        return Icons.spa_rounded;
      case HotelCategory.boutique:
        return Icons.villa_rounded;
      case HotelCategory.budget:
        return Icons.home_work_rounded;
      case HotelCategory.glamping:
        return Icons.cabin_rounded;
    }
  }

  Color get color {
    switch (this) {
      case HotelCategory.all:
        return const Color(0xFF5A7328);
      case HotelCategory.luxury:
        return const Color(0xFFE6A100);
      case HotelCategory.resort:
        return const Color(0xFF00897B);
      case HotelCategory.boutique:
        return const Color(0xFF8E24AA);
      case HotelCategory.budget:
        return const Color(0xFF43A047);
      case HotelCategory.glamping:
        return const Color(0xFFD84315);
    }
  }
}

/// Supported sorting options for hotel listings.
enum HotelSortOption {
  nearness,
  rating,
  priceLowToHigh,
  priceHighToLow,
}

extension HotelSortOptionExtension on HotelSortOption {
  String get displayName {
    switch (this) {
      case HotelSortOption.nearness:
        return 'Nearest';
      case HotelSortOption.rating:
        return 'Highest Rated';
      case HotelSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case HotelSortOption.priceHighToLow:
        return 'Price: High to Low';
    }
  }

  String get apiKey {
    switch (this) {
      case HotelSortOption.nearness:
        return 'nearest';
      case HotelSortOption.rating:
        return 'rating';
      case HotelSortOption.priceLowToHigh:
        return 'price_low_high';
      case HotelSortOption.priceHighToLow:
        return 'price_high_low';
    }
  }

  IconData get icon {
    switch (this) {
      case HotelSortOption.nearness:
        return Icons.near_me_rounded;
      case HotelSortOption.rating:
        return Icons.star_rate_rounded;
      case HotelSortOption.priceLowToHigh:
        return Icons.arrow_upward_rounded;
      case HotelSortOption.priceHighToLow:
        return Icons.arrow_downward_rounded;
    }
  }
}

/// Amenities provided by hotels.
enum HotelAmenity {
  freeWifi,
  mountainView,
  swimmingPool,
  spaWellness,
  restaurant,
  freeBreakfast,
  airportShuttle,
  roomService,
  heatingAc,
  freeParking,
  tourDesk,
  bonfireArea,
}

extension HotelAmenityExtension on HotelAmenity {
  String get displayName {
    switch (this) {
      case HotelAmenity.freeWifi:
        return 'Free High-Speed Wi-Fi';
      case HotelAmenity.mountainView:
        return 'Mountain / Valley View';
      case HotelAmenity.swimmingPool:
        return 'Swimming Pool';
      case HotelAmenity.spaWellness:
        return 'Spa & Wellness Center';
      case HotelAmenity.restaurant:
        return 'Fine Dining Restaurant';
      case HotelAmenity.freeBreakfast:
        return 'Complimentary Breakfast';
      case HotelAmenity.airportShuttle:
        return 'Airport Shuttle';
      case HotelAmenity.roomService:
        return '24/7 Room Service';
      case HotelAmenity.heatingAc:
        return 'Central Heating & AC';
      case HotelAmenity.freeParking:
        return 'Free Secure Parking';
      case HotelAmenity.tourDesk:
        return 'Jeep & Tour Desk';
      case HotelAmenity.bonfireArea:
        return 'Evening Bonfire Area';
    }
  }

  IconData get icon {
    switch (this) {
      case HotelAmenity.freeWifi:
        return Icons.wifi_rounded;
      case HotelAmenity.mountainView:
        return Icons.terrain_rounded;
      case HotelAmenity.swimmingPool:
        return Icons.pool_rounded;
      case HotelAmenity.spaWellness:
        return Icons.spa_rounded;
      case HotelAmenity.restaurant:
        return Icons.restaurant_rounded;
      case HotelAmenity.freeBreakfast:
        return Icons.free_breakfast_rounded;
      case HotelAmenity.airportShuttle:
        return Icons.airport_shuttle_rounded;
      case HotelAmenity.roomService:
        return Icons.room_service_rounded;
      case HotelAmenity.heatingAc:
        return Icons.ac_unit_rounded;
      case HotelAmenity.freeParking:
        return Icons.local_parking_rounded;
      case HotelAmenity.tourDesk:
        return Icons.explore_rounded;
      case HotelAmenity.bonfireArea:
        return Icons.local_fire_department_rounded;
    }
  }
}

/// Comprehensive Hotel model supporting Geoapify data, Gemini enrichment,
/// Haversine distance, and interactive map markers.
class Hotel {
  final String id;
  final String name;
  final HotelCategory category;
  final String badgeLabel;
  final double latitude;
  final double longitude;
  final String city;
  final String address;
  final String distance;
  final double distanceKm;
  final String estimatedTravelTime;
  final double? rating;
  final int? reviewCount;
  final int? pricePerNightPkr;
  final String? imageUrl;
  final List<String> galleryImages;
  final bool isAvailable;
  final String? phone;
  final String? website;
  final List<String> customAmenities;
  final List<HotelAmenity> amenities;
  final String description;
  final String? highlight;
  final String? popularReviewSnippet;
  final String landmarkNearby;
  final String directionsUrl;

  const Hotel({
    required this.id,
    required this.name,
    required this.category,
    this.badgeLabel = 'Hotel & Stay',
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.address,
    required this.distance,
    required this.distanceKm,
    required this.estimatedTravelTime,
    this.rating,
    this.reviewCount,
    this.pricePerNightPkr,
    this.imageUrl,
    this.galleryImages = const [],
    this.isAvailable = true,
    this.phone,
    this.website,
    this.customAmenities = const [],
    this.amenities = const [],
    required this.description,
    this.highlight,
    this.popularReviewSnippet,
    this.landmarkNearby = '',
    required this.directionsUrl,
  });

  /// Formatted price string in PKR currency if available.
  String? get formattedPrice {
    if (pricePerNightPkr == null || pricePerNightPkr! <= 0) {
      return null;
    }
    final priceStr = pricePerNightPkr.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return 'PKR $priceStr / night';
  }

  /// Create a copy of hotel with updated distance based on active user coordinates.
  Hotel copyWithDistance({
    required double newDistanceKm,
    required String newDistance,
    required String newTravelTime,
  }) {
    return Hotel(
      id: id,
      name: name,
      category: category,
      badgeLabel: badgeLabel,
      latitude: latitude,
      longitude: longitude,
      city: city,
      address: address,
      distance: newDistance,
      distanceKm: newDistanceKm,
      estimatedTravelTime: newTravelTime,
      rating: rating,
      reviewCount: reviewCount,
      pricePerNightPkr: pricePerNightPkr,
      imageUrl: imageUrl,
      galleryImages: galleryImages,
      isAvailable: isAvailable,
      phone: phone,
      website: website,
      customAmenities: customAmenities,
      amenities: amenities,
      description: description,
      highlight: highlight,
      popularReviewSnippet: popularReviewSnippet,
      landmarkNearby: landmarkNearby,
      directionsUrl: directionsUrl,
    );
  }

  /// Create model instance from standard JSON dictionary (supporting snake_case & camelCase).
  factory Hotel.fromJson(Map<String, dynamic> json) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? 33.6844;
    final lon = (json['longitude'] as num?)?.toDouble() ?? 73.0479;
    final roadDistKm = (json['road_distance_km'] as num?)?.toDouble() ??
        (json['roadDistanceKm'] as num?)?.toDouble();
    final drivingDurationMin = (json['driving_duration_min'] as num?)?.toInt() ??
        (json['drivingDurationMin'] as num?)?.toInt();
    final formattedDist = json['formatted_distance'] as String? ??
        json['formattedDistance'] as String?;

    final distKmNum = roadDistKm ??
        (json['distance_km'] as num?)?.toDouble() ??
        (json['distanceKm'] as num?)?.toDouble();

    final double distKm = distKmNum ?? 0.0;

    final String distStr;
    if (formattedDist != null && formattedDist.isNotEmpty) {
      distStr = formattedDist;
    } else if (distKmNum != null && distKmNum > 0) {
      distStr = distKmNum < 1.0
          ? '${(distKmNum * 1000).round()} m away'
          : '${distKmNum.toStringAsFixed(1)} km away';
    } else {
      distStr = 'Distance unavailable';
    }

    final String travelTimeStr;
    if (drivingDurationMin != null) {
      travelTimeStr = '~$drivingDurationMin min';
    } else if (json['estimatedTravelTime'] is String &&
        (json['estimatedTravelTime'] as String).isNotEmpty) {
      travelTimeStr = json['estimatedTravelTime'] as String;
    } else {
      travelTimeStr = 'ETA unavailable';
    }

    final rawCat = json['category'] as String?;
    final parsedCat = _parseCategory(rawCat);

    final rawAmenities = json['amenities'] as List<dynamic>?;
    final parsedEnumAmenities = _parseAmenities(rawAmenities);
    final stringAmenities =
        rawAmenities?.map((e) => e.toString()).toList() ?? <String>[];

    final directions = json['directions_url'] as String? ??
        json['directionsUrl'] as String? ??
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon';

    final rawCity = json['city'] as String? ?? 'Pakistan';
    final rawName = json['name'] as String? ?? 'Stay in Pakistan';
    final rawBadge = json['badge_label'] as String? ??
        json['badgeLabel'] as String? ??
        parsedCat.displayName;

    final resolvedBadge = _sanitizeBadgeLabel(
      rawBadge: rawBadge,
      city: rawCity,
      name: rawName,
      category: parsedCat,
    );

    return Hotel(
      id: json['id'] as String? ?? 'HTL-${DateTime.now().millisecondsSinceEpoch}',
      name: rawName,
      category: parsedCat,
      badgeLabel: resolvedBadge,
      latitude: lat,
      longitude: lon,
      city: rawCity,
      address: json['address'] as String? ?? '',
      distance: distStr,
      distanceKm: distKm,
      estimatedTravelTime: travelTimeStr,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['reviews_count'] as num?)?.toInt() ??
          (json['reviewCount'] as num?)?.toInt(),
      pricePerNightPkr: (json['price_per_night_pkr'] as num?)?.toInt() ??
          (json['pricePerNightPkr'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      galleryImages: (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAvailable: json['isAvailable'] as bool? ?? true,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      customAmenities: stringAmenities,
      amenities: parsedEnumAmenities,
      description: json['description'] as String? ??
          'Accommodation located in ${json['city'] ?? 'Pakistan'}.',
      highlight: json['highlight'] as String?,
      popularReviewSnippet: json['popularReviewSnippet'] as String?,
      landmarkNearby: json['landmarkNearby'] as String? ?? '',
      directionsUrl: directions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'badge_label': badgeLabel,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'address': address,
      'distance': distance,
      'distance_km': distanceKm,
      'estimatedTravelTime': estimatedTravelTime,
      'rating': rating,
      'reviews_count': reviewCount,
      'price_per_night_pkr': pricePerNightPkr,
      'image_url': imageUrl,
      'galleryImages': galleryImages,
      'isAvailable': isAvailable,
      'phone': phone,
      'website': website,
      'amenities': customAmenities,
      'description': description,
      'highlight': highlight,
      'popularReviewSnippet': popularReviewSnippet,
      'landmarkNearby': landmarkNearby,
      'directions_url': directionsUrl,
    };
  }

  static String _sanitizeBadgeLabel({
    String? rawBadge,
    required String city,
    required String name,
    required HotelCategory category,
  }) {
    String badge = rawBadge?.trim() ?? '';
    if (badge.isEmpty) {
      badge = category.displayName;
    }

    final c = city.toLowerCase();
    final n = name.toLowerCase();

    final isCoastal = c.contains('karachi') ||
        c.contains('gwadar') ||
        n.contains('karachi') ||
        n.contains('sea view') ||
        n.contains('turtle beach') ||
        n.contains('clifton');
    final isPlains = c.contains('multan') ||
        c.contains('lahore') ||
        c.contains('faisalabad') ||
        c.contains('bahawalpur') ||
        c.contains('sukkur') ||
        c.contains('hyderabad') ||
        n.contains('multan') ||
        n.contains('lahore');

    // If a hotel in Multan, Karachi, Lahore or other plains city is labeled with "Mountain":
    if ((isCoastal || isPlains) && badge.toLowerCase().contains('mountain')) {
      if (isCoastal) {
        if (n.contains('beach') || n.contains('sea') || n.contains('turtle')) {
          return 'Beach Resort';
        } else if (n.contains('waterfront') ||
            n.contains('creek') ||
            n.contains('marina')) {
          return 'Waterfront Resort';
        } else if (n.contains('golf') ||
            n.contains('club') ||
            n.contains('dreamworld')) {
          return 'Golf & Country Club';
        }
        return 'Coastal Resort';
      } else {
        // Plains
        if (n.contains('golf') || n.contains('rumanza')) {
          return 'Golf & Country Resort';
        } else if (n.contains('heritage')) {
          return 'Heritage Resort';
        } else if (category == HotelCategory.luxury) {
          return '5-Star Luxury';
        }
        return 'City Resort & Spa';
      }
    }

    return badge;
  }

  static HotelCategory _parseCategory(String? raw) {
    if (raw == null) return HotelCategory.all;
    final r = raw.toLowerCase().trim();
    if (r.contains('luxury')) return HotelCategory.luxury;
    if (r.contains('resort')) return HotelCategory.resort;
    if (r.contains('boutique')) return HotelCategory.boutique;
    if (r.contains('budget') || r.contains('guesthouse') || r.contains('guest_house') || r.contains('hostel')) {
      return HotelCategory.budget;
    }
    if (r.contains('glamping') || r.contains('camp') || r.contains('campsite')) {
      return HotelCategory.glamping;
    }
    return HotelCategory.all;
  }

  static List<HotelAmenity> _parseAmenities(List<dynamic>? rawList) {
    if (rawList == null) return [];
    final result = <HotelAmenity>[];
    for (final item in rawList) {
      final str = item.toString().toLowerCase();
      if (str.contains('wifi') || str.contains('wi-fi')) {
        result.add(HotelAmenity.freeWifi);
      } else if (str.contains('view') || str.contains('mountain')) {
        result.add(HotelAmenity.mountainView);
      } else if (str.contains('pool')) {
        result.add(HotelAmenity.swimmingPool);
      } else if (str.contains('spa')) {
        result.add(HotelAmenity.spaWellness);
      } else if (str.contains('restaurant') || str.contains('dining')) {
        result.add(HotelAmenity.restaurant);
      } else if (str.contains('breakfast')) {
        result.add(HotelAmenity.freeBreakfast);
      } else if (str.contains('shuttle') || str.contains('airport')) {
        result.add(HotelAmenity.airportShuttle);
      } else if (str.contains('parking')) {
        result.add(HotelAmenity.freeParking);
      } else if (str.contains('heating') || str.contains('ac') || str.contains('air')) {
        result.add(HotelAmenity.heatingAc);
      } else if (str.contains('bonfire') || str.contains('fire')) {
        result.add(HotelAmenity.bonfireArea);
      } else if (str.contains('tour') || str.contains('jeep')) {
        result.add(HotelAmenity.tourDesk);
      } else if (str.contains('room service')) {
        result.add(HotelAmenity.roomService);
      }
    }
    return result.toSet().toList();
  }
}
