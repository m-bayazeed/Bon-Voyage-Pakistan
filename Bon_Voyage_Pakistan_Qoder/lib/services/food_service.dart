import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/food_place_model.dart';
import 'hotel_location_service.dart';

/// Abstract interface for food & dining data providers.
abstract class FoodDataProvider {
  Future<List<FoodPlace>> fetchFoodPlaces({
    String? city,
    double? userLat,
    double? userLng,
    FoodCategory? category,
    String? query,
  });

  List<String> getSupportedCities();
}

/// Rich curated offline provider featuring authentic Pakistani culinary landmarks.
class CuratedFoodDataProvider implements FoodDataProvider {
  @override
  List<String> getSupportedCities() => const [
        'Islamabad',
        'Lahore',
        'Karachi',
        'Hunza Valley',
        'Skardu',
        'Swat & Kalam',
        'Naran & Kaghan',
        'Murree & Galiyat',
        'Peshawar',
        'Quetta & Ziarat',
        'Multan',
      ];

  static final List<FoodPlace> _allFoodPlaces = [
    // ══════════════════════════════════════════════════════════
    // ISLAMABAD & RAWALPINDI
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-ISB-001',
      name: 'The Monal Restaurant',
      category: FoodCategory.fineDining,
      cuisine: 'Mughlai BBQ, Shinwari Karahi & Continental',
      latitude: 33.7485,
      longitude: 73.0645,
      city: 'Islamabad',
      address: 'Daman-e-Koh Road, Pir Sohawa, Margalla Hills, Islamabad',
      distance: '3.2 km',
      distanceKm: 3.2,
      estimatedTravelTime: '12 mins',
      rating: 4.8,
      reviewCount: 14200,
      priceTier: FoodPriceTier.expensive,
      avgCostPerPersonPkr: 3200,
      imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '09:00 AM - 01:00 AM',
      phone: '+92-51-5837230',
      specialties: ['Mutton Shinwari Karahi', 'Chicken Reshmi Kabab', 'Monal Cheese Naan', 'Sizzling Brownie'],
      description:
          'Perched high in the Margalla Hills with a breathtaking panoramic view of Islamabad, offering premier Pakistani BBQ and live cooking stations.',
      popularReview:
          '"Unrivalled twilight mountain breeze and sensational Mutton Karahi cooked in fresh desi butter. An essential Pakistan culinary experience!"',
      landmarkNearby: 'Pir Sohawa Viewpoint',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),
    FoodPlace(
      id: 'FOOD-ISB-002',
      name: 'Kabul Restaurant F-7',
      category: FoodCategory.desiPakistani,
      cuisine: 'Authentic Afghani Tikka, Kabuli Pulao & Dum Pukht',
      latitude: 33.7210,
      longitude: 73.0560,
      city: 'Islamabad',
      address: 'College Road, Markaz F-7, Islamabad',
      distance: '1.8 km',
      distanceKm: 1.8,
      estimatedTravelTime: '6 mins',
      rating: 4.7,
      reviewCount: 8900,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1600,
      imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '11:30 AM - 12:00 AM',
      phone: '+92-51-2650953',
      specialties: ['Special Kabuli Pulao with Raisins & Carrots', 'Afghani Boti Skewers', 'Mantu Dumplings', 'Dumba Karahi'],
      description:
          'Legendary Markaz eatery famous for authentic Afghani gastronomy, tender charcoal meat skewers, and fragrant saffron rice.',
      popularReview: '"Tender, melt-in-mouth Afghani boti and perfectly spiced Kabuli Pulao. Very generous portions!"',
      landmarkNearby: 'Jinnah Super Market (F-7 Markaz)',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),
    FoodPlace(
      id: 'FOOD-ISB-003',
      name: 'Chaaye Khana F-6',
      category: FoodCategory.cafe,
      cuisine: 'Artisan Chai, Specialty Teas, Bakery & High Tea',
      latitude: 33.7298,
      longitude: 73.0760,
      city: 'Islamabad',
      address: 'Shop 11, Super Market, F-6 Markaz, Islamabad',
      distance: '2.5 km',
      distanceKm: 2.5,
      estimatedTravelTime: '8 mins',
      rating: 4.6,
      reviewCount: 6500,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1200,
      imageUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '08:00 AM - 12:00 AM',
      phone: '+92-51-8312192',
      specialties: ['Peshawari Kahwa', 'Karak Doodh Patti', 'Chicken Mushroom Crepes', 'Nutella French Toast'],
      description:
          'A cultured tea lounge offering over 70 varieties of global teas, freshly baked pastries, book corners, and cozy conversation spaces.',
      popularReview: '"The gold standard for evening chai in the capital with a wonderful book-lounge vibe."',
      landmarkNearby: 'Super Market F-6',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),
    FoodPlace(
      id: 'FOOD-ISB-004',
      name: 'Savour Foods Blue Area',
      category: FoodCategory.biryani,
      cuisine: 'Traditional Murgh Pulao, Shami Kabab & Roast',
      latitude: 33.7120,
      longitude: 73.0680,
      city: 'Islamabad',
      address: 'Fortune Arcade, Blue Area, Islamabad',
      distance: '2.1 km',
      distanceKm: 2.1,
      estimatedTravelTime: '7 mins',
      rating: 4.7,
      reviewCount: 19400,
      priceTier: FoodPriceTier.budget,
      avgCostPerPersonPkr: 550,
      imageUrl: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '11:00 AM - 01:00 AM',
      phone: '+92-51-2348007',
      specialties: ['Special Murgh Pulao with 2 Shami Kababs', 'Crispy Chicken Roast', 'Zarda Sweet Rice'],
      description:
          'Islamabad and Rawalpindi’s most iconic budget feast. Known for lightning-fast service, steaming spiced pulao, and signature chicken roast.',
      popularReview: '"Crisp chicken, fragrant brown pulao, and silky shami kababs at an unbeatable price point."',
      landmarkNearby: 'Blue Area Metro Station',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),

