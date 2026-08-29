import 'dart:convert';

enum ScanType { camera, upload }

/// Data model representing a landmark/location identified by AI Scan n Search.
class ScanItem {
  final String id;
  final int? userId;
  final String title;
  final String? identifiedLocation;
  final String location;
  final String category;
  final double confidenceScore;
  final String shortDescription;
  final String historicalStory;
  final List<String> keyFacts;
  final List<String> recommendedActivities;
  final String bestTimeToVisit;
  final DateTime timestamp;
  final ScanType scanType;
  final String? imagePath;
  final String searchStatus;
  final String imagePlaceholderAsset;
  final bool isFavorite;

  const ScanItem({
    required this.id,
    this.userId,
    required this.title,
    this.identifiedLocation,
    required this.location,
    required this.category,
    required this.confidenceScore,
    required this.shortDescription,
    required this.historicalStory,
    required this.keyFacts,
    required this.recommendedActivities,
    required this.bestTimeToVisit,
    required this.timestamp,
    required this.scanType,
    this.imagePath,
    this.searchStatus = 'Identified',
    this.imagePlaceholderAsset = 'assets/images/onboarding1.png',
    this.isFavorite = false,
  });

  DateTime get createdAt => timestamp;
  String get source => scanType == ScanType.camera ? 'camera' : 'gallery';

  ScanItem copyWith({
    String? id,
    int? userId,
    String? title,
    String? identifiedLocation,
    String? location,
    String? category,
    double? confidenceScore,
    String? shortDescription,
    String? historicalStory,
    List<String>? keyFacts,
    List<String>? recommendedActivities,
    String? bestTimeToVisit,
    DateTime? timestamp,
    ScanType? scanType,
    String? imagePath,
    String? searchStatus,
    String? imagePlaceholderAsset,
    bool? isFavorite,
  }) {
    return ScanItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      identifiedLocation: identifiedLocation ?? this.identifiedLocation,
      location: location ?? this.location,
      category: category ?? this.category,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      shortDescription: shortDescription ?? this.shortDescription,
      historicalStory: historicalStory ?? this.historicalStory,
      keyFacts: keyFacts ?? this.keyFacts,
      recommendedActivities:
          recommendedActivities ?? this.recommendedActivities,
      bestTimeToVisit: bestTimeToVisit ?? this.bestTimeToVisit,
      timestamp: timestamp ?? this.timestamp,
      scanType: scanType ?? this.scanType,
      imagePath: imagePath ?? this.imagePath,
      searchStatus: searchStatus ?? this.searchStatus,
      imagePlaceholderAsset:
          imagePlaceholderAsset ?? this.imagePlaceholderAsset,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'identifiedLocation': identifiedLocation ?? title,
      'location': location,
      'category': category,
      'confidenceScore': confidenceScore,
      'shortDescription': shortDescription,
      'historicalStory': historicalStory,
      'keyFacts': jsonEncode(keyFacts),
      'recommendedActivities': jsonEncode(recommendedActivities),
      'bestTimeToVisit': bestTimeToVisit,
      'timestamp': timestamp.toIso8601String(),
      'scanType': scanType.name,
      'imagePath': imagePath,
      'searchStatus': searchStatus,
      'imagePlaceholderAsset': imagePlaceholderAsset,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory ScanItem.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return List<String>.from(val);
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return List<String>.from(decoded);
        } catch (_) {}
      }
      return [];
    }

    return ScanItem(
      id: map['id'] as String? ?? 'SCAN-${DateTime.now().millisecondsSinceEpoch}',
      userId: map['userId'] as int?,
      title: map['title'] as String? ?? 'Pakistani Landmark',
      identifiedLocation: map['identifiedLocation'] as String? ?? map['title'] as String?,
      location: map['location'] as String? ?? 'Pakistan',
      category: map['category'] as String? ?? 'Heritage Site',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.95,
      shortDescription: map['shortDescription'] as String? ?? '',
      historicalStory: map['historicalStory'] as String? ?? '',
      keyFacts: parseList(map['keyFacts']),
      recommendedActivities: parseList(map['recommendedActivities']),
      bestTimeToVisit: map['bestTimeToVisit'] as String? ?? 'All year round',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      scanType: (map['scanType'] == 'upload' || map['scanType'] == 'gallery')
          ? ScanType.upload
          : ScanType.camera,
      imagePath: map['imagePath'] as String?,
      searchStatus: map['searchStatus'] as String? ?? 'Identified',
      imagePlaceholderAsset:
          map['imagePlaceholderAsset'] as String? ?? 'assets/images/onboarding1.png',
      isFavorite: map['isFavorite'] == 1 || map['isFavorite'] == true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ScanItem.fromJson(String source) =>
      ScanItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
