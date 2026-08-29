import 'dart:async';
import 'package:flutter/material.dart';
import '../models/hotel_model.dart';
import 'hotel_location_service.dart';

/// Abstract Data Provider contract for hotel discovery.
/// Enables seamless drop-in replacements for Google Places API, Booking.com API,
/// or custom Flask / Node.js backend endpoints without UI rewrites.
abstract class HotelDataProvider {
  Future<List<Hotel>> fetchHotels({
    String? city,
    HotelCategory? category,
    String? searchQuery,
    double? userLat,
    double? userLng,
    int? maxPrice,
  });

  List<String> getSupportedCities();
}

/// Curated offline & demo data provider featuring premier hotels, resorts,
/// boutique lodges, and heritage palaces across Pakistan.
class CuratedHotelDataProvider implements HotelDataProvider {
  static const List<Hotel> _dataset = [
    // ── ISLAMABAD ──
    Hotel(
      id: 'HTL-SERENA-ISB',
      name: 'Islamabad Serena Hotel',
      category: HotelCategory.luxury,
      latitude: 33.7126,
      longitude: 73.0964,
      city: 'Islamabad',
      address: 'Opposite Convention Centre, Khayaban-e-Suhrawardy, Islamabad',
      distance: '1.2 km',
      distanceKm: 1.2,
      estimatedTravelTime: '4 mins',
      rating: 4.9,
      reviewCount: 3840,
      pricePerNightPkr: 55000,
      imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800&q=80',
        'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800&q=80',
      ],
      isAvailable: true,
      phone: '+92-51-2874000',
      website: 'https://www.serenahotels.com/serena-islamabad',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.swimmingPool,
        HotelAmenity.spaWellness,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.airportShuttle,
        HotelAmenity.roomService,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'Set amidst 14 acres of lush gardens with sweeping views of the Margalla Hills and Rawal Lake, Serena Islamabad combines traditional Islamic architecture with five-star luxury.',
      popularReviewSnippet:
          'World-class hospitality, magnificent traditional interior architecture, and exquisite buffet at Zamana restaurant.',
      landmarkNearby: 'Rawal Lake & Margalla National Park',
    ),
    Hotel(
      id: 'HTL-MARRIOTT-ISB',
      name: 'Islamabad Marriott Hotel',
      category: HotelCategory.luxury,
      latitude: 33.7250,
      longitude: 73.0880,
      city: 'Islamabad',
      address: 'Aga Khan Road, Shalimar 5, Sector F-5/1, Islamabad',
      distance: '2.0 km',
      distanceKm: 2.0,
      estimatedTravelTime: '6 mins',
      rating: 4.7,
      reviewCount: 2950,
      pricePerNightPkr: 42000,
      imageUrl: 'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800&q=80',
      ],
      isAvailable: true,
      phone: '+92-51-2826121',
      website: 'https://www.marriott.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.swimmingPool,
        HotelAmenity.spaWellness,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.airportShuttle,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'Located in the prestigious diplomatic enclave foot of the Margalla Hills, Marriott Islamabad offers contemporary guest rooms, signature dining, and state-of-the-art wellness facilities.',
      popularReviewSnippet:
          'Exceptional central security, grand lobby ambiance, and outstanding Chinese dining at Dynasty.',
      landmarkNearby: 'Diplomatic Enclave & Supreme Court',
    ),
    Hotel(
      id: 'HTL-HIGHLAND-ISB',
      name: 'Highland Country Club & Resort',
      category: HotelCategory.resort,
      latitude: 33.8050,
      longitude: 73.1350,
      city: 'Islamabad',
      address: 'Pir Sohawa Road, Sangada, Margalla Hills, Islamabad',
      distance: '14.5 km',
      distanceKm: 14.5,
      estimatedTravelTime: '28 mins',
      rating: 4.6,
      reviewCount: 1680,
      pricePerNightPkr: 28000,
      imageUrl: 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-311-1444100',
      website: 'https://highlandresort.com.pk',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.bonfireArea,
        HotelAmenity.tourDesk,
        HotelAmenity.freeParking,
      ],
      description:
          'Perched at an elevation of 4,500 feet atop the scenic Margalla Ridge, Highland Resort offers cool mountain breezes, luxury cottages, and panoramic valley views.',
      popularReviewSnippet:
          'Breathtaking sunrise views over the clouds. The bonfire and live BBQ evenings are unforgettable.',
      landmarkNearby: 'Monal Viewpoint & Trail 5 Ridge',
    ),

    // ── HUNZA VALLEY ──
    Hotel(
      id: 'HTL-LUXUS-HUNZA',
      name: 'Luxus Hunza Attabad Lake Resort',
      category: HotelCategory.resort,
      latitude: 36.3350,
      longitude: 74.8650,
      city: 'Hunza',
      address: 'Karakoram Highway, Ainabad, Attabad Lake, Hunza Valley',
      distance: '0.8 km',
      distanceKm: 0.8,
      estimatedTravelTime: '3 mins',
      rating: 4.9,
      reviewCount: 2150,
      pricePerNightPkr: 48000,
      imageUrl: 'https://images.unsplash.com/photo-1540541338287-41700207dee6?w=800&q=80',
      galleryImages: [
        'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800&q=80',
      ],
      isAvailable: true,
      phone: '+92-300-0589871',
      website: 'https://luxushunza.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.bonfireArea,
        HotelAmenity.tourDesk,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'An ultra-premium lakefront boutique resort situated directly on the turquoise waters of Attabad Lake. Features private balconies facing glacier peaks.',
      popularReviewSnippet:
          'Waking up to the glowing blue waters of Attabad Lake directly from the bed is magical. Outstanding service in the mountains.',
      landmarkNearby: 'Attabad Lake Jet Ski & Boating Dock',
    ),
    Hotel(
      id: 'HTL-SERENA-HUNZA',
      name: 'Hunza Serena Inn',
      category: HotelCategory.boutique,
      latitude: 36.3260,
      longitude: 74.6640,
      city: 'Hunza',
      address: 'Zero Point, Karimabad, Hunza Valley, Gilgit-Baltistan',
      distance: '1.5 km',
      distanceKm: 1.5,
      estimatedTravelTime: '5 mins',
      rating: 4.8,
      reviewCount: 1920,
      pricePerNightPkr: 38000,
      imageUrl: 'https://images.unsplash.com/photo-1568084680786-a84f91d1153c?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-5813-457660',
      website: 'https://www.serenahotels.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.tourDesk,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'Overlooking the ancient Baltit Fort with uninterrupted views of Ultar Sar and Ladyfinger Peak. Built with local timber and stone architecture.',
      popularReviewSnippet:
          'Terrace views of Rakaposhi and Ultar are breathtaking. The local apricot cake and walnut bread at breakfast are delicious.',
      landmarkNearby: 'Historic Baltit Fort & Karimabad Bazaar',
    ),
    Hotel(
      id: 'HTL-HARDROCK-HUNZA',
      name: 'Hard Rock Hunza Resort & Villas',
      category: HotelCategory.boutique,
      latitude: 36.3190,
      longitude: 74.6520,
      city: 'Hunza',
      address: 'Eagle\'s Nest Road, Duikar, Hunza Valley',
      distance: '3.2 km',
      distanceKm: 3.2,
      estimatedTravelTime: '9 mins',
      rating: 4.7,
      reviewCount: 1140,
      pricePerNightPkr: 26000,
      imageUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-345-5007000',
      website: 'https://hardrockhunza.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.bonfireArea,
        HotelAmenity.heatingAc,
      ],
      description:
          'Located at the highest viewpoint in Duikar, famous for 360-degree golden hour sunrises and sunsets over eight 7,000m peaks.',
      popularReviewSnippet:
          'The viewpoint from the cliffside deck offers one of the greatest vistas on Earth.',
      landmarkNearby: 'Duikar Eagles Nest Sunrise Point',
    ),

    // ── SKARDU & BALTISTAN ──
    Hotel(
      id: 'HTL-SHANGRILA-SKD',
      name: 'Shangrila Resort Skardu (Heaven on Earth)',
      category: HotelCategory.resort,
      latitude: 35.4220,
      longitude: 75.3620,
      city: 'Skardu',
      address: 'Lower Kachura Lake, Shangrila, Skardu, Gilgit-Baltistan',
      distance: '1.8 km',
      distanceKm: 1.8,
      estimatedTravelTime: '6 mins',
      rating: 4.9,
      reviewCount: 3410,
      pricePerNightPkr: 45000,
      imageUrl: 'https://images.unsplash.com/photo-1506059612708-99d6c258160e?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-5815-454941',
      website: 'https://shangrilaresorts.com.pk',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.airportShuttle,
        HotelAmenity.tourDesk,
        HotelAmenity.freeParking,
      ],
      description:
          'Surrounding the legendary heart-shaped Lower Kachura Lake with Swiss-style red chalets, Pagoda restaurant, and aircraft lounge.',
      popularReviewSnippet:
          'An iconic paradise in Pakistan. The cherry blossoms and mirror lake reflection in autumn and spring are unmatched.',
      landmarkNearby: 'Lower Kachura Lake & Upper Kachura Lake',
    ),
    Hotel(
      id: 'HTL-SHIGAR-SKD',
      name: 'Serena Shigar Fort (Fong-Khar Palace)',
      category: HotelCategory.boutique,
      latitude: 35.4270,
      longitude: 75.7480,
      city: 'Skardu',
      address: 'Shigar Valley, 30 km from Skardu, Gilgit-Baltistan',
      distance: '28.0 km',
      distanceKm: 28.0,
      estimatedTravelTime: '40 mins',
      rating: 4.9,
      reviewCount: 1520,
      pricePerNightPkr: 39000,
      imageUrl: 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-5815-460100',
      website: 'https://www.serenahotels.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.tourDesk,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'A 400-year-old restored Raja palace on the route to K2. Guests sleep in genuine royal chambers curated with antique wooden craftsmanship.',
      popularReviewSnippet:
          'Living in a 17th-century Tibetan-Balti fort palace with babbling streams and fruit orchards. Absolutely extraordinary.',
      landmarkNearby: 'Blind Lake & Cold Desert Shigar',
    ),
    Hotel(
      id: 'HTL-GLAMPING-SKD',
      name: 'Katpana Desert Luxury Glamping & Camps',
      category: HotelCategory.glamping,
      latitude: 35.3210,
      longitude: 75.6020,
      city: 'Skardu',
      address: 'Cold Desert Katpana Dunes, Skardu',
      distance: '4.5 km',
      distanceKm: 4.5,
      estimatedTravelTime: '12 mins',
      rating: 4.6,
      reviewCount: 870,
      pricePerNightPkr: 18000,
      imageUrl: 'https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-344-9988771',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.bonfireArea,
        HotelAmenity.freeBreakfast,
        HotelAmenity.tourDesk,
        HotelAmenity.freeParking,
      ],
      description:
          'Experience the surreal High-Altitude Cold Desert in heated luxury dome tents with astronomical stargazing skylights and evening musical campfires.',
      popularReviewSnippet:
          'The Milky Way visibility at night from the sand dunes surrounded by snow peaks is magical.',
      landmarkNearby: 'Katpana Cold Desert & Dunes',
    ),

    // ── SWAT & KALAM ──
    Hotel(
      id: 'HTL-WALNUT-KALAM',
      name: 'Walnut Heights Resort Kalam',
      category: HotelCategory.resort,
      latitude: 35.4940,
      longitude: 72.5920,
      city: 'Kalam',
      address: 'Jalban, Upper Kalam Valley, Swat, Khyber Pakhtunkhwa',
      distance: '2.1 km',
      distanceKm: 2.1,
      estimatedTravelTime: '7 mins',
      rating: 4.8,
      reviewCount: 1450,
      pricePerNightPkr: 24000,
      imageUrl: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-333-5154321',
      website: 'https://walnutheights.com.pk',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.bonfireArea,
        HotelAmenity.tourDesk,
        HotelAmenity.freeParking,
      ],
      description:
          'Nestled among dense pine forests and walnut trees overlooking the roaring Swat River, Walnut Heights offers timber chalets and pure alpine peace.',
      popularReviewSnippet:
          'Top-notch wooden cottages, sound of the river, and fresh trout fish dinner by the fireplace.',
      landmarkNearby: 'Kalam Forest & Ushu Valley Road',
    ),
    Hotel(
      id: 'HTL-SERENA-SWAT',
      name: 'Swat Serena Hotel',
      category: HotelCategory.boutique,
      latitude: 34.7720,
      longitude: 72.3610,
      city: 'Swat / Mingora',
      address: 'Amanabad, Opposite Golf Course, Saidu Sharif, Swat',
      distance: '1.4 km',
      distanceKm: 1.4,
      estimatedTravelTime: '5 mins',
      rating: 4.7,
      reviewCount: 2200,
      pricePerNightPkr: 32000,
      imageUrl: 'https://images.unsplash.com/photo-1549294413-26f195200c16?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-946-9240400',
      website: 'https://www.serenahotels.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.swimmingPool,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.tourDesk,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'Originally the private residence of the Wali of Swat, this colonial-era estate features sprawling rose gardens and royal hospitality.',
      popularReviewSnippet:
          'Historic colonial charm, heritage museum on site, and lush green gardens in the heart of Saidu Sharif.',
      landmarkNearby: 'Swat Museum & White Palace Marghazar',
    ),

    // ── NARAN & KAGHAN ──
    Hotel(
      id: 'HTL-PINEPARK-NARAN',
      name: 'Pine Park Glade Resort Kaghan',
      category: HotelCategory.resort,
      latitude: 34.7950,
      longitude: 73.5420,
      city: 'Naran / Kaghan',
      address: 'Shogran Plateau, Kaghan Valley, Khyber Pakhtunkhwa',
      distance: '3.6 km',
      distanceKm: 3.6,
      estimatedTravelTime: '11 mins',
      rating: 4.7,
      reviewCount: 1830,
      pricePerNightPkr: 22000,
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-300-5155822',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.mountainView,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.bonfireArea,
        HotelAmenity.tourDesk,
        HotelAmenity.freeParking,
      ],
      description:
          'Sprawled over lush pine lawns with uninterrupted views of Siri Paye Meadows and Makra Peak.',
      popularReviewSnippet:
          'Best resort in Shogran! The pine aroma, lawn tea, and jeep ride to Siri Paye made our trip memorable.',
      landmarkNearby: 'Siri Paye Meadows & Shogran Forest',
    ),

    // ── LAHORE ──
    Hotel(
      id: 'HTL-PC-LHR',
      name: 'Pearl Continental Hotel Lahore',
      category: HotelCategory.luxury,
      latitude: 31.5546,
      longitude: 74.3317,
      city: 'Lahore',
      address: 'Shahrah-e-Quaid-e-Azam, Mall Road, Lahore',
      distance: '1.9 km',
      distanceKm: 1.9,
      estimatedTravelTime: '6 mins',
      rating: 4.7,
      reviewCount: 4200,
      pricePerNightPkr: 38000,
      imageUrl: 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-42-111-505-505',
      website: 'https://www.pchotels.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.swimmingPool,
        HotelAmenity.spaWellness,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.airportShuttle,
        HotelAmenity.roomService,
        HotelAmenity.heatingAc,
        HotelAmenity.freeParking,
      ],
      description:
          'An iconic luxury landmark on historic Mall Road featuring regal Mughal decor, Bukhara BBQ, and premier city access.',
      popularReviewSnippet:
          'The live traditional music and Bukhara barbecue are unbeatable in Lahore.',
      landmarkNearby: 'Lahore Zoo, Mall Road & Bagh-e-Jinnah',
    ),
    Hotel(
      id: 'HTL-NISHAT-LHR',
      name: 'The Nishat Hotel Gulberg',
      category: HotelCategory.boutique,
      latitude: 31.5120,
      longitude: 74.3490,
      city: 'Lahore',
      address: '9A, Mian Mehmood Ali Kasoori Rd, Gulberg III, Lahore',
      distance: '2.5 km',
      distanceKm: 2.5,
      estimatedTravelTime: '8 mins',
      rating: 4.8,
      reviewCount: 2600,
      pricePerNightPkr: 34000,
      imageUrl: 'https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?w=800&q=80',
      galleryImages: [],
      isAvailable: true,
      phone: '+92-42-111-646-835',
      website: 'https://nishathotel.com',
      amenities: [
        HotelAmenity.freeWifi,
        HotelAmenity.swimmingPool,
        HotelAmenity.spaWellness,
        HotelAmenity.restaurant,
        HotelAmenity.freeBreakfast,
        HotelAmenity.airportShuttle,
        HotelAmenity.heatingAc,
      ],
      description:
          'Parisian-style boutique luxury situated in fashionable Gulberg with marble interiors, rooftop bistro, and bespoke service.',
      popularReviewSnippet:
          'Exquisite interior design, ultra-comfortable mattresses, and delicious Italian brunch.',
      landmarkNearby: 'MM Alam Road & Liberty Market',
    ),
  ];

  @override
  Future<List<Hotel>> fetchHotels({
    String? city,
    HotelCategory? category,
    String? searchQuery,
    double? userLat,
    double? userLng,
    int? maxPrice,
  }) async {
    // Realistic network simulation delay
    await Future.delayed(const Duration(milliseconds: 280));

    List<Hotel> results = List<Hotel>.from(_dataset);

    // Filter by City if specified
    if (city != null &&
        city.isNotEmpty &&
        city != 'All Locations' &&
        !city.contains('Current Location')) {
      results = results
          .where((h) => h.city.toLowerCase().contains(city.toLowerCase()))
          .toList();
    }

    // Filter by Category
    if (category != null && category != HotelCategory.all) {
      results = results.where((h) => h.category == category).toList();
    }

    // Filter by Max Price
    if (maxPrice != null && maxPrice > 0) {
      results = results.where((h) => h.pricePerNightPkr <= maxPrice).toList();
    }

    // Filter by Search Query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      results = results.where((h) {
        return h.name.toLowerCase().contains(q) ||
            h.address.toLowerCase().contains(q) ||
            h.city.toLowerCase().contains(q) ||
            h.landmarkNearby.toLowerCase().contains(q) ||
            h.description.toLowerCase().contains(q);
      }).toList();
    }

    // Recompute distances dynamically if user GPS coordinates provided
    if (userLat != null && userLng != null) {
      results = results.map((h) {
        final distKm = HotelLocationService.calculateDistanceKm(
          userLat,
          userLng,
          h.latitude,
          h.longitude,
        );
        final distStr = HotelLocationService.formatDistance(distKm);
        final timeStr = HotelLocationService.estimateTravelTime(distKm);
        return h.copyWithDistance(
          newDistanceKm: distKm,
          newDistance: distStr,
          newTravelTime: timeStr,
        );
      }).toList();
    }

    return results;
  }

  @override
  List<String> getSupportedCities() {
    return [
      'Current Location (GPS)',
      'All Locations',
      'Islamabad',
      'Hunza',
      'Skardu',
      'Kalam',
      'Swat / Mingora',
      'Naran / Kaghan',
      'Lahore',
      'Murree',
      'Gilgit',
      'Karachi',
    ];
  }
}

