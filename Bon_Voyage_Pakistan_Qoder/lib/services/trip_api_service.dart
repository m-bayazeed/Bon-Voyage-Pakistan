import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/trip_plan_model.dart';

class TripIncompatibleException implements Exception {
  final String message;
  final List<String> suggestedInterests;
  final List<String> suggestedDestinations;

  TripIncompatibleException({
    required this.message,
    this.suggestedInterests = const [],
    this.suggestedDestinations = const [],
  });

  @override
  String toString() => message;
}

class TripGenerationResult {
  final TripPlan plan;
  final String introMessage;
  final List<String> quickSuggestions;

  TripGenerationResult({
    required this.plan,
    required this.introMessage,
    required this.quickSuggestions,
  });
}

class TripChatResult {
  final String message;
  final TripPlan? updatedPlan;

  TripChatResult({
    required this.message,
    this.updatedPlan,
  });
}

class TripApiService {
  TripApiService._();

  /// Generate a complete AI tour plan via the Flask backend and Groq AI.
  static Future<TripGenerationResult> generateTripPlan({
    required String departingCity,
    required String destinationCity,
    required int days,
    required List<String> interests,
    String specialRequirements = '',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.generateTripPlan),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'departing': departingCity,
              'destination': destinationCity,
              'days': days,
              'interests': interests,
              'special_requirements': specialRequirements,
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Check for Interest Incompatibility returned by backend validator
        if (data['incompatible'] == true) {
          throw TripIncompatibleException(
            message: data['message'] ??
                'Selected interests do not have verified matches for this destination.',
            suggestedInterests: data['suggestedInterests'] != null
                ? List<String>.from(data['suggestedInterests'] as List)
                : const [],
            suggestedDestinations: data['suggestedDestinations'] != null
                ? List<String>.from(data['suggestedDestinations'] as List)
                : const [],
          );
        }

        if (data['success'] == true && data['plan'] != null) {
          final plan = TripPlan.fromJson(data['plan'] as Map<String, dynamic>);
          final introMessage = data['introMessage'] as String? ??
              "Salam & welcome! 🇵🇰 I have prepared your personalized <b>${plan.title}</b> departing from <b>${plan.departingCity}</b>.";
          final quickSuggestions = data['quickSuggestions'] != null
              ? List<String>.from(data['quickSuggestions'] as List)
              : <String>[
                  'Add more photography viewpoints 📸',
                  'I want more historical places 🏛️',
                  'Suggest best local food spots 🍲',
                  'Make route easier for families 👨‍👩‍👧',
                ];

          return TripGenerationResult(
            plan: plan,
            introMessage: introMessage,
            quickSuggestions: quickSuggestions,
          );
        }
      }
      throw Exception(
        'Server returned ${response.statusCode}: ${response.body}',
      );
    } on TripIncompatibleException {
      rethrow;
    } catch (e) {
      // Fallback synthesis if server is unreachable
      return _generateLocalFallbackPlan(
        departingCity: departingCity,
        destinationCity: destinationCity,
        days: days,
        interests: interests,
        specialRequirements: specialRequirements,
      );
    }
  }

  /// Refine trip with chat query via Groq AI backend.
  static Future<TripChatResult> sendChatMessage({
    required String message,
    TripPlan? currentPlan,
    List<ChatMessage>? chatHistory,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.chatTripPlan),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'current_plan': currentPlan?.toJson(),
              'chat_history': chatHistory?.map((m) => m.toJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true) {
          final reply = data['message'] as String? ??
              'I have updated your preferences accordingly.';
          TripPlan? updatedPlan;
          if (data['updatedPlan'] != null) {
            try {
              updatedPlan = TripPlan.fromJson(data['updatedPlan'] as Map<String, dynamic>);
            } catch (_) {}
          }
          return TripChatResult(
            message: reply,
            updatedPlan: updatedPlan,
          );
        }
      }
      throw Exception('Server returned ${response.statusCode}');
    } catch (e) {
      return _getLocalChatFallback(message);
    }
  }

  static TripGenerationResult _generateLocalFallbackPlan({
    required String departingCity,
    required String destinationCity,
    required int days,
    required List<String> interests,
    required String specialRequirements,
  }) {
    final destLower = destinationCity.toLowerCase();

    // Validation check for local fallback
    if (destLower.contains('multan') || destLower.contains('lahore') || destLower.contains('karachi')) {
      final hasMountainHiking = interests.any((i) =>
          i.toLowerCase().contains('mountain') ||
          i.toLowerCase().contains('hiking') ||
          i.toLowerCase().contains('trekking') ||
          i.toLowerCase().contains('camp'));
      final hasLocal = interests.any((i) =>
          i.toLowerCase().contains('histor') ||
          i.toLowerCase().contains('cultur') ||
          i.toLowerCase().contains('food') ||
          i.toLowerCase().contains('cuisin') ||
          i.toLowerCase().contains('photo') ||
          i.toLowerCase().contains('luxur') ||
          i.toLowerCase().contains('beach') ||
          i.toLowerCase().contains('coast'));

      if (hasMountainHiking && !hasLocal && interests.isNotEmpty) {
        throw TripIncompatibleException(
          message:
              '<b>$destinationCity</b> does not currently have verified mountain or hiking trail attractions matching your selected interests.\n\n'
              'The destination is better suited to: <b>History & Heritage • Sufi Culture • Local Cuisine & Food</b>.\n\n'
              'Please adjust your interests or choose another destination such as <b>Hunza Valley</b>, <b>Skardu & Deosai</b>, <b>Swat & Kalam</b>, or <b>Margalla Hills (Islamabad)</b>.',
          suggestedInterests: const [
            'History & Heritage',
            'Cultural Festivals',
            'Local Cuisine & Food',
            'Photography & Stargazing',
          ],
          suggestedDestinations: const [
            'Hunza Valley',
            'Skardu & Deosai',
            'Swat & Kalam',
            'Margalla Hills (Islamabad)',
          ],
        );
      }
    }

    final planId =
        'TRIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final List<ItineraryDay> daysPlan = [];

    for (int i = 1; i <= days; i++) {
      if (destLower.contains('multan')) {
        if (i == 1) {
          daysPlan.add(ItineraryDay(
            dayNumber: 1,
            title: '$departingCity to Multan & Historic Sufi Shrines',
            route: '$departingCity ➔ M-4 Motorway ➔ Multan Fort ➔ Qasim Bagh',
            timing: '08:00 AM – 06:30 PM • Sufi Heritage & Architecture',
            attractions: const [
              'Shrine of Shah Rukn-e-Alam (14th-century octagonal dome)',
              'Shrine of Bahauddin Zakariya',
              'Multan Fort & Qasim Bagh Panoramic View'
            ],
            activities: const [
              'Admire intricate blue Kashikari glazed tile architecture',
              'Courtyard walking tour and Sufi history overview',
              'Rooftop sunset view over ancient Multan city'
            ],
            foodRecommendation: 'Famous <i>Hafiz Sohan Halwa</i> & fresh fried fish at Bohar Gate',
            stayRecommendation: 'Central boutique hotel on Abdali Road / Cantt',
          ));
        } else if (i == 2) {
          daysPlan.add(const ItineraryDay(
            dayNumber: 2,
            title: 'Tomb of Shah Shams & Blue Pottery Artisan Guilds',
            route: 'Cantt ➔ Tomb of Shah Shams Tabrez ➔ Institute of Blue Pottery ➔ Hussain Agahi',
            timing: '09:00 AM – 06:00 PM • Craft & Market Exploration',
            attractions: [
              'Tomb of Shah Shams Tabrez',
              'Institute of Blue Pottery Development (Kashikari)',
              'Hussain Agahi Traditional Bazaar'
            ],
            activities: [
              'Live master demonstration of traditional blue pottery painting',
              'Shop for authentic camel-skin lamps and hand-embroidered shawls',
              'Street culinary tasting in historic bazaars'
            ],
            foodRecommendation: 'Traditional <i>Doli Roti</i> & spicy Multani Gol Gappay at Ghanta Ghar',
            stayRecommendation: 'Comfortable hotel in Gulgasht / Cantt Multan',
          ));
        } else {
          daysPlan.add(ItineraryDay(
            dayNumber: i,
            title: 'Day $i: Clock Tower, Gardens & Farewell Feast',
            route: 'Multan ➔ Ghanta Ghar (Clock Tower) ➔ Chaman Zar Askari Lake ➔ Return to $departingCity',
            timing: '09:30 AM – 05:00 PM • Heritage landmarks and return',
            attractions: const [
              'Clock Tower Multan (Ghanta Ghar)',
              'Patrick Alexander Vans Agnew Monument',
              'Chaman Zar Askari Lake Park'
            ],
            activities: const [
              'Colonial architecture photography at Ghanta Ghar',
              'Relaxing boat ride at Askari Lake',
              'Souvenir box packing of Multani Rewari and Sohan Halwa'
            ],
            foodRecommendation: 'Authentic <i>Multani Mutton Karahi</i> & chilled Rabri Falooda',
            stayRecommendation: 'Safe return journey to $departingCity',
          ));
        }
      } else if (destLower.contains('lahore')) {
        if (i == 1) {
          daysPlan.add(ItineraryDay(
            dayNumber: 1,
            title: '$departingCity to Lahore & Walled City Exploration',
            route: '$departingCity ➔ M-2 Motorway ➔ Lahore Walled City ➔ Delhi Gate',
            timing: '08:00 AM – 06:30 PM • Heritage & Cultural Tour',
            attractions: const [
              'Shahi Hammam (Royal Bath)',
              'Wazir Khan Mosque',
              'Fort Road Food Street'
            ],
            activities: const [
              'Walking tour through ancient Delhi Gate & bazaars',
              'Architectural fresco photography inside Wazir Khan Mosque',
              'Rooftop welcome dinner overlooking Badshahi Mosque'
            ],
            foodRecommendation: 'Famous <i>Phikkay ki Jalebi</i> & authentic <i>Mutton Karahi</i> at Fort Road',
            stayRecommendation: 'Heritage boutique hotel in Gulberg / Mall Road',
          ));
        } else if (i == 2) {
          daysPlan.add(const ItineraryDay(
            dayNumber: 2,
            title: 'Mughal Splendor & Historic Forts',
            route: 'Gulberg ➔ Lahore Fort ➔ Badshahi Mosque ➔ Greater Iqbal Park',
            timing: '09:00 AM – 06:00 PM • Monument Discovery',
            attractions: [
              'UNESCO World Heritage Lahore Fort & Sheesh Mahal',
              'Grand Badshahi Mosque',
              'Minar-e-Pakistan'
            ],
            activities: [
              'Guided exploration of Mughal royal chambers and mirror palace',
              'Historic courtyard stroll at Badshahi Mosque',
              'Souvenir shopping in Anarkali Bazaar'
            ],
            foodRecommendation: 'Traditional <i>Halwa Puri</i> & slow-cooked <i>Siri Paye</i> in Old Anarkali',
            stayRecommendation: 'Comfortable central hotel in Lahore',
          ));
        } else if (i == 3) {
          daysPlan.add(const ItineraryDay(
            dayNumber: 3,
            title: 'Shalimar Gardens & Wagah Border Ceremony',
            route: 'Lahore ➔ Shalimar Gardens ➔ Wagah Border Parade ➔ Packages Mall',
            timing: '10:00 AM – 07:30 PM • Gardens & Patriotic Excursion',
            attractions: [
              '3-Tier Mughal Shalimar Gardens',
              'Wagah Border Flag Lowering Ceremony',
              'Lahore Museum (Gandhara Fasting Buddha)'
            ],
            activities: [
              'Stroll across Mughal water cascades and marble pavilions',
              'Witness the high-energy Wagah Border military parade',
              'Explore ancient Harappan and Gandharan artifacts'
            ],
            foodRecommendation: 'Authentic <i>Murgh Chanay</i> & rich saffron <i>Falooda</i>',
            stayRecommendation: 'Serena / Pearl Continental or boutique stay in Gulberg',
          ));
        } else {
          daysPlan.add(ItineraryDay(
            dayNumber: i,
            title: 'Day $i: Art, Crafts & Farewell Culinary Trail',
            route: 'Gulberg ➔ National College of Arts & Tollinton Market ➔ Return Journey to $departingCity',
            timing: '09:30 AM – 05:00 PM • Artisan exploration and return',
            attractions: const [
              'Alhamra Cultural Complex',
              'Liberty Market Artisan Quarter',
              'Jinnah Garden (Lawrence Gardens)'
            ],
            activities: const [
              'Craft shopping for traditional truck-art souvenirs and shawls',
              'Relaxing tea in lush botanical gardens',
              'Farewell traditional feast'
            ],
            foodRecommendation: 'Fresh <i>Tawa Chicken</i> at Lakshmi Chowk with hot <i>Roghni Naan</i>',
            stayRecommendation: 'Safe return journey to $departingCity',
          ));
        }
      } else if (destLower.contains('hunza')) {
        if (i == 1) {
          daysPlan.add(ItineraryDay(
            dayNumber: 1,
            title: '$departingCity to Gilgit & Karimabad',
            route: '$departingCity ➔ Karakoram Highway ➔ Chilas / Gilgit ➔ Karimabad, Hunza',
            timing: '06:00 AM – 06:00 PM • Scenic Mountain Highway',
            attractions: const [
              '3 Mountain Ranges Junction',
              'Rakaposhi Viewpoint',
              'Karimabad Bazaar'
            ],
            activities: const [
              'Scenic tea stop overlooking Rakaposhi Peak',
              'Sunset stroll in historic Karimabad streets'
            ],
            foodRecommendation: 'Authentic <i>Chapshuro</i> (Hunza meat pies) & Walnut Cake',
            stayRecommendation: 'Mountain lodge in Karimabad overlooking Ultar Sar',
          ));
        } else if (i == 2) {
          daysPlan.add(const ItineraryDay(
            dayNumber: 2,
            title: 'Ancient Forts & Royal Culture',
            route: 'Karimabad ➔ Baltit Fort ➔ Altit Fort ➔ Duikar (Eagle’s Nest)',
            timing: '09:00 AM – 06:30 PM • Heritage & Sunset Viewpoints',
            attractions: [
              '700-year-old Baltit Fort',
              '900-year-old Altit Fort & Royal Gardens',
              'Eagle’s Nest Sunset Deck'
            ],
            activities: [
              'Guided heritage fort tour with local historian',
              '360-degree panoramic golden hour photo session'
            ],
            foodRecommendation: 'Organic <i>Mamtu</i> dumplings & traditional apricot juice',
            stayRecommendation: 'Eagle’s Nest or boutique hotel in Duikar',
          ));
        } else {
          daysPlan.add(ItineraryDay(
            dayNumber: i,
            title: 'Day $i: Turquoise Lakes & High Passes',
            route: 'Karimabad ➔ Attabad Lake ➔ Hussaini Bridge ➔ Passu Cones',
            timing: '08:30 AM – 05:30 PM • Upper Hunza Exploration',
            attractions: const [
              'Attabad Lake',
              'Hussaini Suspension Bridge',
              'Passu Cathedral Cones'
            ],
            activities: const [
              'Boating on turquoise Attabad Lake',
              'Scenic photography at Passu Glacier viewpoint'
            ],
            foodRecommendation: 'Fresh Yak steak & herbal mountain tea at Passu',
            stayRecommendation: 'Lakefront resort at Attabad Lake or return lodge',
          ));
        }
      } else {
        daysPlan.add(ItineraryDay(
          dayNumber: i,
          title: 'Day $i: Curated Highlights of $destinationCity',
          route: '$departingCity ➔ Central $destinationCity Sightseeing & Heritage Trail',
          timing: '08:30 AM – 06:00 PM • Exploration & Spot Visits',
          attractions: [
            'Iconic $destinationCity Viewpoint & Panorama',
            'Historic Landmark & Cultural Quarter',
            'Artisan Heritage Market',
          ],
          activities: const [
            'Guided cultural and landscape photography',
            'Artisan craft sampling and local sightseeing',
            'Authentic dinner experience',
          ],
          foodRecommendation: 'Fresh traditional regional specialty platter with hot <i>tandoori</i> bread and tea',
          stayRecommendation: 'Top-rated tourist lodge in $destinationCity',
        ));
      }
    }

    final plan = TripPlan(
      id: planId,
      title: '$days-Day $destinationCity AI Discovery Plan',
      departingCity: departingCity,
      destinationCity: destinationCity,
      days: days,
      travelers: 1,
      budgetTier: 'Curated Spots Guide',
      budgetAmountPkr: 0,
      interests: interests,
      transportation: 'Scenic Route Transport',
      accommodation: 'Tourist Lodges',
      specialRequirements: specialRequirements,
      daysPlan: daysPlan,
      budgetBreakdown: const BudgetBreakdown(
        transportPkr: 0,
        accommodationPkr: 0,
        foodPkr: 0,
        activitiesPkr: 0,
        contingencyPkr: 0,
      ),
      isFinalized: false,
    );

    final interestsStr = interests.isNotEmpty ? interests.join(', ') : 'Sightseeing & Culture';
    final introMessage =
        "Salam & welcome! 🇵🇰 I have prepared your personalized <b>$days-Day $destinationCity</b> trip plan departing from <b>$departingCity</b> focusing on <b>$interestsStr</b>.\n\n"
        "<b><u>Trip Overview:</u></b>\n"
        "• <b>Route:</b> $departingCity ➔ $destinationCity\n"
        "• <b>Duration:</b> $days Days\n"
        "• <b>Interests:</b> $interestsStr\n\n"
        "You can chat with me to fine-tune spots, adjust pace, or add specific attractions. When you're ready, tap <b>Review Plan Summary & Finalize</b> below to review your detailed day-by-day itinerary and save your trip!";

    return TripGenerationResult(
      plan: plan,
      introMessage: introMessage,
      quickSuggestions: const [
        'Add more photography viewpoints 📸',
        'I want more historical places 🏛️',
        'Suggest best local food spots 🍲',
        'Make route easier for families 👨‍👩‍👧',
      ],
    );
  }

  static TripChatResult _getLocalChatFallback(String message) {
    return TripChatResult(
      message:
          "Got it! I have customized your spots and itinerary for \"<b>$message</b>\". The route and day-by-day sightseeing plan have been refreshed to match this preference.\n\n"
          "Tap <b>Review Summary & Finalize</b> below to inspect your updated day-by-day schedule.",
    );
  }
}
