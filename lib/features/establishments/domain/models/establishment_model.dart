import 'package:cloud_firestore/cloud_firestore.dart';

class Establishment {
  final String id;
  final String name;
  final String address;
  final String organizationType;
  final DateTime createdAt;

  Establishment({
    required this.id,
    required this.name,
    required this.address,
    required this.organizationType,
    required this.createdAt,
  });

  factory Establishment.fromMap(Map<String, dynamic> data, String documentId) {
    return Establishment(
      id: documentId,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      organizationType: data['organizationType'] ?? 'UNIFICADO',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'organizationType': organizationType,
      'createdAt': createdAt,
    };
  }

  Establishment copyWith({
    String? id,
    String? name,
    String? address,
    String? organizationType,
    DateTime? createdAt,
  }) {
    return Establishment(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      organizationType: organizationType ?? this.organizationType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
