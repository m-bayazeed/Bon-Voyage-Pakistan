import 'package:flutter_test/flutter_test.dart';
import 'package:bon_voyage_pakistan/models/hotel_model.dart';
import 'package:bon_voyage_pakistan/services/hotel_location_service.dart';

void main() {
  group('Hotels & Stays Unit Tests', () {
    test('Haversine distance calculation is accurate', () {
      // Islamabad to Lahore distance (~270 km)
      final dist = HotelLocationService.calculateDistanceKm(
        33.6844,
        73.0479,
        31.5204,
        74.3587,
      );
      expect(dist, greaterThan(250.0));
      expect(dist, lessThan(300.0));
    });

    test('Hotel model correctly parses Geoapify backend response', () {
      final json = {
        'id': 'geo_33.7180_73.0538_Hilton',
        'name': 'Hilton Hills Islamabad',
        'category': 'resort',
        'badge_label': 'Mountain Resort',
        'latitude': 33.7185,
        'longitude': 73.0541,
        'distance_km': 0.8,
        'address': 'Bhitai Road, F-7, Islamabad',
        'city': 'Islamabad',
        'country': 'Pakistan',
        'description': 'A serene mountain resort stay in Islamabad.',
        'highlight': 'Scenic Mountain Stay',
        'rating': 4.5,
        'price_per_night_pkr': 25000,
        'amenities': ['Free High-Speed Wi-Fi', 'Mountain / Valley View'],
        'directions_url':
            'https://www.google.com/maps/dir/?api=1&destination=33.7185,73.0541',
      };

      final hotel = Hotel.fromJson(json);

      expect(hotel.id, 'geo_33.7180_73.0538_Hilton');
      expect(hotel.name, 'Hilton Hills Islamabad');
      expect(hotel.category, HotelCategory.resort);
      expect(hotel.badgeLabel, 'Mountain Resort');
      expect(hotel.distanceKm, 0.8);
      expect(hotel.rating, 4.5);
      expect(hotel.pricePerNightPkr, 25000);
      expect(hotel.formattedPrice, 'PKR 25,000 / night');
      expect(hotel.directionsUrl, contains('destination=33.7185,73.0541'));
    });

    test('Hotel model gracefully handles null image and price without error', () {
      final json = {
        'id': 'geo_test_nulls',
        'name': 'Rawal Guest House',
        'category': 'budget',
        'latitude': 33.6900,
        'longitude': 73.0500,
        'distance_km': 1.5,
        'address': 'Islamabad',
        'image_url': null,
        'rating': null,
        'price_per_night_pkr': null,
        'directions_url':
            'https://www.google.com/maps/dir/?api=1&destination=33.6900,73.0500',
      };

      final hotel = Hotel.fromJson(json);

      expect(hotel.name, 'Rawal Guest House');
      expect(hotel.category, HotelCategory.budget);
      expect(hotel.imageUrl, isNull);
      expect(hotel.rating, isNull);
      expect(hotel.pricePerNightPkr, isNull);
      expect(hotel.formattedPrice, isNull);
    });

    test('All HotelCategory enum values have displayName and icon', () {
      for (final cat in HotelCategory.values) {
        expect(cat.displayName.isNotEmpty, isTrue);
        expect(cat.icon, isNotNull);
        expect(cat.color, isNotNull);
      }
    });

    test('All HotelSortOption enum values map to correct API keys', () {
      expect(HotelSortOption.nearness.apiKey, 'nearest');
      expect(HotelSortOption.rating.apiKey, 'rating');
      expect(HotelSortOption.priceLowToHigh.apiKey, 'price_low_high');
      expect(HotelSortOption.priceHighToLow.apiKey, 'price_high_low');
    });
  });
}
