import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String phoneNumber;
  final String? alias;
  final String? name;
  final String? company;
  final String? email;
  final String employeeId;
  final DateTime lastCallAt;
  final int totalCalls;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.phoneNumber,
    this.alias,
    this.name,
    this.company,
    this.email,
    required this.employeeId,
    required this.lastCallAt,
    this.totalCalls = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? id,
    String? phoneNumber,
    String? alias,
    String? name,
    String? company,
    String? email,
    String? employeeId,
    DateTime? lastCallAt,
    int? totalCalls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      alias: alias ?? this.alias,
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      lastCallAt: lastCallAt ?? this.lastCallAt,
      totalCalls: totalCalls ?? this.totalCalls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'alias': alias,
      'name': name,
      'company': company,
      'email': email,
      'employeeId': employeeId,
      'lastCallAt': Timestamp.fromDate(lastCallAt),
      'totalCalls': totalCalls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      alias: json['alias'] as String?,
      name: json['name'] as String?,
      company: json['company'] as String?,
      email: json['email'] as String?,
      employeeId: json['employeeId'] as String,
      lastCallAt: (json['lastCallAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalCalls: json['totalCalls'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get displayName => alias ?? name ?? phoneNumber;

  @override
  String toString() {
    return 'Customer(id: $id, phoneNumber: $phoneNumber, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}