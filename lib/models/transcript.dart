import 'package:cloud_firestore/cloud_firestore.dart';

class TranscriptSegment {
  final String text;
  final double startTime;
  final double endTime;
  final String? speaker; // 'employee' or 'customer' or null

  const TranscriptSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.speaker,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'startTime': startTime,
      'endTime': endTime,
      'speaker': speaker,
    };
  }

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      text: json['text'] as String,
      startTime: (json['startTime'] as num).toDouble(),
      endTime: (json['endTime'] as num).toDouble(),
      speaker: json['speaker'] as String?,
    );
  }
}

class Transcript {
  final String id;
  final String callId;
  final String employeeId;
  final String customerId;
  final String fullText;
  final List<TranscriptSegment> segments;
  final String? language;
  final double? confidence;
  final String? transcriptionProvider; // 'whisper', 'deepgram', etc.
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transcript({
    required this.id,
    required this.callId,
    required this.employeeId,
    required this.customerId,
    required this.fullText,
    required this.segments,
    this.language,
    this.confidence,
    this.transcriptionProvider,
    required this.createdAt,
    required this.updatedAt,
  });

  Transcript copyWith({
    String? id,
    String? callId,
    String? employeeId,
    String? customerId,
    String? fullText,
    List<TranscriptSegment>? segments,
    String? language,
    double? confidence,
    String? transcriptionProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transcript(
      id: id ?? this.id,
      callId: callId ?? this.callId,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      fullText: fullText ?? this.fullText,
      segments: segments ?? this.segments,
      language: language ?? this.language,
      confidence: confidence ?? this.confidence,
      transcriptionProvider: transcriptionProvider ?? this.transcriptionProvider,
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
      'fullText': fullText,
      'segments': segments.map((s) => s.toJson()).toList(),
      'language': language,
      'confidence': confidence,
      'transcriptionProvider': transcriptionProvider,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Transcript.fromJson(Map<String, dynamic> json) {
    return Transcript(
      id: json['id'] as String,
      callId: json['callId'] as String,
      employeeId: json['employeeId'] as String,
      customerId: json['customerId'] as String,
      fullText: json['fullText'] as String,
      segments: (json['segments'] as List<dynamic>?)
          ?.map((s) => TranscriptSegment.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      language: json['language'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      transcriptionProvider: json['transcriptionProvider'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get formattedText {
    if (segments.isEmpty) return fullText;
    return segments.map((s) => s.text).join(' ');
  }

  @override
  String toString() {
    return 'Transcript(id: $id, callId: $callId, language: $language)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transcript && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}