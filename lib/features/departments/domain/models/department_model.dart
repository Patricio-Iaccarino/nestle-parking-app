import 'package:cloud_firestore/cloud_firestore.dart';

class Department {
  final String id;
  final String name;
  final String establishmentId;
  final String? description;
  final int numberOfSpots;
  final DateTime createdAt;

  Department({
    required this.id,
    required this.name,
    required this.establishmentId,
    this.description,
    required this.numberOfSpots,
    required this.createdAt,
  });

  factory Department.fromMap(Map<String, dynamic> data, String documentId) {
    return Department(
      id: documentId,
      name: data['name'] ?? '',
      establishmentId: data['establishmentId'] ?? '',
      description: data['description'],
      numberOfSpots: data['numberOfSpots'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'establishmentId': establishmentId,
      'description': description,
      'numberOfSpots': numberOfSpots,
      'createdAt': createdAt,
    };
  }

  Department copyWith({
    String? id,
    String? name,
    String? establishmentId,
    String? description,
    int? numberOfSpots,
    DateTime? createdAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      establishmentId: establishmentId ?? this.establishmentId,
      description: description ?? this.description,
      numberOfSpots: numberOfSpots ?? this.numberOfSpots,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
