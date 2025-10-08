import 'package:cloud_firestore/cloud_firestore.dart';

enum SentimentType { positive, neutral, negative }

class AISummary {
  final String id;
  final String callId;
  final String employeeId;
  final String customerId;
  final String summary;
  final List<String> keyHighlights;
  final SentimentType sentiment;
  final double sentimentScore; // -1 to 1
  final List<String> nextSteps;
  final List<String> concerns;
  final Map<String, dynamic>? metadata;
  final String aiProvider; // 'gemini', 'openai', etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  const AISummary({
    required this.id,
    required this.callId,
    required this.employeeId,
    required this.customerId,
    required this.summary,
    required this.keyHighlights,
    required this.sentiment,
    required this.sentimentScore,
    required this.nextSteps,
    required this.concerns,
    this.metadata,
    this.aiProvider = 'gemini',
    required this.createdAt,
    required this.updatedAt,
  });

  AISummary copyWith({
    String? id,
    String? callId,
    String? employeeId,
    String? customerId,
    String? summary,
    List<String>? keyHighlights,
    SentimentType? sentiment,
    double? sentimentScore,
    List<String>? nextSteps,
    List<String>? concerns,
    Map<String, dynamic>? metadata,
    String? aiProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AISummary(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      summary: summary ?? this.summary,
      keyHighlights: keyHighlights ?? this.keyHighlights,
      sentiment: sentiment ?? this.sentiment,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      nextSteps: nextSteps ?? this.nextSteps,
      concerns: concerns ?? this.concerns,
      metadata: metadata ?? this.metadata,
      aiProvider: aiProvider ?? this.aiProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callId': callId,
      'employeeId': employeeId,
      'customerId': customerId,
      'summary': summary,
      'keyHighlights': keyHighlights,
      'sentiment': sentiment.name,
      'sentimentScore': sentimentScore,
      'nextSteps': nextSteps,
      'concerns': concerns,
      'metadata': metadata,
      'aiProvider': aiProvider,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory AISummary.fromJson(Map<String, dynamic> json) {
    return AISummary(
      id: json['id'] as String,
      callId: json['callId'] as String,
      employeeId: json['employeeId'] as String,
      customerId: json['customerId'] as String,
      summary: json['summary'] as String,
      keyHighlights: List<String>.from(json['keyHighlights'] as List<dynamic>),
      sentiment: SentimentType.values.firstWhere((e) => e.name == json['sentiment']),
      sentimentScore: (json['sentimentScore'] as num).toDouble(),
      nextSteps: List<String>.from(json['nextSteps'] as List<dynamic>),
      concerns: List<String>.from(json['concerns'] as List<dynamic>),
      metadata: json['metadata'] as Map<String, dynamic>?,
      aiProvider: json['aiProvider'] as String? ?? 'gemini',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get sentimentLabel {
    switch (sentiment) {
      case SentimentType.positive:
        return 'Positive';
      case SentimentType.neutral:
        return 'Neutral';
      case SentimentType.negative:
        return 'Negative';
    }
  }

  String get sentimentEmoji {
    switch (sentiment) {
      case SentimentType.positive:
        return '😊';
      case SentimentType.neutral:
        return '😐';
      case SentimentType.negative:
        return '😞';
    }
  }

  @override
  String toString() {
    return 'AISummary(id: $id, callId: $callId, sentiment: $sentiment)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AISummary && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}