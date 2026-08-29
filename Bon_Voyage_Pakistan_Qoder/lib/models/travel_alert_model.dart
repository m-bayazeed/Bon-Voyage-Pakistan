import 'package:flutter/material.dart';

/// Categories of travel notifications and advisories.
enum AlertCategory {
  all,
  weather,
  roadCondition,
  naturalDisaster,
  publicSafety,
  advisory,
}

extension AlertCategoryExtension on AlertCategory {
  String get displayName {
    switch (this) {
      case AlertCategory.all:
        return 'All Alerts';
      case AlertCategory.weather:
        return 'Weather & Met';
      case AlertCategory.roadCondition:
        return 'Roads & Passes';
      case AlertCategory.naturalDisaster:
        return 'Disaster Warnings';
      case AlertCategory.publicSafety:
        return 'Public Safety';
      case AlertCategory.advisory:
        return 'Travel Advisories';
    }
  }

  IconData get icon {
    switch (this) {
      case AlertCategory.all:
        return Icons.notifications_active_rounded;
      case AlertCategory.weather:
        return Icons.cloudy_snowing;
      case AlertCategory.roadCondition:
        return Icons.traffic_rounded;
      case AlertCategory.naturalDisaster:
        return Icons.warning_amber_rounded;
      case AlertCategory.publicSafety:
        return Icons.security_rounded;
      case AlertCategory.advisory:
        return Icons.info_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AlertCategory.all:
        return const Color(0xFF5A7328);
      case AlertCategory.weather:
        return const Color(0xFF0288D1);
      case AlertCategory.roadCondition:
        return const Color(0xFFE65100);
      case AlertCategory.naturalDisaster:
        return const Color(0xFFD32F2F);
      case AlertCategory.publicSafety:
        return const Color(0xFF7B1FA2);
      case AlertCategory.advisory:
        return const Color(0xFF388E3C);
    }
  }
}

/// Severity classification for travel alerts.
enum AlertSeverity {
  critical,
  high,
  moderate,
  informational,
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical Hazard';
      case AlertSeverity.high:
        return 'High Warning';
      case AlertSeverity.moderate:
        return 'Moderate Caution';
      case AlertSeverity.informational:
        return 'Information';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverity.critical:
        return const Color(0xFFD32F2F);
      case AlertSeverity.high:
        return const Color(0xFFF57C00);
      case AlertSeverity.moderate:
        return const Color(0xFFFBC02D);
      case AlertSeverity.informational:
        return const Color(0xFF1976D2);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverity.critical:
        return Icons.dangerous_rounded;
      case AlertSeverity.high:
        return Icons.warning_rounded;
      case AlertSeverity.moderate:
        return Icons.report_problem_rounded;
      case AlertSeverity.informational:
        return Icons.info_rounded;
    }
  }
}

/// Comprehensive Travel Alert model representing real-time conditions.
class TravelAlert {
  final String id;
  final AlertCategory type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String location;
  final String city;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String source;
  final String? recommendedAction;
  final bool isRead;
  final Map<String, dynamic>? details;

  const TravelAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.location,
    required this.city,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.expiresAt,
    required this.source,
    this.recommendedAction,
    this.isRead = false,
    this.details,
  });

  /// Check if the alert has geographic GPS coordinates for map display.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Time-ago representation (e.g. "25 mins ago", "2 hrs ago").
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 60)} mins ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hrs ago';
    } else {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    }
  }

  TravelAlert copyWith({
    String? id,
    AlertCategory? type,
    AlertSeverity? severity,
    String? title,
    String? description,
    String? location,
    String? city,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? source,
    String? recommendedAction,
    bool? isRead,
    Map<String, dynamic>? details,
  }) {
    return TravelAlert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      city: city ?? this.city,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      source: source ?? this.source,
      recommendedAction: recommendedAction ?? this.recommendedAction,
      isRead: isRead ?? this.isRead,
      details: details ?? this.details,
    );
  }

  factory TravelAlert.fromJson(Map<String, dynamic> json) {
    return TravelAlert(
      id: json['id'] as String? ?? 'ALERT-${DateTime.now().millisecondsSinceEpoch}',
      type: _parseCategory(json['type'] as String?),
      severity: _parseSeverity(json['severity'] as String?),
      title: json['title'] as String? ?? 'Travel Notice',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? 'Pakistan',
      city: json['city'] as String? ?? 'National',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      source: json['source'] as String? ?? 'National Travel Authority',
      recommendedAction: json['recommendedAction'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'location': location,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'source': source,
      'recommendedAction': recommendedAction,
      'isRead': isRead,
      'details': details,
    };
  }

  static AlertCategory _parseCategory(String? raw) {
    if (raw == null) return AlertCategory.advisory;
    return AlertCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => AlertCategory.advisory,
    );
  }

  static AlertSeverity _parseSeverity(String? raw) {
    if (raw == null) return AlertSeverity.moderate;
    return AlertSeverity.values.firstWhere(
      (s) => s.name.toLowerCase() == raw.toLowerCase(),
      orElse: () => AlertSeverity.moderate,
    );
  }
}
