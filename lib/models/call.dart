import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { incoming, outgoing }
enum CallStatus { recording, completed, transcribing, analyzed, failed }

class Call {
  final String id;
  final String employeeId;
  final String customerId;
  final String customerPhoneNumber;
  final CallType type;
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int? duration; // in seconds
  final String? audioFileUrl;
  final String? audioFileName;
  final int? audioFileSize;
  final bool hasTranscript;
  final bool hasAISummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Call({
    required this.id,
    required this.employeeId,
    required this.customerId,
    required this.customerPhoneNumber,
    required this.type,
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
    this.audioFileUrl,
    this.audioFileName,
    this.audioFileSize,
    this.hasTranscript = false,
    this.hasAISummary = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Call copyWith({
    String? id,
    String? employeeId,
    String? customerId,
    String? customerPhoneNumber,
    CallType? type,
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
    String? audioFileUrl,
    String? audioFileName,
    int? audioFileSize,
    bool? hasTranscript,
    bool? hasAISummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Call(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      customerId: customerId ?? this.customerId,
      customerPhoneNumber: customerPhoneNumber ?? this.customerPhoneNumber,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      audioFileUrl: audioFileUrl ?? this.audioFileUrl,
      audioFileName: audioFileName ?? this.audioFileName,
      audioFileSize: audioFileSize ?? this.audioFileSize,
      hasTranscript: hasTranscript ?? this.hasTranscript,
      hasAISummary: hasAISummary ?? this.hasAISummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'customerId': customerId,
      'customerPhoneNumber': customerPhoneNumber,
      'type': type.name,
      'status': status.name,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration,
      'audioFileUrl': audioFileUrl,
      'audioFileName': audioFileName,
      'audioFileSize': audioFileSize,
      'hasTranscript': hasTranscript,
      'hasAISummary': hasAISummary,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      customerId: json['customerId'] as String,
      customerPhoneNumber: json['customerPhoneNumber'] as String,
      type: CallType.values.firstWhere((e) => e.name == json['type']),
      status: CallStatus.values.firstWhere((e) => e.name == json['status']),
      startTime: (json['startTime'] as Timestamp).toDate(),
      endTime: (json['endTime'] as Timestamp?)?.toDate(),
      duration: json['duration'] as int?,
      audioFileUrl: json['audioFileUrl'] as String?,
      audioFileName: json['audioFileName'] as String?,
      audioFileSize: json['audioFileSize'] as int?,
      hasTranscript: json['hasTranscript'] as bool? ?? false,
      hasAISummary: json['hasAISummary'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isCompleted => status == CallStatus.completed || status == CallStatus.analyzed;

  @override
  String toString() {
    return 'Call(id: $id, customerPhoneNumber: $customerPhoneNumber, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Call && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}