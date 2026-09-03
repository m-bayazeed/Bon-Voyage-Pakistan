library trip_plan_model;

/// Data models for AI Tour Planning in Bon Voyage Pakistan.

/// Represents a chat message in the AI Tour Planning conversation.
class ChatMessage {
  final String id;
  final String text;
  final bool isAi;
  final DateTime timestamp;
  final TripPlan? planSnippet;
  final List<String>? quickSuggestions;
  final String? checklistActionTitle;
  final int? checklistActionDayNumber;
  final bool isChecklistActionAdded;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isAi,
    DateTime? timestamp,
    this.planSnippet,
    this.quickSuggestions,
    this.checklistActionTitle,
    this.checklistActionDayNumber,
    this.isChecklistActionAdded = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isAi,
    DateTime? timestamp,
    TripPlan? planSnippet,
    List<String>? quickSuggestions,
    String? checklistActionTitle,
    int? checklistActionDayNumber,
    bool? isChecklistActionAdded,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isAi: isAi ?? this.isAi,
      timestamp: timestamp ?? this.timestamp,
      planSnippet: planSnippet ?? this.planSnippet,
      quickSuggestions: quickSuggestions ?? this.quickSuggestions,
      checklistActionTitle: checklistActionTitle ?? this.checklistActionTitle,
      checklistActionDayNumber: checklistActionDayNumber ?? this.checklistActionDayNumber,
      isChecklistActionAdded: isChecklistActionAdded ?? this.isChecklistActionAdded,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isAi': isAi,
        'timestamp': timestamp.toIso8601String(),
        'planSnippet': planSnippet?.toJson(),
        'quickSuggestions': quickSuggestions,
        'checklistActionTitle': checklistActionTitle,
        'checklistActionDayNumber': checklistActionDayNumber,
        'isChecklistActionAdded': isChecklistActionAdded,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        text: json['text'] as String,
        isAi: json['isAi'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        planSnippet: json['planSnippet'] != null
            ? TripPlan.fromJson(json['planSnippet'] as Map<String, dynamic>)
            : null,
        quickSuggestions: json['quickSuggestions'] != null
            ? List<String>.from(json['quickSuggestions'] as List)
            : null,
        checklistActionTitle: json['checklistActionTitle'] as String?,
        checklistActionDayNumber: json['checklistActionDayNumber'] as int?,
        isChecklistActionAdded: json['isChecklistActionAdded'] as bool? ?? false,
      );
}


/// Detailed day-by-day itinerary item.
class ItineraryDay {
  final int dayNumber;
  final String title;
  final String route;
  final String timing;
  final List<String> attractions;
  final List<String> activities;
  final String foodRecommendation;
  final String stayRecommendation;

  const ItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.route,
    required this.timing,
    required this.attractions,
    required this.activities,
    required this.foodRecommendation,
    required this.stayRecommendation,
  });

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'title': title,
        'route': route,
        'timing': timing,
        'attractions': attractions,
        'activities': activities,
        'foodRecommendation': foodRecommendation,
        'stayRecommendation': stayRecommendation,
      };

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
        dayNumber: json['dayNumber'] as int,
        title: json['title'] as String,
        route: json['route'] as String,
        timing: json['timing'] as String,
        attractions: List<String>.from(json['attractions'] as List),
        activities: List<String>.from(json['activities'] as List),
        foodRecommendation: json['foodRecommendation'] as String,
        stayRecommendation: json['stayRecommendation'] as String,
      );
}

/// Budget breakdown in Pakistani Rupees (PKR).
class BudgetBreakdown {
  final int transportPkr;
  final int accommodationPkr;
  final int foodPkr;
  final int activitiesPkr;
  final int contingencyPkr;

  const BudgetBreakdown({
    required this.transportPkr,
    required this.accommodationPkr,
    required this.foodPkr,
    required this.activitiesPkr,
    required this.contingencyPkr,
  });

  int get totalPkr =>
      transportPkr +
      accommodationPkr +
      foodPkr +
      activitiesPkr +
      contingencyPkr;

  Map<String, dynamic> toJson() => {
        'transportPkr': transportPkr,
        'accommodationPkr': accommodationPkr,
        'foodPkr': foodPkr,
        'activitiesPkr': activitiesPkr,
        'contingencyPkr': contingencyPkr,
      };