    // ══════════════════════════════════════════════════════════
    // LAHORE
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-LHE-001',
      name: 'Butt Karahi Lakshmi Chowk',
      category: FoodCategory.desiPakistani,
      cuisine: 'Desi Ghee Mutton Karahi, Brain Masala & Naan',
      latitude: 31.5645,
      longitude: 74.3210,
      city: 'Lahore',
      address: 'Lakshmi Chowk, McLeod Road, Lahore',
      distance: '3.6 km',
      distanceKm: 3.6,
      estimatedTravelTime: '14 mins',
      rating: 4.8,
      reviewCount: 22000,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 2200,
      imageUrl: 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '05:00 PM - 03:00 AM',
      phone: '+92-42-37358156',
      specialties: ['Organic Desi Ghee Mutton Karahi', 'Maghaz (Brain) Masala', 'Sesame Roghni Naan', 'Fresh Lassi'],
      description:
          'The world-famous heart of Lahori food culture, sizzling tender goat meat in pure golden desi ghee and freshly crushed spices over roaring flames.',
      popularReview: '"Unquestionably the best Mutton Karahi on earth. Rich, aromatic, and cooked right in front of you!"',
      landmarkNearby: 'Lakshmi Chowk Heritage Square',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),
    FoodPlace(
      id: 'FOOD-LHE-002',
      name: 'Haveli Restaurant Fort Road',
      category: FoodCategory.fineDining,
      cuisine: 'Mughlai BBQ, Royal Karahi & Traditional Sweets',
      latitude: 31.5890,
      longitude: 74.3160,
      city: 'Lahore',
      address: '2170/A Food Street, Fort Road, Old City, Lahore',
      distance: '4.8 km',
      distanceKm: 4.8,
      estimatedTravelTime: '18 mins',
      rating: 4.9,
      reviewCount: 16500,
      priceTier: FoodPriceTier.expensive,
      avgCostPerPersonPkr: 2800,
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '01:00 PM - 01:00 AM',
      phone: '+92-42-37637864',
      specialties: ['Mutton Champ Masala', 'Badshahi BBQ Platter', 'Tandoori Murgh Sajji', 'Kheer in Clay Pots'],
      description:
          'Dine on the rooftop of a restored 18th-century Haveli directly opposite the grand illuminated domes and minarets of Badshahi Mosque.',
      popularReview: '"A magical sensory feast! Eating juicy charcoal tandoori chops while gazing directly at Badshahi Mosque."',
      landmarkNearby: 'Badshahi Mosque & Shahi Qila',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),
    FoodPlace(
      id: 'FOOD-LHE-003',
      name: 'Waris Nihari House',
      category: FoodCategory.traditionalLocal,
      cuisine: 'Slow-Cooked Beef & Mutton Nalli Nihari',
      latitude: 31.5710,
      longitude: 74.3180,
      city: 'Lahore',
      address: '7 Abkari Road, New Anarkali Bazaar, Lahore',
      distance: '4.0 km',
      distanceKm: 4.0,
      estimatedTravelTime: '15 mins',
      rating: 4.7,
      reviewCount: 11200,
      priceTier: FoodPriceTier.budget,
      avgCostPerPersonPkr: 850,
      imageUrl: 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '06:00 AM - 12:00 PM & 06:00 PM - 11:00 PM',
      phone: '+92-42-37351659',
      specialties: ['Special Nalli (Bone Marrow) Nihari', 'Maghaz Nihari', 'Tandoori Kulcha Naan', 'Ginger Chili Garnish'],
      description:
          'Simmered overnight in huge copper cauldrons with secret royal spice blends, Waris Nihari is the undisputed breakfast king of Old Lahore.',
      popularReview: '"Rich marrow broth topped with fresh ginger slivers and lime juice, scooped with blistered kulchas."',
      landmarkNearby: 'Anarkali Bazaar',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),

    // ══════════════════════════════════════════════════════════
    // KARACHI
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-KHI-001',
      name: 'Kolachi Restaurant Do Darya',
      category: FoodCategory.fineDining,
      cuisine: 'Coastal Seafood, Malai Tikka & Sajji',
      latitude: 24.7720,
      longitude: 67.0780,
      city: 'Karachi',
      address: 'Creak Side, Phase 8, DHA Do Darya, Karachi',
      distance: '6.5 km',
      distanceKm: 6.5,
      estimatedTravelTime: '22 mins',
      rating: 4.9,
      reviewCount: 28000,
      priceTier: FoodPriceTier.expensive,
      avgCostPerPersonPkr: 3500,
      imageUrl: 'https://images.unsplash.com/photo-1578474846511-04ba529f0b88?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '07:00 PM - 02:00 AM',
      phone: '+92-21-111-111-001',
      specialties: ['Fish Tikka Grilled on Open Coals', 'Kolachi Special Karahi', 'Chicken Makhni Handi', 'Garlic Naan'],
      description:
          'Karachi’s crown jewel waterfront dining on wooden decks extended directly over the Arabian Sea waves with sea breezes and gourmet seafood.',
      popularReview: '"Unbeatable seaside atmosphere, gentle ocean breeze, and the finest Grilled Fish Tikka in South Asia."',
      landmarkNearby: 'Do Darya Promenade',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),
    FoodPlace(
      id: 'FOOD-KHI-002',
      name: 'Al-Rehman Biryani Saddar',
      category: FoodCategory.biryani,
      cuisine: 'Spicy Karachi Dum Biryani & Pulao',
      latitude: 24.8580,
      longitude: 67.0190,
      city: 'Karachi',
      address: 'Haji Adam Chamber, Altaf Hussain Road, Saddar, Karachi',
      distance: '3.1 km',
      distanceKm: 3.1,
      estimatedTravelTime: '12 mins',
      rating: 4.8,
      reviewCount: 17500,
      priceTier: FoodPriceTier.budget,
      avgCostPerPersonPkr: 600,
      imageUrl: 'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '12:00 PM - 11:30 PM',
      phone: '+92-21-32215887',
      specialties: ['Special Double Aloo Beef Biryani', 'Chicken Dum Biryani', 'Mint Raita & Salad'],
      description:
          'The ultimate destination for authentic spicy Karachi-style dum biryani with long grain basmati rice, tender spiced meat, and juicy potatoes.',
      popularReview: '"The genuine flavor of Karachi! Intense spices, perfectly seasoned potatoes, and fluffy separate rice grains."',
      landmarkNearby: 'Empress Market Saddar',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),
    FoodPlace(
      id: 'FOOD-KHI-003',
      name: 'Waheed Kabab House Burns Road',
      category: FoodCategory.bbq,
      cuisine: 'Burns Road Fry Kabab, Dhaga Kabab & Bihari Boti',
      latitude: 24.8620,
      longitude: 67.0210,
      city: 'Karachi',
      address: 'Burns Road Food Street, Saddar, Karachi',
      distance: '3.4 km',
      distanceKm: 3.4,
      estimatedTravelTime: '14 mins',
      rating: 4.7,
      reviewCount: 13800,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1100,
      imageUrl: 'https://images.unsplash.com/photo-1529193591184-b1d58069ecdd?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '06:00 PM - 03:00 AM',
      phone: '+92-21-32631247',
      specialties: ['Beef Fry Kabab in Pure Desi Ghee', 'Dhaga Kabab', 'Spicy Nihari', 'Poori Paratha'],
      description:
          'Located in Karachi’s historic food heartland, world-renowned for silky smoked fry kababs sautéed in sizzling butter over cast iron griddles.',
      popularReview: '"Silky Fry Kababs paired with crisp piping hot poori parathas. Pure late-night Karachi heritage."',
      landmarkNearby: 'Burns Road Heritage Street',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),

    // ══════════════════════════════════════════════════════════
    // HUNZA & GILGIT
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-HNZ-001',
      name: 'Yak Grill Passu',
      category: FoodCategory.bbq,
      cuisine: 'Organic Yak Burgers, Yak Steaks & Local Apricot Tea',
      latitude: 36.4710,
      longitude: 74.8890,
      city: 'Hunza Valley',
      address: 'Karakoram Highway (KKH), Passu Village, Upper Hunza',
      distance: '2.4 km',
      distanceKm: 2.4,
      estimatedTravelTime: '8 mins',
      rating: 4.9,
      reviewCount: 3200,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1800,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '11:00 AM - 10:00 PM',
      phone: '+92-346-5238190',
      specialties: ['Juicy Grass-Fed Yak Burger', 'Yak Ribeye Steak', 'Passu Herb Fries', 'Apricot Blossom Tea'],
      description:
          'Famous roadside grill right under the dramatic Passu Cones, pioneering organic yak meat burgers seasoned with mountain herbs and cheese.',
      popularReview: '"Unbelievably juicy Yak Burger with majestic needle peaks of Passu towering right in front of your table!"',
      landmarkNearby: 'Passu Cones Cathedral Ridge',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),
    FoodPlace(
      id: 'FOOD-HNZ-002',
      name: 'Cafe de Hunza',
      category: FoodCategory.cafe,
      cuisine: 'Fresh Walnut Cake, Artisan Espresso & Apricot Juices',
      latitude: 36.3260,
      longitude: 74.6640,
      city: 'Hunza Valley',
      address: 'Baltit Fort Road, Karimabad Bazaar, Central Hunza',
      distance: '1.2 km',
      distanceKm: 1.2,
      estimatedTravelTime: '5 mins',
      rating: 4.8,
      reviewCount: 4600,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 950,
      imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '08:30 AM - 10:30 PM',
      phone: '+92-5813-457090',
      specialties: ['Signature Hunza Honey Walnut Cake', 'Italian Roast Cappuccino', 'Organic Apricot Smoothie', 'Buckwheat Pancakes'],
      description:
          'The pioneering coffee shop of the Northern areas with an open balcony looking out onto Rakaposhi and Ultar Sar snow summits.',
      popularReview: '"Warm Honey Walnut Cake and hot latte after trekking to Baltit Fort. A legendary traveler sanctuary."',
      landmarkNearby: 'Baltit Fort Heritage Walk',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),
    FoodPlace(
      id: 'FOOD-HNZ-003',
      name: 'Hidden Paradise Hunza Cuisine',
      category: FoodCategory.traditionalLocal,
      cuisine: 'Traditional Wakhi & Burushaski Organic Dishes',
      latitude: 36.3245,
      longitude: 74.6655,
      city: 'Hunza Valley',
      address: 'Karimabad Village Walk, Hunza',
      distance: '1.5 km',
      distanceKm: 1.5,
      estimatedTravelTime: '6 mins',
      rating: 4.7,
      reviewCount: 2100,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1400,
      imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '12:00 PM - 09:30 PM',
      phone: '+92-5813-457310',
      specialties: ['Authentic Chapshuro (Hunza Meat Pie)', 'Gyal (Buckwheat Bread with Apricot Oil)', 'Diram Fitti', 'Tumuro Herb Tea'],
      description:
          'Authentic heritage eatery preserving 1,000-year-old culinary traditions of longevity, prepared with whole grains, apricot kernel oil, and mountain herbs.',
      popularReview: '"Crisp piping hot Chapshuro filled with spiced mince and fresh spring onions. Healthy and so comforting."',
      landmarkNearby: 'Karimabad Craft Bazaar',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),

    // ══════════════════════════════════════════════════════════
    // SKARDU & BALTISTAN
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-SKD-001',
      name: 'Dewan-e-Khas Restaurant Skardu',
      category: FoodCategory.familyDining,
      cuisine: 'Balti Cuisine, Freshwater Trout & Desi Karahi',
      latitude: 35.2980,
      longitude: 75.6320,
      city: 'Skardu',
      address: 'Kazmi Bazaar, Main Skardu City, Gilgit-Baltistan',
      distance: '1.1 km',
      distanceKm: 1.1,
      estimatedTravelTime: '4 mins',
      rating: 4.7,
      reviewCount: 3800,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1500,
      imageUrl: 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '11:00 AM - 11:00 PM',
      phone: '+92-5815-452180',
      specialties: ['Pan-Fried Indus Trout Fish', 'Balti Mamtu Dumplings', 'Prapu Noodle Soup', 'Mutton Shinwari Handi'],
      description:
          'Skardu’s highest-rated family gathering point, serving fresh mountain river trout and traditional Balti specialties after expeditions to K2 and Deosai.',
      popularReview: '"Crispy skinned trout from the crystal cold streams paired with steaming garlic naan. Exceptional hospitality!"',
      landmarkNearby: 'Skardu Polo Ground',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),

    // ══════════════════════════════════════════════════════════
    // SWAT & KALAM
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-SWT-001',
      name: 'Fizagat Trout Park & BBQ',
      category: FoodCategory.desiPakistani,
      cuisine: 'Swat River Fresh Trout, Chapli Kabab & Shinwari',
      latitude: 34.7890,
      longitude: 72.3680,
      city: 'Swat & Kalam',
      address: 'Fizagat Riverside Park, Kalam Highway, Mingora, Swat',
      distance: '2.0 km',
      distanceKm: 2.0,
      estimatedTravelTime: '7 mins',
      rating: 4.8,
      reviewCount: 5200,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 1600,
      imageUrl: 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '10:00 AM - 11:30 PM',
      phone: '+92-946-724110',
      specialties: ['Grilled Swat River Trout', 'Peshawari Chappal Kabab', 'Mutton Karahi with Green Chilies', 'Lassi & Kahwa'],
      description:
          'Open-air riverside dining along the rushing emerald waters of the Swat River, renowned for live trout picking and charcoal grilling.',
      popularReview: '"Select your live trout from the clear mountain pond and have it grilled to perfection with Swat pomegranate seeds."',
      landmarkNearby: 'Fizagat Riverside Park',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: false,
    ),

    // ══════════════════════════════════════════════════════════
    // PESHAWAR
    // ══════════════════════════════════════════════════════════
    FoodPlace(
      id: 'FOOD-PSH-001',
      name: 'Charsi Tikka Namak Mandi',
      category: FoodCategory.bbq,
      cuisine: 'Namak Mandi Mutton Dumba Karahi & BBQ Skewers',
      latitude: 34.0080,
      longitude: 71.5720,
      city: 'Peshawar',
      address: 'Namak Mandi Food Bazaar, Old Peshawar City',
      distance: '2.8 km',
      distanceKm: 2.8,
      estimatedTravelTime: '10 mins',
      rating: 4.9,
      reviewCount: 18900,
      priceTier: FoodPriceTier.moderate,
      avgCostPerPersonPkr: 2000,
      imageUrl: 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=800&auto=format&fit=crop&q=80',
      isOpen: true,
      openingHours: '12:00 PM - 02:00 AM',
      phone: '+92-91-2567890',
      specialties: ['Dumba (Fat-Tailed Sheep) Karahi', 'Charcoal Lamb Chops', 'Namak Mandi Boti', 'Peshawari Green Tea with Cardamom'],
      description:
          'The legendary birthplace of Pashtun salt-and-fat meat craft. Cooked using only mutton fat, salt, and fresh tomatoes over high coal fires.',
      popularReview: '"Unadulterated flavor without artificial spices. Tender, smoky, melt-in-the-mouth mutton perfection."',
      landmarkNearby: 'Namak Mandi Square',
      hasDineIn: true,
      hasTakeaway: true,
      hasDelivery: true,
    ),
  ];

  @override
  Future<List<FoodPlace>> fetchFoodPlaces({
    String? city,
    double? userLat,
    double? userLng,
    FoodCategory? category,
    String? query,
  }) async {
    // Simulate realistic network latency for API readiness
    await Future.delayed(const Duration(milliseconds: 350));

    var results = List<FoodPlace>.from(_allFoodPlaces);

    // 1. City filter
    if (city != null && city.isNotEmpty && city.toLowerCase() != 'all') {
      final normalizedCity = city.toLowerCase().trim();
      results = results.where((p) {
        final placeCity = p.city.toLowerCase();
        return placeCity.contains(normalizedCity) || normalizedCity.contains(placeCity);
      }).toList();
    }

    // 2. Category filter
    if (category != null && category != FoodCategory.all) {
      results = results.where((p) => p.category == category).toList();
    }

    // 3. Search query filter
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      results = results.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.cuisine.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.specialties.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }

    // 4. GPS Distance Calculation if coordinates provided
    if (userLat != null && userLng != null) {
      results = results.map((place) {
        final distKm = _calculateDistanceKm(userLat, userLng, place.latitude, place.longitude);
        final distStr = distKm < 1.0
            ? '${(distKm * 1000).toInt()} m'
            : '${distKm.toStringAsFixed(1)} km';
        final travelMins = math.max(3, (distKm * 3.2).toInt());
        final travelStr = '$travelMins mins';

        return place.copyWithDistance(
          newDistanceKm: distKm,
          newDistance: distStr,
          newTravelTime: travelStr,
        );
      }).toList();
    }

    return results;
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth's radius in kilometers
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180.0);
}

