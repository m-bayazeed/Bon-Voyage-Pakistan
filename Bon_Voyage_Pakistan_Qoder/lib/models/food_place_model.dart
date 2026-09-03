import 'package:flutter/material.dart';

/// Categories of Pakistani cuisine and dining establishments.
enum FoodCategory {
  all,
  desiPakistani,
  streetFood,
  bbq,
  biryani,
  fastFood,
  chinese,
  continental,
  traditionalLocal,
  cafe,
  bakery,
  dhaba,
  familyDining,
  fineDining,
  vegetarian,
}

extension FoodCategoryExtension on FoodCategory {
  String get displayName {
    switch (this) {
      case FoodCategory.all:
        return 'All Cuisines';
      case FoodCategory.desiPakistani:
        return 'Desi & Karahi';
      case FoodCategory.streetFood:
        return 'Street Food & Chaat';
      case FoodCategory.bbq:
        return 'BBQ & Tikka';
      case FoodCategory.biryani:
        return 'Biryani & Pulao';
      case FoodCategory.fastFood:
        return 'Burgers & Fast Food';
      case FoodCategory.chinese:
        return 'Pak-Chinese';
      case FoodCategory.continental:
        return 'Continental & Steaks';
      case FoodCategory.traditionalLocal:
        return 'Traditional / Regional';
      case FoodCategory.cafe:
        return 'Cafés & Coffee';
      case FoodCategory.bakery:
        return 'Bakeries & Sweets';
      case FoodCategory.dhaba:
        return 'Highway Dhaba & Chai';
      case FoodCategory.familyDining:
        return 'Family Restaurants';
      case FoodCategory.fineDining:
        return 'Fine Dining';
      case FoodCategory.vegetarian:
        return 'Vegetarian & Daal';
    }
  }

  IconData get icon {
    switch (this) {
      case FoodCategory.all:
        return Icons.restaurant_rounded;
      case FoodCategory.desiPakistani:
        return Icons.soup_kitchen_rounded;
      case FoodCategory.streetFood:
        return Icons.fastfood_rounded;
      case FoodCategory.bbq:
        return Icons.outdoor_grill_rounded;
      case FoodCategory.biryani:
        return Icons.rice_bowl_rounded;
      case FoodCategory.fastFood:
        return Icons.lunch_dining_rounded;
      case FoodCategory.chinese:
        return Icons.ramen_dining_rounded;
      case FoodCategory.continental:
        return Icons.dinner_dining_rounded;
      case FoodCategory.traditionalLocal:
        return Icons.set_meal_rounded;
      case FoodCategory.cafe:
        return Icons.local_cafe_rounded;
      case FoodCategory.bakery:
        return Icons.bakery_dining_rounded;
      case FoodCategory.dhaba:
        return Icons.emoji_food_beverage_rounded;
      case FoodCategory.familyDining:
        return Icons.family_restroom_rounded;
      case FoodCategory.fineDining:
        return Icons.wine_bar_rounded;
      case FoodCategory.vegetarian:
        return Icons.eco_rounded;
    }
  }

  Color get color {
    switch (this) {
      case FoodCategory.all:
        return const Color(0xFF5A7328);
      case FoodCategory.desiPakistani:
        return const Color(0xFFD84315);
      case FoodCategory.streetFood:
        return const Color(0xFFF57C00);
      case FoodCategory.bbq:
        return const Color(0xFFC2185B);
      case FoodCategory.biryani:
        return const Color(0xFFE65100);
      case FoodCategory.fastFood:
        return const Color(0xFFFBC02D);
      case FoodCategory.chinese:
        return const Color(0xFFD32F2F);
      case FoodCategory.continental:
        return const Color(0xFF512DA8);
      case FoodCategory.traditionalLocal:
        return const Color(0xFF00796B);
      case FoodCategory.cafe:
        return const Color(0xFF6D4C41);
      case FoodCategory.bakery:
        return const Color(0xFF8D6E63);
      case FoodCategory.dhaba:
        return const Color(0xFF388E3C);
      case FoodCategory.familyDining:
        return const Color(0xFF1976D2);
      case FoodCategory.fineDining:
        return const Color(0xFF455A64);
      case FoodCategory.vegetarian:
        return const Color(0xFF2E7D32);
    }
  }
}