/// Central Hotel Service & Repository.
/// Handles high-level sorting, filtering, and data source coordination.
class HotelService {
  static HotelDataProvider _provider = CuratedHotelDataProvider();

  /// Inject an alternative data provider (e.g. Google Places API or Flask backend).
  static void setProvider(HotelDataProvider provider) {
    _provider = provider;
  }

  /// Get list of supported cities/regions.
  static List<String> getAvailableCities() {
    return _provider.getSupportedCities();
  }

  /// Fetch and sort hotels according to traveler preferences.
  static Future<List<Hotel>> getHotels({
    String? city,
    HotelCategory? category,
    HotelSortOption sortBy = HotelSortOption.nearness,
    String? searchQuery,
    double? userLat,
    double? userLng,
    int? maxPrice,
  }) async {
    try {
      final list = await _provider.fetchHotels(
        city: city,
        category: category,
        searchQuery: searchQuery,
        userLat: userLat,
        userLng: userLng,
        maxPrice: maxPrice,
      );

      // Apply sorting
      switch (sortBy) {
        case HotelSortOption.nearness:
          list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          break;
        case HotelSortOption.rating:
          list.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case HotelSortOption.reviews:
          list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
          break;
        case HotelSortOption.priceLowToHigh:
          list.sort((a, b) => a.pricePerNightPkr.compareTo(b.pricePerNightPkr));
          break;
        case HotelSortOption.priceHighToLow:
          list.sort((a, b) => b.pricePerNightPkr.compareTo(a.pricePerNightPkr));
          break;
      }

      return list;
    } catch (e, stackTrace) {
      debugPrint('HOTEL SERVICE ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
