import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageSender { user, ai }
enum MessageType { text, summary, followUp }

class ChatMessage {
  final String id;
  final String customerId;
  final String employeeId;
  final String content;
  final MessageSender sender;
  final MessageType type;
  final Map<String, dynamic>? metadata;
  final String? relatedCallId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatMessage({
    required this.id,
    required this.customerId,
    required this.employeeId,
    required this.content,
    required this.sender,
    this.type = MessageType.text,
    this.metadata,
    this.relatedCallId,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatMessage copyWith({
    String? id,
    String? customerId,
    String? employeeId,
    String? content,
    MessageSender? sender,
    MessageType? type,
    Map<String, dynamic>? metadata,
    String? relatedCallId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      employeeId: employeeId ?? this.employeeId,
      content: content ?? this.content,
      sender: sender ?? this.sender,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      relatedCallId: relatedCallId ?? this.relatedCallId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'employeeId': employeeId,
      'content': content,
      'sender': sender.name,
      'type': type.name,
      'metadata': metadata,
      'relatedCallId': relatedCallId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      employeeId: json['employeeId'] as String,
      content: json['content'] as String,
      sender: MessageSender.values.firstWhere((e) => e.name == json['sender']),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
      relatedCallId: json['relatedCallId'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isFromUser => sender == MessageSender.user;
  bool get isFromAI => sender == MessageSender.ai;

  @override
  String toString() {
    return 'ChatMessage(id: $id, sender: $sender, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}