/// Central Repository coordinating Food Data, GPS resolution, sorting, and filtering.
class FoodService {
  static FoodDataProvider _provider = CuratedFoodDataProvider();

  /// Change data provider (e.g. Google Places, OpenStreetMap, or custom REST API).
  static void setProvider(FoodDataProvider provider) {
    _provider = provider;
  }

  /// Get supported city destinations.
  static List<String> getSupportedCities() => _provider.getSupportedCities();

  /// Fetch and sort food spots according to user selections.
  static Future<List<FoodPlace>> searchFoodPlaces({
    String? city,
    bool useCurrentLocation = false,
    FoodCategory category = FoodCategory.all,
    FoodSortOption sortOption = FoodSortOption.rating,
    String? query,
  }) async {
    try {
      debugPrint('FOOD SEARCH STARTED: city=$city, useGPS=$useCurrentLocation, category=${category.name}');

      double? userLat;
      double? userLng;

      if (useCurrentLocation) {
        final pos = await HotelLocationService.getCurrentLocation();
        userLat = pos.latitude;
        userLng = pos.longitude;
        debugPrint('FOOD LOCATION (GPS): $userLat, $userLng');
      }

      var places = await _provider.fetchFoodPlaces(
        city: useCurrentLocation ? null : city,
        userLat: userLat,
        userLng: userLng,
        category: category,
        query: query,
      );

      // Sort results
      switch (sortOption) {
        case FoodSortOption.nearest:
          places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          break;
        case FoodSortOption.rating:
          places.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case FoodSortOption.reviews:
          places.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
          break;
        case FoodSortOption.priceLowToHigh:
          places.sort((a, b) => a.avgCostPerPersonPkr.compareTo(b.avgCostPerPersonPkr));
          break;
        case FoodSortOption.priceHighToLow:
          places.sort((a, b) => b.avgCostPerPersonPkr.compareTo(a.avgCostPerPersonPkr));
          break;
      }

      debugPrint('FOOD SEARCH COMPLETE: Found ${places.length} places');
      return places;
    } catch (e, stackTrace) {
      debugPrint('FOOD API ERROR: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