/// Supported sorting options for food discovery.
enum FoodSortOption {
  nearest,
  rating,
  reviews,
  priceLowToHigh,
  priceHighToLow,
}

extension FoodSortOptionExtension on FoodSortOption {
  String get displayName {
    switch (this) {
      case FoodSortOption.nearest:
        return 'Nearest to Me';
      case FoodSortOption.rating:
        return 'Top Rated';
      case FoodSortOption.reviews:
        return 'Most Popular (Reviews)';
      case FoodSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case FoodSortOption.priceHighToLow:
        return 'Price: High to Low';
    }
  }

  IconData get icon {
    switch (this) {
      case FoodSortOption.nearest:
        return Icons.near_me_rounded;
      case FoodSortOption.rating:
        return Icons.star_rate_rounded;
      case FoodSortOption.reviews:
        return Icons.rate_review_rounded;
      case FoodSortOption.priceLowToHigh:
        return Icons.arrow_upward_rounded;
      case FoodSortOption.priceHighToLow:
        return Icons.arrow_downward_rounded;
    }
  }
}

/// Price tier indicators.
enum FoodPriceTier {
  budget,
  moderate,
  expensive,
  fineDining,
}

extension FoodPriceTierExtension on FoodPriceTier {
  String get symbol {
    switch (this) {
      case FoodPriceTier.budget:
        return 'PKR (Budget)';
      case FoodPriceTier.moderate:
        return 'PKR PKR (Moderate)';
      case FoodPriceTier.expensive:
        return 'PKR PKR PKR (Premium)';
      case FoodPriceTier.fineDining:
        return 'PKR PKR PKR PKR (Fine Dining)';
    }
  }
}

/// Comprehensive Food Place & Restaurant data model.
class FoodPlace {
  final String id;
  final String name;
  final FoodCategory category;
  final String cuisine;
  final double latitude;
  final double longitude;
  final String city;
  final String address;
  final String distance;
  final double distanceKm;
  final String estimatedTravelTime;
  final double rating;
  final int reviewCount;
  final FoodPriceTier priceTier;
  final int avgCostPerPersonPkr;
  final String imageUrl;
  final List<String> galleryImages;
  final bool isOpen;
  final String openingHours;
  final String phone;
  final List<String> specialties;
  final String description;
  final String? popularReview;
  final String landmarkNearby;
  final bool hasDineIn;
  final bool hasTakeaway;
  final bool hasDelivery;
  final String? directionsUrl;

