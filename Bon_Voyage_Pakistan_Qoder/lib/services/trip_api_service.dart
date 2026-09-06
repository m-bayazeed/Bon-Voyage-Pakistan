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
      if (destLower.contains('hunza') || destLower.contains('gilgit') || destLower.contains('karimabad')) {
        daysPlan.add(_buildHunzaDay(i, departingCity, days));
      } else if (destLower.contains('skardu') || destLower.contains('deosai') || destLower.contains('shigar') || destLower.contains('baltistan') || destLower.contains('khaplu')) {
        daysPlan.add(_buildSkarduDay(i, departingCity, days));
      } else if (destLower.contains('swat') || destLower.contains('kalam') || destLower.contains('mingora') || destLower.contains('malam jabba')) {
        daysPlan.add(_buildSwatDay(i, departingCity, days));
      } else if (destLower.contains('naran') || destLower.contains('kaghan') || destLower.contains('shogran') || destLower.contains('saif-ul-malook')) {
        daysPlan.add(_buildNaranDay(i, departingCity, days));
      } else if (destLower.contains('fairy') || destLower.contains('nanga parbat')) {
        daysPlan.add(_buildFairyMeadowsDay(i, departingCity, days));
      } else if (destLower.contains('neelum') || destLower.contains('kashmir') || destLower.contains('ratti gali') || destLower.contains('arang kel') || destLower.contains('sharda')) {
        daysPlan.add(_buildNeelumDay(i, departingCity, days));
      } else if (destLower.contains('gwadar') || destLower.contains('makran') || destLower.contains('kund malir') || destLower.contains('ormara')) {
        daysPlan.add(_buildGwadarDay(i, departingCity, days));
      } else if (destLower.contains('lahore')) {
        daysPlan.add(_buildLahoreDay(i, departingCity, days));
      } else if (destLower.contains('multan') || destLower.contains('bahawalpur')) {
        daysPlan.add(_buildMultanDay(i, departingCity, days));
      } else if (destLower.contains('kumrat') || destLower.contains('dir')) {
        daysPlan.add(_buildKumratDay(i, departingCity, days));
      } else if (destLower.contains('chitral') || destLower.contains('kalash')) {
        daysPlan.add(_buildChitralDay(i, departingCity, days));
      } else if (destLower.contains('islamabad') || destLower.contains('rawalpindi') || destLower.contains('margalla')) {
        daysPlan.add(_buildIslamabadDay(i, departingCity, days));
      } else {
        daysPlan.add(_buildCustomDestinationDay(i, departingCity, destinationCity, days, interests));
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
    final previewHighlights = daysPlan.take(3).map((d) => '• <b>Day ${d.dayNumber}:</b> ${d.title} (<i>${d.attractions.take(2).join(', ')}</i>)').join('\n');
    final moreDaysText = days > 3 ? '\n• <i>...and ${days - 3} more exciting days planned!</i>' : '';

    final introMessage =
        'Salam & welcome! 🇵🇰 I have prepared your personalized <b>$days-Day $destinationCity</b> trip plan departing from <b>$departingCity</b> focusing on <b>$interestsStr</b>.\n\n'
        '<b><u>Trip Overview:</u></b>\n'
        '• <b>Route:</b> $departingCity ➔ $destinationCity\n'
        '• <b>Duration:</b> $days Days\n'
        '• <b>Interests:</b> $interestsStr\n\n'
        '<b><u>Day-by-Day Highlights Preview:</u></b>\n'
        '$previewHighlights$moreDaysText\n\n'
        'Tap <b>Review Plan Summary & Finalize</b> below to review all day-by-day details, routes, and timings, or chat with me to fine-tune spots!';

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

  // ──────────────────────────────────────────────
  // Authentic Day-by-Day Itinerary Builders
  // ──────────────────────────────────────────────

  static ItineraryDay _buildHunzaDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Gilgit & Karimabad Valley',
          route: '$departing ➔ Karakoram Highway ➔ Chilas / Gilgit ➔ Karimabad, Hunza',
          timing: '06:00 AM – 06:30 PM • Mountain Highway & Valley Arrival',
          attractions: const [
            '3 Mountain Ranges Junction (Himalayas, Karakoram, Hindu Kush)',
            'Rakaposhi Viewpoint (7,788m peak panorama)',
            'Karimabad Heritage Gemstone Bazaar',
          ],
          activities: const [
            'Scenic chai stop overlooking Rakaposhi Peak',
            'Sunset stroll in Karimabad cobblestone streets',
            'Welcome traditional Hunza dinner',
          ],
          foodRecommendation: 'Authentic <i>Chapshuro</i> (Hunza meat pies) & walnut cake',
          stayRecommendation: 'Mountain view hotel in Karimabad overlooking Ultar Sar',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Ancient Forts & Eagle\'s Nest Sunset Deck',
          route: 'Karimabad ➔ Baltit Fort ➔ Altit Fort & Royal Gardens ➔ Duikar (Eagle’s Nest)',
          timing: '09:00 AM – 06:30 PM • Royal Forts & 360° Panorama',
          attractions: [
            '700-year-old Baltit Fort',
            '900-year-old Altit Fort & Royal Gardens',
            'Eagle’s Nest 360° Sunset Viewpoint',
          ],
          activities: [
            'Guided heritage fort tour with local historian',
            'Explore ancient Altit village cobblestone alleys',
            '360-degree golden hour sunset photography over 11 peaks',
          ],
          foodRecommendation: 'Organic <i>Mamtu</i> dumplings & traditional apricot kernel oil dishes',
          stayRecommendation: 'Eagle’s Nest or boutique hotel in Duikar',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Turquoise Attabad Lake & Upper Hunza Wonders',
          route: 'Karimabad ➔ Attabad Lake ➔ Hussaini Suspension Bridge ➔ Passu Cones',
          timing: '08:30 AM – 05:30 PM • Lake Boating & Iconic Peaks',
          attractions: [
            'Attabad Lake (Turquoise Waters & Jet Skiing)',
            'Hussaini Suspension Bridge',
            'Passu Cathedral Cones (Tupopdan Peaks)',
          ],
          activities: [
            'Boating on emerald Attabad Lake',
            'Thrilling walk across Hussaini suspension bridge',
            'Scenic photography at Passu Glacier viewpoint',
          ],
          foodRecommendation: 'Fresh Yak steak & herbal mountain tea at Glacier Breeze Cafe',
          stayRecommendation: 'Lakefront resort at Attabad Lake or mountain lodge in Passu',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Khunjerab Pass - Pak-China Mountain Border',
          route: 'Passu ➔ Sost Dry Port ➔ Khunjerab National Park ➔ Khunjerab Pass (15,397 ft)',
          timing: '07:30 AM – 06:00 PM • High Altitude Border Expedition',
          attractions: [
            'Khunjerab Pass (15,397 ft World’s Highest ATM & Border Gate)',
            'Khunjerab National Park (Himalayan Ibex habitat)',
            'Sost International Dry Port Market',
          ],
          activities: [
            'Touch the monumental Pak-China border gate at 4,693m',
            'Spot Himalayan Ibex and Golden Marmots along alpine slopes',
            'Shop for Chinese silk and herbal teas in Sost',
          ],
          foodRecommendation: 'Steaming hot chicken corn soup & Tibetan noodle bowls in Sost',
          stayRecommendation: 'Comfortable tourist lodge in Gulmit or Passu',
        );
      case 5:
        return const ItineraryDay(
          dayNumber: 5,
          title: 'Glacial Lakes & Ancient Silk Road Lore',
          route: 'Gulmit ➔ Borith Lake ➔ Passu Glacier Moraine Trail ➔ Ganish Ancient Settlement',
          timing: '09:00 AM – 05:00 PM • Glacial Hikes & Ancient Settlements',
          attractions: [
            'Borith Lake (Migratory Bird Sanctuary)',
            'White Passu Glacier Viewpoint Trail',
            'Ganish 1,000-year-old Silk Road Village',
          ],
          activities: [
            'Gentle nature hike to Passu Glacier edge and moraine ridge',
            'Explore ancient carved wooden watchtowers in Ganish',
            'Traditional musical instrument workshop in Gulmit',
          ],
          foodRecommendation: 'Traditional <i>Gyaling</i> pancakes with mountain apricot honey',
          stayRecommendation: 'Heritage boutique guest house in Karimabad / Gulmit',
        );
      case 6:
        return const ItineraryDay(
          dayNumber: 6,
          title: 'Nagar Valley & Hopper Glacial Excursion',
          route: 'Karimabad ➔ Nagar Valley ➔ Hopper Glacier Viewpoint ➔ Minapin Orchards',
          timing: '08:30 AM – 05:00 PM • Black Glacier & Blossom Orchards',
          attractions: [
            'Hopper Valley & Hopper Glacier',
            'Minapin Apricot & Cherry Orchards',
            'Diran Peak Viewpoint',
          ],
          activities: [
            'Descend to Hopper active black gravel glacier moraine',
            'Walk through lush terraced orchards in Minapin',
            'Interact with local Nagar farmers and sample dry fruits',
          ],
          foodRecommendation: 'Authentic <i>Ghilmindi</i> (cheese flatbread) & herbal mountain chai',
          stayRecommendation: 'Osho Thang Hotel in Minapin or Karimabad',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Souvenir Artisan Shopping & Farewell Journey',
          route: 'Karimabad ➔ Gilgit City ➔ KKH Highway ➔ Return Journey to $departing',
          timing: '07:00 AM – 07:00 PM • Scenic Return Drive & Memories',
          attractions: const [
            'Gilgit Old Suspension Bridge',
            'Karakoram Highway Mountain Vistas',
            'Besham / Chilas Indus River Rest Point',
          ],
          activities: const [
            'Pack souvenirs: lapis lazuli gems, dried cherries, walnut wood crafts',
            'Final farewell mountain highway photography',
            'Safe return transit to departure city',
          ],
          foodRecommendation: 'Hot <i>Shinwari Karahi</i> & tandoori kulcha along highway dhabas',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildSkarduDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Skardu & Kachura Lakes',
          route: '$departing ➔ Skardu Valley ➔ Shangrila Resort ➔ Upper Kachura Lake',
          timing: '07:30 AM – 06:00 PM • Alpine Valley Arrival & Emerald Lakes',
          attractions: const [
            'Shangrila Resort Lake (Lower Kachura Pagoda)',
            'Upper Kachura Lake (Emerald Alpine Water)',
            'Kachura Trout Hatchery & Pine Woods',
          ],
          activities: const [
            'Wooden rowboat ride across crystal-clear Upper Kachura Lake',
            'Iconic pagoda photo session at Shangrila Lake',
            'Welcome evening stroll along Indus riverbank',
          ],
          foodRecommendation: 'Fresh Pan-Fried Kachura Trout Fish with lemon herb dip',
          stayRecommendation: 'Lakeside resort in Kachura or central hotel in Skardu',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Cold Desert Dunes & Shigar Royal Fort',
          route: 'Skardu ➔ Sarfaranga Cold Desert ➔ 400-year-old Shigar Fort ➔ Blind Lake',
          timing: '08:30 AM – 06:00 PM • Desert Dunes & Balti Heritage',
          attractions: [
            'Sarfaranga Cold Desert (High-Altitude Sand Dunes)',
            '400-year-old Fong-Khar Shigar Fort Palace',
            'Blind Lake Shigar (Emerald hidden lagoon)',
          ],
          activities: [
            '4x4 desert quad-biking on cold desert sand ripples',
            'Guided tour of Raja of Shigar royal chambers & wooden carvings',
            'Picnic by the peaceful shores of Blind Lake',
          ],
          foodRecommendation: 'Traditional <i>Balti Gosht</i> cooked in stone Deygh with hot khobani naan',
          stayRecommendation: 'Serena Shigar Fort Heritage Lodge or boutique hotel in Shigar',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Deosai Plains - Land of Giants Expedition',
          route: 'Skardu ➔ Ali Malik Top ➔ Deosai National Park ➔ Sheosar Lake',
          timing: '07:00 AM – 06:00 PM • 13,500 ft High-Altitude Plateau',
          attractions: [
            'Deosai National Park & Plateau (Land of Giants)',
            'Heart-shaped Sheosar Lake',
            'Bara Pani & Kala Pani Glacial Streams',
          ],
          activities: [
            'Cross high-altitude plains dotted with golden alpine wildflowers',
            'Spot Himalayan Brown Bears and golden marmots',
            'Spectacular photography of snowcapped Nanga Parbat backdrop across Sheosar Lake',
          ],
          foodRecommendation: 'Warm thermos chai & hot local chicken pulao at Deosai campsite',
          stayRecommendation: 'Glamping camp at Deosai or return to Skardu hotel',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'King of Forts & Thundering Waterfalls',
          route: 'Skardu ➔ Kharpocho Fort ➔ Sadpara Lake & Dam ➔ Manthokha Waterfall',
          timing: '08:30 AM – 05:30 PM • Historical Forts & Cascades',
          attractions: [
            'Kharpocho Fort (King of Forts overlooking Indus River)',
            'Sadpara Lake & Dam',
            'Manthokha 180-ft Waterfall in Kharmang',
          ],
          activities: [
            'Hike up ancient stone trail to Kharpocho Fort for panoramic bird-eye valley views',
            'Admire towering water cascades splashing into Manthokha trout stream',
            'Visit 8th-century Manthal Buddha rock carving',
          ],
          foodRecommendation: 'Steaming <i>Balti Mamtu</i> dumplings with spicy tomato dip',
          stayRecommendation: 'Hotel in Skardu town or Khaplu valley lodge',
        );
      case 5:
        return const ItineraryDay(
          dayNumber: 5,
          title: 'Khaplu Royal Palace & Ancient Wooden Mosque',
          route: 'Skardu ➔ Shyok River Valley ➔ Khaplu Palace ➔ Chaqchan Mosque',
          timing: '08:00 AM – 05:30 PM • Royal Architecture & Sufi Roots',
          attractions: [
            'UNESCO heritage Khaplu Palace (Yabgo Dynasty)',
            '700-year-old Chaqchan Mosque (Timber & Mud Architecture)',
            'Thoqsikhar Viewpoint',
          ],
          activities: [
            'Explore Tibetan-Mughal woodcraft balconies and museum exhibits at Khaplu Palace',
            'Quiet reflection inside ancient 14th-century carved wooden prayer hall',
            'Panoramic sunset view over Shyok and Indus confluence',
          ],
          foodRecommendation: 'Warm <i>Marzan</i> (Balti barley dough with melted butter and apricot sauce)',
          stayRecommendation: 'Serena Khaplu Palace or comfortable lodge in Khaplu',
        );
      case 6:
        return const ItineraryDay(
          dayNumber: 6,
          title: 'Marsur Rock Hike & Katpana Desert Sunset',
          route: 'Skardu ➔ Hussainabad ➔ Marsur Rock Trail ➔ Katpana Desert Sunset',
          timing: '08:00 AM – 06:30 PM • Cliff Hikes & Sunset Dunes',
          attractions: [
            'Marsur Rock (The Trolltunga / Pride Rock of Pakistan)',
            'Katpana High-Altitude Cold Desert',
            'Indus River Confluence',
          ],
          activities: [
            'Thrilling guided hike to Marsur Rock cantilevered cliff edge',
            'Sunset photoshoot where white desert dunes meet snowcapped Karakoram peaks',
            'Evening campfire under star-studded skies',
          ],
          foodRecommendation: 'Fresh apricots, roasted almonds, and hearty yak stew',
          stayRecommendation: 'Luxury resort on Katpana desert edge',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Skardu Old Bazaar & Farewell Journey',
          route: 'Skardu Town ➔ Gemstone Bazaar ➔ Jaglot / Highway ➔ Return to $departing',
          timing: '07:30 AM – 07:00 PM • Craft Souvenirs & Scenic Return',
          attractions: const [
            'Skardu Old Bazaar (Dry Fruit & Aquamarine Gemstone Market)',
            'Indus Gorge Highway Vistas',
            'Shangrila Viewpoint',
          ],
          activities: const [
            'Purchase world-famous Baltistan organic dried apricots, walnuts, and topaz',
            'Farewell photography across scenic mountain passes',
            'Safe return transit to departure city',
          ],
          foodRecommendation: 'Hot <i>Namkeen Gosht</i> and green tea with cardamom',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildSwatDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Mingora & Royal White Palace',
          route: '$departing ➔ M-16 Swat Motorway ➔ Mingora ➔ White Palace Marghazar',
          timing: '07:30 AM – 06:00 PM • Royal Marble Architecture & Gandhara Art',
          attractions: const [
            'White Palace Marghazar (Built from Royal Marble in 1940)',
            'Swat Museum (Gandhara Buddhist Sculptures)',
            'Fizagat Riverbank Park',
          ],
          activities: const [
            'Tour royal white marble suites and natural mountain spring gardens',
            'Inspect ancient Gandhara Buddhist carvings and relics at Swat Museum',
            'Evening tea stroll alongside rushing emerald Swat River',
          ],
          foodRecommendation: 'Authentic Peshawari-Swati <i>Chapli Kebabs</i> with hot roghni naan',
          stayRecommendation: 'Riverfront hotel in Fizagat / Mingora',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Malam Jabba Ski Resort & Pine Mountain Ridges',
          route: 'Mingora ➔ Malam Jabba Mountain Road ➔ Malam Jabba Ski Resort & Chairlift',
          timing: '08:30 AM – 05:30 PM • Alpine Adventure & Chairlift Vistas',
          attractions: [
            'Malam Jabba Ski Resort & Mountain Ridge',
            'Malam Jabba 800m Chairlift & Zipline',
            'Dense Pine Woodland Trails',
          ],
          activities: [
            'Scenic chairlift ride soaring over mist-shrouded green pine valleys',
            'Exciting zipline flight over alpine slopes',
            'Gentle pine needle forest ridge walk with sweeping vistas of Hindu Kush',
          ],
          foodRecommendation: 'Sizzling <i>Shinwari Karahi</i> and sweet Swat farm apples',
          stayRecommendation: 'Pearl Continental Malam Jabba or mountain resort',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Journey to Kalam Valley & Dense Pine Forests',
          route: 'Mingora ➔ Madyan ➔ Bahrain Bazaar ➔ Kalam Valley ➔ Ushu Forest',
          timing: '08:00 AM – 05:30 PM • River Cascades & Alpine Wilderness',
          attractions: [
            'Bahrain River Confluence & Wooden Handicrafts Bazaar',
            'Kalam Valley Plateau',
            'Ushu Dense Alpine Pine Forest',
          ],
          activities: [
            'Stop at Bahrain to admire traditional hand-carved cedar furniture',
            'Scenic drive following roaring torrents of Swat River',
            'Walk through towering Deodar trees in magical Ushu forest',
          ],
          foodRecommendation: 'Pan-Fried Swat River Trout with spicy walnut chutney',
          stayRecommendation: 'Pine lodge in Kalam overlooking mountain rapids',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Mahodand Lake & Saifullah Lake Jeep Expedition',
          route: 'Kalam ➔ Matiltan Waterfall ➔ Mahodand Lake ➔ Saifullah Lake',
          timing: '08:00 AM – 05:00 PM • 4x4 Jeep Trek & Glacial Lakes',
          attractions: [
            'Mahodand Lake (Lake of Fishes in Upper Kalam)',
            'Saifullah Lake & Glacial Waterfalls',
            'Matiltan Roaring Waterfall',
          ],
          activities: [
            '4x4 mountain jeep ride through rugged glacial valleys',
            'Colorful wooden boating on serene Mahodand Lake surrounded by snow peaks',
            'Horse riding along lakeside wildflower meadows',
          ],
          foodRecommendation: 'Fresh riverbank BBQ trout and hot cardamom tea',
          stayRecommendation: 'Riverside wooden resort in Kalam',
        );
      case 5:
        return const ItineraryDay(
          dayNumber: 5,
          title: 'Kundol Lake Alpine Hike or Gabin Jabba Pastures',
          route: 'Kalam ➔ Ladu ➔ Kundol Lake Trail OR Gabin Jabba Alpine Meadows',
          timing: '08:30 AM – 05:30 PM • High Altitude Meadow Exploration',
          attractions: [
            'Kundol Lake (Mirror Lake under Falak Sar)',
            'Gabin Jabba Lush Alpine Pastures',
            'Ladu Glacial Stream',
          ],
          activities: [
            'Guided nature trek to unspoiled turquoise waters of Kundol Lake',
            'Photograph sheep grazing on rolling emerald hill slopes',
            'Campfire relaxation with local acoustic folk music',
          ],
          foodRecommendation: 'Traditional <i>Dum Pukht</i> slow-cooked goat meat and wild berry honey',
          stayRecommendation: 'Eco-camp or wooden cottages in Gabin Jabba / Kalam',
        );
      case 6:
        return const ItineraryDay(
          dayNumber: 6,
          title: 'Ancient Buddhist Heritage & Artisan Guilds',
          route: 'Kalam ➔ Mingora ➔ Butkara I Buddhist Stupa ➔ Saidu Sharif',
          timing: '09:00 AM – 05:00 PM • Gandhara Buddhist Lore & Crafts',
          attractions: [
            'Butkara I Ancient Buddhist Stupa (3rd Century BCE)',
            'Shingardar Stupa',
            'Mingora Emerald & Handloom Shawl Bazaar',
          ],
          activities: [
            'Explore ancient Gandhara Buddhist ruins where pilgrims traveled 2,000 years ago',
            'Shop for world-renowned emerald gemstones and warm pashmina Swati shawls',
            'Visit local woodcarvers and embroidery artisans',
          ],
          foodRecommendation: 'Traditional <i>Swati Doodh Patti</i> chai & crispy <i>Pakoras</i>',
          stayRecommendation: 'Serena Hotel Swat or central Mingora hotel',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Swati Farewell & Scenic Return Journey',
          route: 'Mingora ➔ Malakand Pass ➔ Motorway ➔ Return to $departing',
          timing: '08:00 AM – 06:00 PM • Valley Farewell & Return Drive',
          attractions: const [
            'Malakand Pass & Churchill Picket Viewpoint',
            'Batkhela Bazaar & Dargai Canal',
            'Fizagat Riverside Park',
          ],
          activities: const [
            'Pack tins of pure organic Swat honey and dried walnuts',
            'Final scenic mountain view stops over Malakand valley',
            'Safe return transit to departure city',
          ],
          foodRecommendation: 'Traditional <i>Charsi Tikka</i> at Mardan road junction',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildNaranDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Shogran & Siri Paye Meadows',
          route: '$departing ➔ Hazara Motorway ➔ Balakot ➔ Kiwai ➔ Shogran & Siri Paye',
          timing: '07:00 AM – 06:00 PM • Hazara Highway & Alpine Meadows',
          attractions: const [
            'Kiwai Waterfall Rest Point',
            'Shogran Lush Green Plateau',
            'Siri Paye Meadows & Makra Peak Viewpoint',
          ],
          activities: const [
            'Chai and pakoras with feet dipped in cool Kiwai mountain spring',
            'Thrilling 4x4 jeep ride through pine forests up to Shogran',
            'Horse riding through misty high-altitude horse pastures at Siri Paye',
          ],
          foodRecommendation: 'Hot <i>Desi Chicken Karahi</i> with tandoori naan in Shogran',
          stayRecommendation: 'Pine resort in Shogran overlooking valley clouds',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Fabled Emerald Lake Saif-ul-Malook',
          route: 'Shogran ➔ Naran Town ➔ Saif-ul-Malook Jeep Trail ➔ Saif-ul-Malook Lake',
          timing: '08:30 AM – 05:30 PM • Fairy Tale Lake & Mountain Reflections',
          attractions: [
            'Saif-ul-Malook Lake (Emerald Alpine Wonder at 10,578 ft)',
            'Malika Parbat (Queen of Mountains, 5,290m)',
            'Kunhar River Rapids',
          ],
          activities: [
            'Jeep ride up rocky mountain tracks with panoramic glacier views',
            'Boating on mirror-like emerald waters reflecting Malika Parbat peak',
            'Hear the legend of Prince Saif-ul-Malook and fairy Badi-ul-Jamal from local storytellers',
          ],
          foodRecommendation: 'Fresh River Trout at Kunhar Riverbank Dhabas',
          stayRecommendation: 'Riverfront hotel in Naran Town',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Babusar Top & High Altitude Alpine Lakes',
          route: 'Naran ➔ Batakundi ➔ Lulusar Lake ➔ Babusar Top (13,691 ft)',
          timing: '08:00 AM – 05:30 PM • 13,691 ft Mountain Pass Expedition',
          attractions: [
            'Babusar Top (13,691 ft Pass connecting KPK to Gilgit)',
            'Lulusar Lake (Serene Mirror Glacial Lake)',
            'Pyala Lake (Bowl-shaped Lake at Jalkhad)',
          ],
          activities: [
            'Drive past cascading waterfalls and hairpin mountain curves',
            'Stroll along shores of pristine Lulusar Lake reflecting snow peaks',
            'Stand at Babusar Top viewpoint with cloud inversions on both sides',
          ],
          foodRecommendation: 'Hot <i>Shinwari Karahi</i> and Kashmiri pink chai at Babusar viewpoint',
          stayRecommendation: 'Tourist lodge in Batakundi or Naran',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Lalazar Alpine Plateau & River Rafting',
          route: 'Naran ➔ Batakundi ➔ Lalazar Plateau ➔ Kunhar River Rafting Point',
          timing: '09:00 AM – 05:00 PM • Wildflowers & River Thrills',
          attractions: [
            'Lalazar Plateau (Alpine Wildflower Meadow)',
            'Kunhar River Rafting Stretch',
            'Jalkhad Valley Vistas',
          ],
          activities: [
            'Jeep excursion up to high wildflower meadows of Lalazar',
            'Exciting white-water rafting adventure on Kunhar river',
            'Walk along pine tree trails with views of deep river gorges',
          ],
          foodRecommendation: 'Traditional <i>Namkeen Tikka</i> and hot naan',
          stayRecommendation: 'Cozy hotel in Naran',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Kaghan Crafts & Scenic Return Journey',
          route: 'Naran ➔ Balakot ➔ Abbottabad ➔ Return to $departing',
          timing: '08:00 AM – 06:00 PM • Souvenir Shopping & Scenic Return',
          attractions: const [
            'Naran Main Handicraft Bazaar',
            'Balakot Kunhar Suspension Bridge',
            'Hazara Mountain Vistas',
          ],
          activities: const [
            'Shop for handmade wool shawls, honey, and walnut wood crafts',
            'Farewell lunch by the Kunhar riverbank',
            'Safe return drive to departure city',
          ],
          foodRecommendation: 'Famous fried fish and hot chapli kebabs in Balakot',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildFairyMeadowsDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Raikot Bridge & Tattu Village',
          route: '$departing ➔ Karakoram Highway ➔ Chilas ➔ Raikot Bridge ➔ Tattu Village',
          timing: '06:00 AM – 05:30 PM • Karakoram Highway & Thrilling Jeep Track',
          attractions: const [
            'Karakoram Highway Mountain Canyons',
            'Raikot Bridge over Indus River',
            'Tattu Mountain Village',
          ],
          activities: const [
            'Drive along dramatic desert mountain canyons of Indus River',
            'Exciting 4x4 mountain jeep ride along world-famous cliffside Tattu trail',
            'Overnight acclimatization rest in Tattu village',
          ],
          foodRecommendation: 'Hearty chicken pulao and hot mountain chai',
          stayRecommendation: 'Mountain lodge in Tattu village',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Pine Forest Trek to Fairy Meadows',
          route: 'Tattu Village ➔ Alpine Pine Forest Trail ➔ Fairy Meadows Plateau',
          timing: '08:30 AM – 03:30 PM • Alpine Hike & 8,126m Killer Mountain Vistas',
          attractions: [
            'Fairy Meadows Lush Alpine Plateau (3,300m)',
            'Nanga Parbat (8,126m Raikot Face)',
            'Raikot Glacial Stream',
          ],
          activities: [
            'Scenic 3 to 4-hour hike through cool pine and birch woodlands',
            'First breathtaking view of towering ice walls of Nanga Parbat',
            'Relax in wooden log cabins overlooking the snow giant',
          ],
          foodRecommendation: 'Warm vegetable noodle soup and hot tandoori flatbread',
          stayRecommendation: 'Traditional wooden log cabin / cottage in Fairy Meadows',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Reflection Lake & Beyal Camp Trek',
          route: 'Fairy Meadows ➔ Reflection Lake ➔ Beyal Camp (Birch Woods)',
          timing: '09:00 AM – 04:30 PM • Mirror Lakes & Birch Glades',
          attractions: [
            'Fairy Meadows Reflection Lake (Mirrors Nanga Parbat summit)',
            'Beyal Camp (Quiet Alpine Meadow)',
            'Raikot Glacier Moraine',
          ],
          activities: [
            'Capture mirror-still morning reflections of Nanga Parbat in the lake',
            'Gentle 2-hour walk through alpine meadows to Beyal Camp',
            'Hot cup of kahwa tea watching ice avalanches tumble down distant ridges',
          ],
          foodRecommendation: 'Fresh mountain dal, steamed rice, and spicy achar',
          stayRecommendation: 'Wooden cottage in Fairy Meadows or Beyal Camp',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Nanga Parbat Base Camp & German Viewpoint',
          route: 'Beyal Camp ➔ German Viewpoint ➔ Nanga Parbat Base Camp (3,900m)',
          timing: '07:30 AM – 05:00 PM • Glacial Ice & High Base Camp',
          attractions: [
            'German Viewpoint (Dramatic Glacier Edge)',
            'Nanga Parbat Base Camp (3,967m)',
            'Raikot Glacier Seracs',
          ],
          activities: [
            'Trek up to edge of giant Raikot glacier with views of ice pinnacles',
            'Visit historic German climber expedition memorial plaque',
            'High-altitude mountaineering photography under the Killer Mountain',
          ],
          foodRecommendation: 'Energy trail mix, warm soup, and evening bonfire dinner',
          stayRecommendation: 'Fairy Meadows log cabin',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Dawn Golden Hour, Hike Down & Return Transit',
          route: 'Fairy Meadows ➔ Tattu Village ➔ Raikot Bridge ➔ Return to $departing',
          timing: '06:00 AM – 07:00 PM • Golden Sunrise & Return Journey',
          attractions: const [
            'Nanga Parbat Golden Dawn Sunbeams',
            'Tattu Pine Trail',
            'Karakoram Highway Vistas',
          ],
          activities: const [
            'Catch golden hour sunlight touching Nanga Parbat summit ice',
            'Hike down to Tattu village and jeep descent to Raikot Bridge',
            'Safe highway return journey to departure city',
          ],
          foodRecommendation: 'Highway Shinwari mutton karahi with freshly baked naan',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildNeelumDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Muzaffarabad & Keran Valley',
          route: '$departing ➔ Murree Expressway ➔ Muzaffarabad ➔ Dhani Waterfall ➔ Keran',
          timing: '07:30 AM – 06:00 PM • Kashmir Valley Entry & Waterfalls',
          attractions: const [
            'Dhani Roaring Waterfall',
            'Kutton Jagran Hydro Waterfall',
            'Keran Neelum Riverbank (Line of Control view)',
          ],
          activities: const [
            'Admire white water sprays at Dhani waterfall',
            'Stroll along Neelum riverbank looking across at Indian-administered Kashmir',
            'Evening riverside campfire under walnut trees',
          ],
          foodRecommendation: 'Authentic Kashmiri <i>Gustaba</i> & <i>Rogan Josh</i> with saffron rice',
          stayRecommendation: 'Riverside wooden resort in Keran',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Ancient Sharda Peeth University & Historic Caves',
          route: 'Keran ➔ Dowarian ➔ Sharda Peeth Temple & University Ruins ➔ Kishan Ghati',
          timing: '08:30 AM – 05:30 PM • 6th-Century Ancient Knowledge & Caves',
          attractions: [
            'Sharda Peeth Ancient 6th-Century University & Temple Ruins',
            'Kishan Ghati Historic Caves',
            'Sharda Wooden Suspension Bridge',
          ],
          activities: [
            'Explore ancient sandstone pillars of Sharda temple university',
            'Hike up to legendary Kishan Ghati caves overlooking Sharda town',
            'Cross scenic wooden bridge over turquoise Neelum river',
          ],
          foodRecommendation: 'Fresh River Trout and hot Kashmiri Noon Chai with Bakarkhani',
          stayRecommendation: 'Scenic hotel in Sharda overlooking the river',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Arang Kel - Pearl of Neelum Valley',
          route: 'Sharda ➔ Kel Town ➔ Kel Chairlift ➔ Arang Kel Alpine Plateau',
          timing: '08:30 AM – 05:30 PM • Chairlift & Green Alpine Plateau',
          attractions: [
            'Kel Town River Confluence',
            'Arang Kel Chairlift over gorge',
            'Arang Kel Green Alpine Plateau (Pearl of Neelum)',
          ],
          activities: [
            'Thrilling cable car ride across roaring Neelum river gorge',
            'Hike through emerald pine woodlands up to Arang Kel plateau',
            'Photograph traditional wooden Kashmiri houses nestled against glaciers',
          ],
          foodRecommendation: 'Kashmiri Kulcha, local curd, and honey flatbread',
          stayRecommendation: 'Wooden cottage on Arang Kel plateau',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Ratti Gali Glacial Lake 4x4 Jeep Excursion',
          route: 'Sharda ➔ Dowarian ➔ 4x4 Jeep Track ➔ Ratti Gali Basecamp & Alpine Lake',
          timing: '07:30 AM – 06:00 PM • Turquoise Glacial Lake at 12,130 ft',
          attractions: [
            'Ratti Gali Glacial Lake (Turquoise Alpine Wonder)',
            'Dowarian Pine Gorge',
            'Red Wildflower Meadow Plateau',
          ],
          activities: [
            'Adventurous 4x4 jeep ride along cascading mountain torrents',
            'Hike across red and yellow wildflower meadows to the lake edge',
            'Sit in awe of hanging glaciers dripping directly into sapphire waters',
          ],
          foodRecommendation: 'Warm vegetable noodle soup and hot cardamom chai at basecamp',
          stayRecommendation: 'Lakeside glamping tent or return to Keran hotel',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Taobat Border Settlement & Kashmiri Farewell',
          route: 'Kel ➔ Taobat Valley ➔ Muzaffarabad ➔ Return to $departing',
          timing: '07:00 AM – 07:30 PM • Untouched Border Paradise & Return',
          attractions: const [
            'Taobat (Last Village of Neelum Valley)',
            'Gagai Glacial Stream Confluence',
            'Kashmir Artisan Craft Bazaars',
          ],
          activities: const [
            'Admire crystal-clear Gagai stream meeting Neelum river in Taobat',
            'Shop for authentic Kashmiri wool shawls, dry walnuts, and wooden crafts',
            'Safe return transit to departure city',
          ],
          foodRecommendation: 'Traditional <i>Kashmiri Pulao</i> and sweet Phirni',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildGwadarDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Makran Coastal Highway & Kund Malir',
          route: '$departing ➔ Makran Coastal Highway (N-10) ➔ Hingol National Park ➔ Kund Malir Beach',
          timing: '07:30 AM – 06:00 PM • Scenic Ocean Highway & Rock Sculptures',
          attractions: const [
            'Princess of Hope Natural Rock Sculpture',
            'Sphinx of Balochistan',
            'Kund Malir Golden Sand Beach & Azure Ocean',
          ],
          activities: const [
            'Drive along world-famous scenic Makran coastal highway where desert meets sea',
            'Photograph natural rock sculptures carved over millennia by Arabian winds',
            'Golden hour swim and beach walk at pristine Kund Malir beach',
          ],
          foodRecommendation: 'Fresh Grilled Pomfret & Red Snapper at coastal seafood dhabas',
          stayRecommendation: 'Beachside resort camp at Kund Malir or Ormara',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Ormara Turtle Beaches & Gwadar Marine Drive',
          route: 'Kund Malir ➔ Buzi Pass ➔ Ormara Beach ➔ Gwadar Marine Drive',
          timing: '08:30 AM – 06:00 PM • Coastal Cliffs & Modern Harbor City',
          attractions: [
            'Buzi Pass Coastal Cliffs',
            'Ormara Beach (Green Turtle Sanctuary)',
            'Gwadar Marine Drive & Sunset Point',
          ],
          activities: [
            'Drive through lunar landscape of Buzi Pass',
            'Relax along uncrowded white sands of Ormara beach',
            'Sunset drive along modern Gwadar Marine Drive watching ocean waves crash',
          ],
          foodRecommendation: 'Authentic <i>Balochi Sajji</i> roasted on open wood fires with special Kaak bread',
          stayRecommendation: 'Sea view hotel on Gwadar Marine Drive',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Hammerhead Rock & Koh-e-Batil Cliff Panorama',
          route: 'Gwadar Town ➔ Koh-e-Batil (Hammerhead Rock) ➔ Old Gwadar Wooden Boat Docks',
          timing: '08:30 AM – 05:30 PM • Geological Wonder & Maritime Heritage',
          attractions: [
            'Hammerhead Rock (Koh-e-Batil)',
            'Koh-e-Batil 600-step Cliffside Stairway',
            'Old Gwadar Fish Harbor (Century-old wooden boat building)',
          ],
          activities: [
            'Climb historic stone stairs up Koh-e-Batil for bird-eye view of twin bays',
            'Watch skilled craftsmen hand-carve massive teakwood fishing dhows',
            'Speedboat ride across Gwadar East Bay',
          ],
          foodRecommendation: 'Fresh Jumbo Prawns, Grilled Lobster, and chilled coconut water',
          stayRecommendation: 'Pearl Continental Gwadar or Marine Drive hotel',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Astola Island or Hingol Mud Volcanoes Excursion',
          route: 'Gwadar ➔ Pasni ➔ Astola Island Boat Point OR Chandragup Mud Volcanoes',
          timing: '07:30 AM – 05:30 PM • Volcanic Wonders & Coral Reefs',
          attractions: [
            'Chandragup Mud Volcanoes (Active bubbling sacred mud cones)',
            'Hinglaj Mata Temple in Hingol Gorge',
            'Astola Island Marine Vistas',
          ],
          activities: [
            'Hike up 300-ft bubbling sacred mud volcano crater at Chandragup',
            'Explore ancient rock-cut pilgrimage gorge at Hinglaj Mata',
            'Astrophotography under crystal clear dark coastal skies',
          ],
          foodRecommendation: 'Traditional Balochi mutton roast and sweet Halwa',
          stayRecommendation: 'Comfortable hotel in Gwadar / Ormara',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Gwadar Port Vistas, Omani Fort & Return',
          route: 'Gwadar Town ➔ Omani Fort Ruins ➔ Free Zone Point ➔ Return to $departing',
          timing: '08:00 AM – 06:00 PM • Historic Forts & Return Journey',
          attractions: const [
            'Historic Omani Fort Ruins',
            'Gwadar Deep Sea Port Viewpoint',
            'Shahi Bazaar Balochi Embroidery Market',
          ],
          activities: const [
            'Tour remnants of 200-year-old Omani sultanate rule in Gwadar',
            'Shop for authentic hand-embroidered Balochi dresses and dry dates',
            'Scenic coastal drive back to departure city',
          ],
          foodRecommendation: 'Hot <i>Doodh Patti</i> chai and traditional fresh seafood platter',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildLahoreDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Lahore & Walled City Exploration',
          route: '$departing ➔ M-2 Motorway ➔ Lahore Walled City ➔ Delhi Gate',
          timing: '08:00 AM – 06:30 PM • Heritage & Cultural Tour',
          attractions: const [
            'Shahi Hammam (Royal Bath)',
            'Wazir Khan Mosque (Persian Frescoes)',
            'Fort Road Food Street',
          ],
          activities: const [
            'Walking tour through ancient Delhi Gate & bazaars',
            'Architectural fresco photography inside Wazir Khan Mosque',
            'Rooftop welcome dinner overlooking Badshahi Mosque',
          ],
          foodRecommendation: 'Famous <i>Phikkay ki Jalebi</i> & authentic <i>Mutton Karahi</i> at Fort Road',
          stayRecommendation: 'Heritage boutique hotel in Gulberg / Mall Road',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Mughal Splendor & Historic Forts',
          route: 'Gulberg ➔ Lahore Fort ➔ Badshahi Mosque ➔ Greater Iqbal Park',
          timing: '09:00 AM – 06:00 PM • Monument Discovery',
          attractions: [
            'UNESCO World Heritage Lahore Fort & Sheesh Mahal',
            'Grand Badshahi Mosque',
            'Minar-e-Pakistan',
          ],
          activities: [
            'Guided exploration of Mughal royal chambers and mirror palace',
            'Historic courtyard stroll at Badshahi Mosque',
            'Souvenir shopping in Anarkali Bazaar',
          ],
          foodRecommendation: 'Traditional <i>Halwa Puri</i> & slow-cooked <i>Siri Paye</i> in Old Anarkali',
          stayRecommendation: 'Comfortable central hotel in Lahore',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Shalimar Gardens & Wagah Border Ceremony',
          route: 'Lahore ➔ Shalimar Gardens ➔ Wagah Border Parade ➔ Packages Mall',
          timing: '10:00 AM – 07:30 PM • Gardens & Patriotic Excursion',
          attractions: [
            '3-Tier Mughal Shalimar Gardens',
            'Wagah Border Flag Lowering Ceremony',
            'Lahore Museum (Gandhara Fasting Buddha)',
          ],
          activities: [
            'Stroll across Mughal water cascades and marble pavilions',
            'Witness high-energy Wagah Border military parade',
            'Explore ancient Harappan and Gandharan artifacts',
          ],
          foodRecommendation: 'Authentic <i>Murgh Chanay</i> & rich saffron <i>Falooda</i>',
          stayRecommendation: 'Serena / Pearl Continental or boutique stay in Gulberg',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Colonial Architecture & Cultural Arts Trail',
          route: 'Gulberg ➔ Mall Road ➔ National College of Arts ➔ Alhamra Arts Council',
          timing: '09:30 AM – 06:00 PM • Arts, Literature & Gardens',
          attractions: [
            'Alhamra Cultural Complex',
            'National College of Arts & Tollinton Market',
            'Jinnah Garden (Lawrence Gardens)',
          ],
          activities: [
            'Browse contemporary Pakistani art exhibits at Alhamra',
            'Colonial architectural photography along historic Mall Road',
            'Relaxing evening tea in lush botanical Lawrence Gardens',
          ],
          foodRecommendation: 'Famous <i>Tawa Chicken</i> at Lakshmi Chowk with hot <i>Roghni Naan</i>',
          stayRecommendation: 'Boutique hotel in Gulberg Lahore',
        );
      case 5:
        return const ItineraryDay(
          dayNumber: 5,
          title: 'Royal Tombs & Ravi Riverfront Heritage',
          route: 'Gulberg ➔ Shahdara ➔ Tomb of Jahangir ➔ Tomb of Nur Jahan',
          timing: '09:00 AM – 05:00 PM • Mughal Mausoleums & Waterworks',
          attractions: [
            'Tomb of Emperor Jahangir (Intricate Pietra Dura)',
            'Tomb of Empress Nur Jahan',
            'Asif Khan Mausoleum',
          ],
          activities: [
            'Admire symmetrical Charbagh gardens and marble inlay work',
            'Quiet historic photography along Ravi riverbanks',
            'Evening coffee and dessert on MM Alam Road in Gulberg',
          ],
          foodRecommendation: 'Authentic Nihari at Waris Nihari & Kasuri Falooda',
          stayRecommendation: 'Central Lahore hotel',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Artisan Souvenirs & Farewell Feast',
          route: 'Gulberg ➔ Liberty Market ➔ Anarkali Bazaar ➔ Return Journey to $departing',
          timing: '10:00 AM – 06:00 PM • Shopping & Return Journey',
          attractions: const [
            'Liberty Market Artisan Quarter',
            'Anarkali Traditional Khussa & Bangles Bazaar',
            'Pak Tea House',
          ],
          activities: const [
            'Shop for authentic handmade truck-art souvenirs and embroidered shawls',
            'Chai stop at historic literary landmark Pak Tea House',
            'Safe return journey to departure city',
          ],
          foodRecommendation: 'Fresh Butt Karahi & famous Goga Naqeebia Murgh Chanay',
          stayRecommendation: 'Safe return journey to $departing',
        );
    }
  }

  static ItineraryDay _buildMultanDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Multan & Historic Sufi Shrines',
          route: '$departing ➔ M-4 Motorway ➔ Multan Fort ➔ Qasim Bagh',
          timing: '08:00 AM – 06:30 PM • Sufi Heritage & Architecture',
          attractions: const [
            'Shrine of Shah Rukn-e-Alam (14th-century octagonal dome)',
            'Shrine of Bahauddin Zakariya',
            'Multan Fort & Qasim Bagh Panoramic View',
          ],
          activities: const [
            'Admire intricate blue Kashikari glazed tile architecture',
            'Courtyard walking tour and Sufi history overview',
            'Rooftop sunset view over ancient Multan city',
          ],
          foodRecommendation: 'Famous <i>Hafiz Sohan Halwa</i> & fresh fried fish at Bohar Gate',
          stayRecommendation: 'Central boutique hotel on Abdali Road / Cantt',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Tomb of Shah Shams & Blue Pottery Artisan Guilds',
          route: 'Cantt ➔ Tomb of Shah Shams Tabrez ➔ Institute of Blue Pottery ➔ Hussain Agahi',
          timing: '09:00 AM – 06:00 PM • Craft & Market Exploration',
          attractions: [
            'Tomb of Shah Shams Tabrez',
            'Institute of Blue Pottery Development (Kashikari)',
            'Hussain Agahi Traditional Bazaar',
          ],
          activities: [
            'Live master demonstration of traditional blue pottery painting',
            'Shop for authentic camel-skin lamps and hand-embroidered shawls',
            'Street culinary tasting in historic bazaars',
          ],
          foodRecommendation: 'Traditional <i>Doli Roti</i> & spicy Multani Gol Gappay at Ghanta Ghar',
          stayRecommendation: 'Comfortable hotel in Gulgasht / Cantt Multan',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Bahawalpur Royal Palaces Excursion',
          route: 'Multan ➔ Bahawalpur ➔ Noor Mahal ➔ Darbar Mahal',
          timing: '08:30 AM – 06:00 PM • Italianate Châteaux & Royal Heritage',
          attractions: [
            'Noor Mahal (1872 Italianate Royal Palace)',
            'Darbar Mahal Architectural Grounds',
            'Bahawalpur Central Museum',
          ],
          activities: [
            'Tour grand royal throne room and antique armory at Noor Mahal',
            'Marvel at red sandstone Anglo-Mughal arches at Darbar Mahal',
            'Photograph royal horse carriages and rare manuscripts',
          ],
          foodRecommendation: 'Traditional <i>Multani Mutton Karahi</i> & chilled Rabri Falooda',
          stayRecommendation: 'Royal Continental Hotel or boutique stay in Bahawalpur',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Derawar Fort & Cholistan Desert Safari',
          route: 'Bahawalpur ➔ Cholistan Desert ➔ Derawar Fort ➔ Royal Tombs of Abbasi Nawabs',
          timing: '07:30 AM – 06:00 PM • Desert Strongholds & Camel Safaris',
          attractions: [
            'Derawar Fort (40 Monumental Bastions rising from desert sands)',
            'Abbasi Royal Family Marble Tombs',
            'Cholistan Desert Rolling Sand Ridges',
          ],
          activities: [
            'Explore colossal 30-meter high brick bastions of 9th-century desert fortress',
            'Camel safari across golden Cholistan sand ridges',
            'Sunset desert photography over historic oasis',
          ],
          foodRecommendation: 'Authentic Cholistani <i>Sajji</i> & desert spiced tea',
          stayRecommendation: 'Desert safari camp or return hotel in Bahawalpur',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Clock Tower, Gardens & Farewell Feast',
          route: 'Multan ➔ Ghanta Ghar (Clock Tower) ➔ Chaman Zar Askari Lake ➔ Return to $departing',
          timing: '09:30 AM – 05:00 PM • Heritage landmarks and return',
          attractions: const [
            'Clock Tower Multan (Ghanta Ghar)',
            'Patrick Alexander Vans Agnew Monument',
            'Chaman Zar Askari Lake Park',
          ],
          activities: const [
            'Colonial architecture photography at Ghanta Ghar',
            'Relaxing boat ride at Askari Lake',
            'Souvenir box packing of Multani Rewari and Sohan Halwa',
          ],
          foodRecommendation: 'Authentic <i>Multani Mutton Karahi</i> & chilled Rabri Falooda',
          stayRecommendation: 'Safe return journey to $departing',
        );
    }
  }

  static ItineraryDay _buildKumratDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Upper Dir & Thal Gateway',
          route: '$departing ➔ M-16 Motorway ➔ Chakdara ➔ Upper Dir ➔ Thal Village',
          timing: '07:00 AM – 06:00 PM • Scenic Mountain River Drive',
          attractions: const [
            'Panjkora River Gorges',
            'Thal Historic Hand-Carved Wooden Mosque',
            'Kumrat Valley Gateway',
          ],
          activities: const [
            'Scenic drive following roaring turquoise waters of Panjkora river',
            'Admire century-old carved cedar wood pillars at Thal central mosque',
            'Check-in and evening bonfire by the river',
          ],
          foodRecommendation: 'Fresh river trout & hot Shinwari karahi with tandoori naan',
          stayRecommendation: 'Wooden cottages or riverside tourist camp in Thal / Kumrat',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Kumrat Dense Deodar Forest & Big Waterfall',
          route: 'Thal ➔ Kumrat National Pine Forest ➔ Kumrat Roaring Waterfall',
          timing: '08:30 AM – 05:30 PM • Towering Conifers & Cascades',
          attractions: [
            'Kumrat Giant Deodar Forest (Towering 200ft Trees)',
            'Kumrat Big Waterfall',
            'Panjkora River Sandy Embankment',
          ],
          activities: [
            'Walk through misty cathedral-like Deodar pine forest glades',
            'Photograph mighty Kumrat waterfall splashing onto glacial boulders',
            'Riverside picnic and pine forest relaxation',
          ],
          foodRecommendation: 'Tandoori chicken tikka skewers & hot cardamom tea',
          stayRecommendation: 'Pine forest glamping resort in Kumrat',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Kala Chashma Springs & Do Janga River Confluence',
          route: 'Kumrat Forest ➔ Kala Chashma (Black Water Spring) ➔ Do Janga Confluence',
          timing: '08:30 AM – 05:00 PM • Crystal Springs & Alpine Glades',
          attractions: [
            'Kala Chashma (Crystal Clear Natural Spring)',
            'Do Janga (Meeting point of two alpine rivers)',
            'Shahzore Glacial Valley Vista',
          ],
          activities: [
            'Drink pristine cold mineral water from natural Kala Chashma spring',
            'Hike along gentle river gravel banks at Do Janga confluence',
            'Landscape photography of untouched northern pine valleys',
          ],
          foodRecommendation: 'Local Swati-Dir mutton stew with wild mountain herbs',
          stayRecommendation: 'Eco-lodge in Kumrat Valley',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Jahaz Banda Meadows & Katora Lake Trek',
          route: 'Kumrat ➔ Chupral ➔ 4x4 Jeep ➔ Jahaz Banda Alpine Meadows',
          timing: '07:30 AM – 05:30 PM • 10,000 ft High Alpine Plateau',
          attractions: [
            'Jahaz Banda Lush Alpine Meadows',
            'Jahaz Banda Waterfall',
            'Katora Lake Trailhead Viewpoint',
          ],
          activities: [
            'Adventurous 4x4 mountain jeep track up to alpine plateau of Jahaz Banda',
            'Hike across sprawling emerald meadows dotted with wildflowers and sheep',
            'Spectacular views of bowl-shaped glacial peaks',
          ],
          foodRecommendation: 'Warm chicken soup and fresh chapati around campsite bonfire',
          stayRecommendation: 'Wooden hut or alpine tent at Jahaz Banda',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Kumrat Farewell & Scenic Return Journey',
          route: 'Kumrat / Thal ➔ Upper Dir ➔ Timergara ➔ Return to $departing',
          timing: '07:30 AM – 06:30 PM • Valley Farewell & Return Drive',
          attractions: const [
            'Timergara Riverfront Viewpoint',
            'Malakand Scenic Pass',
            'Local Honey & Walnut Stalls',
          ],
          activities: const [
            'Pack pure organic Dir pine honey and mountain walnuts',
            'Final panoramic photo stops overlooking Dir mountains',
            'Safe return transit to departure city',
          ],
          foodRecommendation: 'Famous <i>Chapli Kebabs</i> at Batkhela bazaar',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildChitralDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Lowari Tunnel & Chitral Town',
          route: '$departing ➔ M-16 Motorway ➔ Lowari Tunnel ➔ Chitral Town',
          timing: '06:30 AM – 06:00 PM • 10.4km Lowari Pass Tunnel & River Forts',
          attractions: const [
            'Lowari Tunnel (10.4km Engineering Marvel)',
            'Chitral Shahi Mosque (Mughal Style Red Architecture)',
            'Chitral Royal Fort on Kunar River',
          ],
          activities: const [
            'Scenic drive cutting beneath high mountain ridges via Lowari Tunnel',
            'Inspect historic royal fort chambers of the Mehtar of Chitral',
            'Evening stroll through Chitral bazaar beneath shadow of Tirich Mir',
          ],
          foodRecommendation: 'Traditional <i>Ghalmandi</i> (stuffed flatbread with fresh cottage cheese) & tea',
          stayRecommendation: 'Chitral Serena Hotel or central town hotel',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'Bumburet Valley - Heart of Ancient Kalash Culture',
          route: 'Chitral Town ➔ Ayun Valley ➔ Bumburet Valley (Kalash)',
          timing: '08:30 AM – 05:30 PM • Unique Animist Living Heritage',
          attractions: [
            'Bumburet Kalash Valley & Cedar Villages',
            'Kalasha Dur Heritage Museum (Brun)',
            'Traditional Kalash Dancing Grounds (Charsue)',
          ],
          activities: [
            'Discover vibrant heritage, beaded headdresses, and embroidered dresses of Kalash people',
            'Guided tour of Kalasha Dur cultural preservation museum',
            'Walk among multi-tiered wooden log homes clinging to hillsides',
          ],
          foodRecommendation: 'Warm walnut bread, local goat cheese, and fresh apricot tea',
          stayRecommendation: 'Traditional tourist lodge in Bumburet Kalash',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Rumbur & Birir Untouched Kalash Valleys',
          route: 'Bumburet ➔ Rumbur Valley (Grum) ➔ Local Artisan Workshops',
          timing: '09:00 AM – 05:00 PM • Pristine Ancient Settlements',
          attractions: [
            'Rumbur Valley (Most authentic traditional settlement)',
            'Ancient Wooden Altars & Shrines',
            'Handicraft Weaving Centers',
          ],
          activities: [
            'Hike through untouched village paths in Rumbur',
            'Meet local artisans hand-weaving colorful wool belts and bead jewelry',
            'Listen to oral folklore and ancient songs passed down millennia',
          ],
          foodRecommendation: 'Traditional <i>Sanabachi</i> bread & herbal mountain tea',
          stayRecommendation: 'Cozy guest house in Bumburet or Chitral',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Garam Chashma Hot Springs & Tirich Mir Views',
          route: 'Chitral Town ➔ Garam Chashma (Hot Springs) ➔ Shoghor Gorge',
          timing: '08:30 AM – 05:00 PM • Healing Springs & 7,708m Giant Vistas',
          attractions: [
            'Garam Chashma Natural Sulfur Hot Springs',
            'Vistas of Tirich Mir (7,708m Highest Peak of Hindu Kush)',
            'Lutkho River Gorges',
          ],
          activities: [
            'Relaxing soak in therapeutic mineral hot spring baths',
            'Marvel at jagged snowy crown of Tirich Mir from elevated viewpoints',
            'Purchase warm handmade Chitrali Patti woolen shawls and caps',
          ],
          foodRecommendation: 'Authentic <i>Chitrali Pulao</i> and roasted lamb kebabs',
          stayRecommendation: 'Hotel in Chitral town',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Historic Polo Ground & Farewell Journey',
          route: 'Chitral ➔ Chitral Polo Ground ➔ Lowari Tunnel ➔ Return to $departing',
          timing: '07:30 AM – 06:30 PM • Mountain Sports & Scenic Return',
          attractions: const [
            'Chitral Historic Polo Ground',
            'Shahi Bazaar Chitral Patti Woolen Guilds',
            'Lowari Mountain Vistas',
          ],
          activities: const [
            'Visit historic polo ground where freestyle polo has been played for centuries',
            'Pick up signature Chitrali Pakol caps and gemstone souvenirs',
            'Safe return journey to departure city',
          ],
          foodRecommendation: 'Hot Shinwari chicken karahi with fresh tandoori naan',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildIslamabadDay(int day, String departing, int totalDays) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to Islamabad: Faisal Mosque & Margalla Heights',
          route: '$departing ➔ Islamabad ➔ Faisal Mosque ➔ Daman-e-Koh ➔ Pir Sohawa',
          timing: '08:30 AM – 07:00 PM • Iconic Architecture & Panoramic Heights',
          attractions: const [
            'Grand Faisal Mosque (Modern Bedouin Architecture)',
            'Daman-e-Koh Elevated Viewpoint',
            'Pir Sohawa (Monal Panoramic Lookout at 3,600 ft)',
          ],
          activities: const [
            'Tour monumental white marble prayer halls of Faisal Mosque beneath Margalla Hills',
            'Panoramic bird-eye viewing of Islamabad grid layout from Daman-e-Koh terraces',
            'Sunset dinner on Margalla heights with sparkling city lights below',
          ],
          foodRecommendation: 'Fine dining Karahi & BBQ at Monal / La Montana on Margalla Heights',
          stayRecommendation: 'Serena Islamabad or boutique hotel in F-7 / Blue Area',
        );
      case 2:
        return const ItineraryDay(
          dayNumber: 2,
          title: 'National Monuments & Living Folk Heritage',
          route: 'Islamabad ➔ Shakarparian ➔ Pakistan Monument ➔ Lok Virsa Museum ➔ Saidpur Village',
          timing: '09:00 AM – 06:30 PM • National History & Mughal Village',
          attractions: [
            'Pakistan Monument (Granite Petal Architecture)',
            'Lok Virsa Folk Heritage Museum',
            'Saidpur 500-year-old Mughal & Hindu Heritage Village',
          ],
          activities: [
            'Explore wax exhibits depicting Pakistan\'s diverse provincial cultures at Lok Virsa',
            'Photograph blooming petal pavilion of Pakistan Monument',
            'Stroll through ancient brick alleys and art galleries of Saidpur Village',
          ],
          foodRecommendation: 'Traditional Desi Dhabba dining in Saidpur Village with hot tandoori roghni naan',
          stayRecommendation: 'Comfortable central hotel in Islamabad',
        );
      case 3:
        return const ItineraryDay(
          dayNumber: 3,
          title: 'Margalla Forest Trails & Rawal Lake Promenade',
          route: 'Islamabad ➔ Margalla Trail 3 or Trail 5 ➔ Rawal Lake & Lake View Park',
          timing: '07:30 AM – 05:30 PM • Pine Woodland Hikes & Watersports',
          attractions: [
            'Margalla Hills Trail 5 (Streams & Pine Woodland Hike)',
            'Rawal Lake & Lake View Park Promenade',
            'F-7 Markaz / Beverly Center Artisan Cafes',
          ],
          activities: [
            'Morning nature hike along freshwater bubbling stream in Trail 5',
            'Boating on tranquil waters of Rawal Lake watching migratory waterfowl',
            'Evening coffee and pastry hopping in lively F-7 Markaz',
          ],
          foodRecommendation: 'Sizzling platters at Beverly Center or traditional Shinwari Karahi',
          stayRecommendation: 'Top-rated hotel in Islamabad',
        );
      case 4:
        return const ItineraryDay(
          dayNumber: 4,
          title: 'Ancient Gandhara UNESCO Ruins at Taxila',
          route: 'Islamabad ➔ Taxila (30 mins drive) ➔ Taxila Museum ➔ Dharmarajika Stupa ➔ Khanpur Dam',
          timing: '08:30 AM – 06:00 PM • 2,500-Year-Old Buddhist Civilization',
          attractions: [
            'Taxila Museum (Gandhara Buddhist Gold & Sculpture Masterpieces)',
            'Dharmarajika Ancient Stupa (Built by Emperor Ashoka)',
            'Khanpur Dam (Turquoise Reservoir & Jet Skiing)',
          ],
          activities: [
            'Walk among ancient monastery ruins where Alexander the Great once visited',
            'Inspect world-class Gandharan Buddhist relics at Taxila Museum',
            'Jet skiing and cliff diving at scenic Khanpur Dam reservoir',
          ],
          foodRecommendation: 'Fresh deep-fried Rahu fish by Khanpur Dam waterbank',
          stayRecommendation: 'Central hotel in Islamabad / Rawalpindi',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Historic Rawalpindi Bazaars & Farewell',
          route: 'Islamabad ➔ Raja Bazaar ➔ Saddar Colonial Quarter ➔ Golra Railway Museum ➔ Return to $departing',
          timing: '09:00 AM – 05:30 PM • Bazaars & Rail Heritage',
          attractions: const [
            'Raja Bazaar (Historic Old Pindi Spice & Brass Market)',
            'Golra Sharif Victorian Railway Heritage Museum',
            'Centaurus Mall Observation Deck',
          ],
          activities: const [
            'Explore vibrant labyrinth of traditional bazaars in Old Rawalpindi',
            'Tour vintage British colonial steam locomotives and royal carriages at Golra',
            'Safe return journey to departure destination',
          ],
          foodRecommendation: 'Authentic <i>Savour Foods Crispy Chicken Pulao</i> with Shami kebabs',
          stayRecommendation: 'Safe journey back home to $departing',
        );
    }
  }

  static ItineraryDay _buildCustomDestinationDay(
    int day,
    String departing,
    String destination,
    int totalDays,
    List<String> interests,
  ) {
    switch (day) {
      case 1:
        return ItineraryDay(
          dayNumber: 1,
          title: '$departing to $destination: Gateway & Scenic Arrival',
          route: '$departing ➔ Scenic Highway Corridor ➔ Welcome to $destination',
          timing: '07:30 AM – 06:00 PM • Highway Corridor & Check-in',
          attractions: [
            '$destination Valley Gateway',
            'Central $destination Panoramic Viewpoint',
            'Main Boulevard & Historic Welcome Square',
          ],
          activities: const [
            'Scenic highway landscape photography',
            'Check-in and orientation walking tour',
            'Welcome regional dinner experience',
          ],
          foodRecommendation: 'Traditional regional specialty platter with hot tandoori naan and green tea',
          stayRecommendation: 'Comfortable central tourist hotel in $destination',
        );
      case 2:
        return ItineraryDay(
          dayNumber: 2,
          title: '$destination Heritage & Iconic Landmarks',
          route: 'Central $destination ➔ Historic Quarter ➔ Architectural Monument',
          timing: '09:00 AM – 06:00 PM • Culture & Landmark Exploration',
          attractions: [
            'Historic $destination Landmark & Monument',
            'Ancient Fort / Architectural Heritage Landmark',
            'Old Town Heritage Cultural Quarter',
          ],
          activities: const [
            'Guided architectural and historical walking tour',
            'Historic photography and local storytelling',
            'Traditional afternoon tea in historic old bazaar',
          ],
          foodRecommendation: 'Authentic regional karahi with freshly baked roghni naan',
          stayRecommendation: 'Boutique heritage guest house in $destination',
        );
      case 3:
        return ItineraryDay(
          dayNumber: 3,
          title: 'Scenic Natural Wonders & Landscape Trail',
          route: '$destination ➔ Alpine Valley / Water Reservoir ➔ Nature Trail',
          timing: '08:30 AM – 05:30 PM • Nature & Scenic Vistas',
          attractions: [
            '$destination Scenic Lake & River Springs',
            'Pine Forest / Highland Nature Walking Trail',
            'Sunset Panorama Lookout Point',
          ],
          activities: const [
            'Morning nature hike along scenic landscape trails',
            'Lakeside / mountain tea stop overlooking vistas',
            'Golden hour landscape and mountain photography',
          ],
          foodRecommendation: 'Fresh pan-fried river trout or seasonal specialty with mint chutney',
          stayRecommendation: 'Lakeside or mountain-view lodge in $destination',
        );
      case 4:
        return ItineraryDay(
          dayNumber: 4,
          title: 'Artisan Markets & Cultural Handicraft Guilds',
          route: '$destination ➔ Traditional Bazaar ➔ Artisan Workshops',
          timing: '09:30 AM – 05:30 PM • Crafts & Culinary Sampling',
          attractions: [
            '$destination Traditional Bazaar',
            'Handicraft & Textile Artisan Quarter',
            'Local Cultural Folk Heritage Center',
          ],
          activities: const [
            'Watch master artisans craft traditional embroidery & woodwork',
            'Shop for authentic regional souvenirs and handmade textiles',
            'Street food tasting and dry fruits shopping',
          ],
          foodRecommendation: 'Traditional Dum Pukht or spiced roast with fragrant saffron rice',
          stayRecommendation: 'Central comfortable hotel in $destination',
        );
      case 5:
        return ItineraryDay(
          dayNumber: 5,
          title: 'Surrounding Valleys & Hidden Highland Excursion',
          route: '$destination ➔ Upper Valley Pass ➔ Highland Meadow & Springs',
          timing: '08:30 AM – 05:00 PM • Day Excursion & Panoramic Ridges',
          attractions: [
            'Upper $destination Highland Ridge',
            'Natural Mountain Spring Cascades',
            'Panoramic Valley Overlook Deck',
          ],
          activities: const [
            'Off-the-beaten-path excursion with sweeping scenic vistas',
            'Picnic lunch in pristine countryside',
            'Sunset reflection photography session',
          ],
          foodRecommendation: 'Hot spicy soup, grilled tikka skewers, and cardamom kahwa',
          stayRecommendation: 'Scenic mountain lodge in $destination',
        );
      case 6:
        return ItineraryDay(
          dayNumber: 6,
          title: 'Cultural Discovery, Parks & Farewell Evening',
          route: '$destination ➔ Public Botanical Gardens ➔ Sunset Ridge',
          timing: '09:00 AM – 06:00 PM • Leisure & Sunset Views',
          attractions: [
            '$destination Botanical Garden & Park',
            'Elevated Ridge Sunset Deck',
            'Cultural Food Street Quarter',
          ],
          activities: const [
            'Relaxing botanical garden walk',
            'Panoramic golden hour photos over surrounding ridges',
            'Celebratory farewell feast with local folk music',
          ],
          foodRecommendation: 'Traditional slow-cooked roast and sweet regional dessert',
          stayRecommendation: 'Top-rated tourist hotel in $destination',
        );
      default:
        return ItineraryDay(
          dayNumber: day,
          title: 'Day $day: Souvenir Packing & Scenic Return Journey',
          route: '$destination ➔ Scenic Transit Corridor ➔ Return to $departing',
          timing: '08:00 AM – 06:30 PM • Return Highway Drive & Memories',
          attractions: [
            'Highway Mountain Rest Point',
            'Riverside Tea Dhaba',
            'Scenic $destination Farewell Lookout',
          ],
          activities: const [
            'Pack regional handicraft souvenirs and dried fruits',
            'Final scenic transit photography stops along the highway',
            'Safe arrival back in departure destination',
          ],
          foodRecommendation: 'Highway Shinwari karahi and hot milk tea',
          stayRecommendation: 'Safe return journey to $departing',
        );
    }
  }

  static TripChatResult _getLocalChatFallback(String message) {
    return TripChatResult(
      message:
          "Got it! I have customized your spots and itinerary for \"<b>$message</b>\". The route and day-by-day sightseeing plan have been refreshed to match this preference.\n\n"
          "Tap <b>Review Summary & Finalize</b> below to inspect your updated day-by-day schedule.",
    );
  }
}
