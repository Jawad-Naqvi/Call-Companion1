import 'package:cloud_firestore/cloud_firestore.dart';

class UserPreferences {
  final String userId;
  final bool isRecordingEnabled;
  final DateTime updatedAt;

  UserPreferences({
    required this.userId,
    required this.isRecordingEnabled,
    required this.updatedAt,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] as String,
      isRecordingEnabled: json['isRecordingEnabled'] as bool,
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'isRecordingEnabled': isRecordingEnabled,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserPreferences copyWith({
    String? userId,
    bool? isRecordingEnabled,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      isRecordingEnabled: isRecordingEnabled ?? this.isRecordingEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}