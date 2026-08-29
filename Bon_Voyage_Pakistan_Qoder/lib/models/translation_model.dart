library;

/// Represents a language option available for translation.
class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isPakistaniRegional;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.isPakistaniRegional = false,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'nativeName': nativeName,
        'flag': flag,
        'isPakistaniRegional': isPakistaniRegional,
      };

  factory LanguageOption.fromJson(Map<String, dynamic> json) => LanguageOption(
        code: json['code'] as String,
        name: json['name'] as String,
        nativeName: json['nativeName'] as String,
        flag: json['flag'] as String,
        isPakistaniRegional: json['isPakistaniRegional'] as bool? ?? false,
      );
}

/// Communication modes supported by the translator.
enum TranslationMode {
  textToText,
  speechToText,
  textToSpeech,
  speechToSpeech,
}

/// Represents a saved or recent translation item.
class TranslationItem {
  final String id;
  final String sourceText;
  final String translatedText;
  final String romanizedPronunciation;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final DateTime timestamp;
  final bool isFavorite;

  const TranslationItem({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    this.romanizedPronunciation = '',
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.timestamp,
    this.isFavorite = false,
  });

  TranslationItem copyWith({
    String? id,
    String? sourceText,
    String? translatedText,
    String? romanizedPronunciation,
    String? sourceLanguageCode,
    String? targetLanguageCode,
    DateTime? timestamp,
    bool? isFavorite,
  }) {
    return TranslationItem(
      id: id ?? this.id,
      sourceText: sourceText ?? this.sourceText,
      translatedText: translatedText ?? this.translatedText,
      romanizedPronunciation:
          romanizedPronunciation ?? this.romanizedPronunciation,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceText': sourceText,
        'translatedText': translatedText,
        'romanizedPronunciation': romanizedPronunciation,
        'sourceLanguageCode': sourceLanguageCode,
        'targetLanguageCode': targetLanguageCode,
        'timestamp': timestamp.toIso8601String(),
        'isFavorite': isFavorite,
      };

  factory TranslationItem.fromJson(Map<String, dynamic> json) =>
      TranslationItem(
        id: json['id'] as String,
        sourceText: json['sourceText'] as String,
        translatedText: json['translatedText'] as String,
        romanizedPronunciation:
            json['romanizedPronunciation'] as String? ?? '',
        sourceLanguageCode: json['sourceLanguageCode'] as String,
        targetLanguageCode: json['targetLanguageCode'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
}

/// A dialog turn in two-way Live Conversation mode.
class ConversationTurn {
  final String id;
  final String speakerName; // e.g. "Tourist" or "Local Host"
  final bool isTourist;
  final String originalText;
  final String translatedText;
  final String pronunciation;
  final String languageCode;
  final DateTime timestamp;

  const ConversationTurn({
    required this.id,
    required this.speakerName,
    required this.isTourist,
    required this.originalText,
    required this.translatedText,
    this.pronunciation = '',
    required this.languageCode,
    required this.timestamp,
  });
}

/// A tourist phrasebook quick category.
class TouristPhrase {
  final String english;
  final String urdu;
  final String romanUrdu;
  final String category;

  const TouristPhrase({
    required this.english,
    required this.urdu,
    required this.romanUrdu,
    required this.category,
  });
}