  factory BudgetBreakdown.fromJson(Map<String, dynamic> json) => BudgetBreakdown(
        transportPkr: json['transportPkr'] as int,
        accommodationPkr: json['accommodationPkr'] as int,
        foodPkr: json['foodPkr'] as int,
        activitiesPkr: json['activitiesPkr'] as int,
        contingencyPkr: json['contingencyPkr'] as int,
      );
}

/// Complete Trip Plan generated by AI.
class TripPlan {
  final String id;
  final int? userId;
  final String title;
  final String departingCity;
  final String destinationCity;
  final int days;
  final int travelers;
  final String budgetTier;
  final double budgetAmountPkr;
  final List<String> interests;
  final String transportation;
  final String accommodation;
  final String specialRequirements;
  final List<ItineraryDay> daysPlan;
  final BudgetBreakdown budgetBreakdown;
  final DateTime createdAt;
  final bool isFinalized;

  TripPlan({
    required this.id,
    this.userId,
    required this.title,
    required this.departingCity,
    required this.destinationCity,
    required this.days,
    required this.travelers,
    required this.budgetTier,
    required this.budgetAmountPkr,
    required this.interests,
    required this.transportation,
    required this.accommodation,
    this.specialRequirements = '',
    required this.daysPlan,
    required this.budgetBreakdown,
    DateTime? createdAt,
    this.isFinalized = false,
  }) : createdAt = createdAt ?? DateTime.now();

  TripPlan copyWith({
    String? id,
    int? userId,
    String? title,
    String? departingCity,
    String? destinationCity,
    int? days,
    int? travelers,
    String? budgetTier,
    double? budgetAmountPkr,
    List<String>? interests,
    String? transportation,
    String? accommodation,
    String? specialRequirements,
    List<ItineraryDay>? daysPlan,
    BudgetBreakdown? budgetBreakdown,
    DateTime? createdAt,
    bool? isFinalized,
  }) {
    return TripPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      departingCity: departingCity ?? this.departingCity,
      destinationCity: destinationCity ?? this.destinationCity,
      days: days ?? this.days,
      travelers: travelers ?? this.travelers,
      budgetTier: budgetTier ?? this.budgetTier,
      budgetAmountPkr: budgetAmountPkr ?? this.budgetAmountPkr,
      interests: interests ?? this.interests,
      transportation: transportation ?? this.transportation,
      accommodation: accommodation ?? this.accommodation,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      daysPlan: daysPlan ?? this.daysPlan,
      budgetBreakdown: budgetBreakdown ?? this.budgetBreakdown,
      createdAt: createdAt ?? this.createdAt,
      isFinalized: isFinalized ?? this.isFinalized,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'departingCity': departingCity,
        'destinationCity': destinationCity,
        'days': days,
        'travelers': travelers,
        'budgetTier': budgetTier,
        'budgetAmountPkr': budgetAmountPkr,
        'interests': interests,
        'transportation': transportation,
        'accommodation': accommodation,
        'specialRequirements': specialRequirements,
        'daysPlan': daysPlan.map((d) => d.toJson()).toList(),
        'budgetBreakdown': budgetBreakdown.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'isFinalized': isFinalized,
      };

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        id: json['id'] as String,
        userId: json['userId'] as int?,
        title: json['title'] as String,
        departingCity: json['departingCity'] as String,
        destinationCity: json['destinationCity'] as String,
        days: json['days'] as int,
        travelers: json['travelers'] as int,
        budgetTier: json['budgetTier'] as String,
        budgetAmountPkr: (json['budgetAmountPkr'] as num).toDouble(),
        interests: List<String>.from(json['interests'] as List),
        transportation: json['transportation'] as String,
        accommodation: json['accommodation'] as String,
        specialRequirements: json['specialRequirements'] as String? ?? '',
        daysPlan: (json['daysPlan'] as List)
            .map((d) => ItineraryDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        budgetBreakdown: BudgetBreakdown.fromJson(
            json['budgetBreakdown'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        isFinalized: json['isFinalized'] as bool? ?? false,
      );
}