  const FoodPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.cuisine,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.address,
    required this.distance,
    required this.distanceKm,
    required this.estimatedTravelTime,
    required this.rating,
    required this.reviewCount,
    required this.priceTier,
    required this.avgCostPerPersonPkr,
    required this.imageUrl,
    this.galleryImages = const [],
    this.isOpen = true,
    required this.openingHours,
    required this.phone,
    required this.specialties,
    required this.description,
    this.popularReview,
    required this.landmarkNearby,
    this.hasDineIn = true,
    this.hasTakeaway = true,
    this.hasDelivery = false,
    this.directionsUrl,
  });

  /// Formatted cost per person (e.g. "PKR 1,500 / person").
  String get formattedCost {
    final costStr = avgCostPerPersonPkr.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return 'PKR $costStr / person';
  }

  /// Create a copy with updated distances for the user's active GPS coordinates.
  FoodPlace copyWithDistance({
    required double newDistanceKm,
    required String newDistance,
    required String newTravelTime,
  }) {
    return FoodPlace(
      id: id,
      name: name,
      category: category,
      cuisine: cuisine,
      latitude: latitude,
      longitude: longitude,
      city: city,
      address: address,
      distance: newDistance,
      distanceKm: newDistanceKm,
      estimatedTravelTime: newTravelTime,
      rating: rating,
      reviewCount: reviewCount,
      priceTier: priceTier,
      avgCostPerPersonPkr: avgCostPerPersonPkr,
      imageUrl: imageUrl,
      galleryImages: galleryImages,
      isOpen: isOpen,
      openingHours: openingHours,
      phone: phone,
      specialties: specialties,
      description: description,
      popularReview: popularReview,
      landmarkNearby: landmarkNearby,
      hasDineIn: hasDineIn,
      hasTakeaway: hasTakeaway,
      hasDelivery: hasDelivery,
    );
  }

  factory FoodPlace.fromJson(Map<String, dynamic> json) {
    return FoodPlace(
      id: json['id'] as String? ?? 'FOOD-${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Pakistani Food Spot',
      category: _parseCategory(json['category'] as String?),
      cuisine: json['cuisine'] as String? ?? 'Desi / Pakistani',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 33.6844,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 73.0479,
      city: json['city'] as String? ?? 'Islamabad',
      address: json['address'] as String? ?? '',
      distance: json['distance'] as String? ?? (json['distance_km'] != null ? '${json['distance_km']} km' : 'Nearby'),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? (json['distance_km'] as num?)?.toDouble() ?? 1.0,
      estimatedTravelTime: json['estimatedTravelTime'] as String? ?? (json['eta_minutes'] != null ? '${json['eta_minutes']} mins' : '5 mins'),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? (json['reviews_count'] as num?)?.toInt() ?? 120,
      priceTier: _parsePriceTier(json['priceTier'] as String? ?? json['price_tier'] as String?),
      avgCostPerPersonPkr: (json['avgCostPerPersonPkr'] as num?)?.toInt() ?? (json['avg_cost_per_person_pkr'] as num?)?.toInt() ?? 1000,
      imageUrl: json['imageUrl'] as String? ?? json['image_url'] as String? ?? '',
      galleryImages: (json['galleryImages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isOpen: json['isOpen'] as bool? ?? json['is_open'] as bool? ?? true,
      openingHours: json['openingHours'] as String? ?? json['opening_hours'] as String? ?? '12:00 PM - 12:00 AM',
      phone: json['phone'] as String? ?? '+92-51-111-111-111',
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Special Karahi', 'Hot Naan'],
      description: json['description'] as String? ?? '',
      popularReview: json['popularReview'] as String? ?? json['popular_review'] as String?,
      landmarkNearby: json['landmarkNearby'] as String? ?? json['landmark_nearby'] as String? ?? '',
      hasDineIn: json['hasDineIn'] as bool? ?? true,
      hasTakeaway: json['hasTakeaway'] as bool? ?? true,
      hasDelivery: json['hasDelivery'] as bool? ?? false,
      directionsUrl: json['directions_url'] as String? ?? json['directionsUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'cuisine': cuisine,
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'address': address,
      'distance': distance,
      'distanceKm': distanceKm,
      'estimatedTravelTime': estimatedTravelTime,
      'rating': rating,
      'reviewCount': reviewCount,
      'priceTier': priceTier.name,
      'avgCostPerPersonPkr': avgCostPerPersonPkr,
      'imageUrl': imageUrl,
      'galleryImages': galleryImages,
      'isOpen': isOpen,
      'openingHours': openingHours,
      'phone': phone,
      'specialties': specialties,
      'description': description,
      'popularReview': popularReview,
      'landmarkNearby': landmarkNearby,
      'hasDineIn': hasDineIn,
      'hasTakeaway': hasTakeaway,
      'hasDelivery': hasDelivery,
    };
  }

  static FoodCategory _parseCategory(String? raw) {
    if (raw == null) return FoodCategory.desiPakistani;
    return FoodCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => FoodCategory.desiPakistani,
    );
  }

  static FoodPriceTier _parsePriceTier(String? raw) {
    if (raw == null) return FoodPriceTier.moderate;
    return FoodPriceTier.values.firstWhere(
      (p) => p.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => FoodPriceTier.moderate,
    );
  }
}
