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
        return 'Mountain Resort';
      case HotelCategory.boutique:
        return 'Boutique & Lodge';
      case HotelCategory.budget:
        return 'Guest House / Budget';
      case HotelCategory.glamping:
        return 'Glamping & Campsite';
    }
  }

  IconData get icon {
    switch (this) {
      case HotelCategory.all:
        return Icons.hotel_rounded;
      case HotelCategory.luxury:
        return Icons.star_rounded;
      case HotelCategory.resort:
        return Icons.landscape_rounded;
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
  reviews,
  priceLowToHigh,
  priceHighToLow,
}

extension HotelSortOptionExtension on HotelSortOption {
  String get displayName {
    switch (this) {
      case HotelSortOption.nearness:
        return 'Nearest to Me';
      case HotelSortOption.rating:
        return 'Top Rated';
      case HotelSortOption.reviews:
        return 'Most Popular (Reviews)';
      case HotelSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case HotelSortOption.priceHighToLow:
        return 'Price: High to Low';
    }
  }

  IconData get icon {
    switch (this) {
      case HotelSortOption.nearness:
        return Icons.near_me_rounded;
      case HotelSortOption.rating:
        return Icons.star_rate_rounded;
      case HotelSortOption.reviews:
        return Icons.rate_review_rounded;
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

/// Comprehensive Hotel model supporting rich UI, map markers, distance calculations,
/// and future Maps/Places/Backend API ingestion.
class Hotel {
  final String id;
  final String name;
  final HotelCategory category;
  final double latitude;
  final double longitude;
  final String city;
  final String address;
  final String distance;
  final double distanceKm;
  final String estimatedTravelTime;
  final double rating;
  final int reviewCount;
  final int pricePerNightPkr;
  final String imageUrl;
  final List<String> galleryImages;
  final bool isAvailable;
  final String phone;
  final String? website;
  final List<HotelAmenity> amenities;
  final String description;
  final String? popularReviewSnippet;
  final String landmarkNearby;

  const Hotel({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.address,
    required this.distance,
    required this.distanceKm,
    required this.estimatedTravelTime,
    required this.rating,
    required this.reviewCount,
    required this.pricePerNightPkr,
    required this.imageUrl,
    this.galleryImages = const [],
    this.isAvailable = true,
    required this.phone,
    this.website,
    required this.amenities,
    required this.description,
    this.popularReviewSnippet,
    required this.landmarkNearby,
  });

  /// Formatted price string in PKR currency (e.g. "PKR 25,000 / night").
  String get formattedPrice {
    final priceStr = pricePerNightPkr.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return 'PKR $priceStr';
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
      amenities: amenities,
      description: description,
      popularReviewSnippet: popularReviewSnippet,
      landmarkNearby: landmarkNearby,
    );
  }

  /// Create model instance from standard JSON dictionary (for future backend API).
  factory Hotel.fromJson(Map<String, dynamic> json) {
    return Hotel(
      id: json['id'] as String? ?? 'HTL-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unnamed Hotel',
      category: _parseCategory(json['category'] as String?),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 33.6844,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 73.0479,
      city: json['city'] as String? ?? 'Islamabad',
      address: json['address'] as String? ?? '',
      distance: json['distance'] as String? ?? 'Nearby',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 1.0,
      estimatedTravelTime: json['estimatedTravelTime'] as String? ?? '5 mins',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 100,
      pricePerNightPkr: (json['pricePerNightPkr'] as num?)?.toInt() ?? 15000,
      imageUrl: json['imageUrl'] as String? ?? '',
      galleryImages: (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAvailable: json['isAvailable'] as bool? ?? true,
      phone: json['phone'] as String? ?? '+92-51-111-111-111',
      website: json['website'] as String?,
      amenities: _parseAmenities(json['amenities'] as List<dynamic>?),
      description: json['description'] as String? ?? '',
      popularReviewSnippet: json['popularReviewSnippet'] as String?,
      landmarkNearby: json['landmarkNearby'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'address': address,
      'distance': distance,
      'distanceKm': distanceKm,
      'estimatedTravelTime': estimatedTravelTime,
      'rating': rating,
      'reviewCount': reviewCount,
      'pricePerNightPkr': pricePerNightPkr,
      'imageUrl': imageUrl,
      'galleryImages': galleryImages,
      'isAvailable': isAvailable,
      'phone': phone,
      'website': website,
      'amenities': amenities.map((a) => a.name).toList(),
      'description': description,
      'popularReviewSnippet': popularReviewSnippet,
      'landmarkNearby': landmarkNearby,
    };
  }

  static HotelCategory _parseCategory(String? raw) {
    if (raw == null) return HotelCategory.luxury;
    return HotelCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => HotelCategory.luxury,
    );
  }

  static List<HotelAmenity> _parseAmenities(List<dynamic>? rawList) {
    if (rawList == null) return [HotelAmenity.freeWifi, HotelAmenity.mountainView];
    final result = <HotelAmenity>[];
    for (final item in rawList) {
      final str = item.toString().toLowerCase();
      for (final a in HotelAmenity.values) {
        if (a.name.toLowerCase() == str) {
          result.add(a);
          break;
        }
      }
    }
    return result.isEmpty
        ? [HotelAmenity.freeWifi, HotelAmenity.mountainView]
        : result;
  }
}
