import 'package:cloud_firestore/cloud_firestore.dart';

class Department {
  final String id;
  final String name;
  final String establishmentId;
  final String? description;
  final DateTime createdAt;

  Department({
    required this.id,
    required this.name,
    required this.establishmentId,
    this.description,
    required this.createdAt,
    required this.parkingSpotsCount,
  });

  final int parkingSpotsCount;

  factory Department.fromMap(Map<String, dynamic> data, String documentId) {
    return Department(
      id: documentId,
      name: data['name'] ?? '',
      establishmentId: data['establishmentId'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      parkingSpotsCount: (data['parkingSpotsCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'establishmentId': establishmentId,
      'description': description,
      'createdAt': createdAt,
      'parkingSpotsCount': parkingSpotsCount,
    };
  }

  Department copyWith({
    String? id,
    String? name,
    String? establishmentId,
    String? description,
    DateTime? createdAt,
    int? parkingSpotsCount,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      establishmentId: establishmentId ?? this.establishmentId,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      parkingSpotsCount: parkingSpotsCount ?? this.parkingSpotsCount,
    );
  }
}
