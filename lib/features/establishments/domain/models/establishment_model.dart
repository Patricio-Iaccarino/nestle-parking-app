import 'package:cloud_firestore/cloud_firestore.dart';

class Establishment {
  final String id;
  final String name;
  final String address;
  final String organizationType;
  final int totalParkingSpots;
  final DateTime createdAt;

  Establishment({
    required this.id,
    required this.name,
    required this.address,
    required this.organizationType,
    required this.totalParkingSpots,
    required this.createdAt,
  });

  factory Establishment.fromMap(Map<String, dynamic> data, String documentId) {
    return Establishment(
      id: documentId,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      organizationType: data['organizationType'] ?? 'UNIFICADO',
      totalParkingSpots: data['totalParkingSpots'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'organizationType': organizationType,
      'totalParkingSpots': totalParkingSpots,
      'createdAt': createdAt,
    };
  }

  Establishment copyWith({
    String? id,
    String? name,
    String? address,
    String? organizationType,
    int? totalParkingSpots,
    DateTime? createdAt,
  }) {
    return Establishment(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      organizationType: organizationType ?? this.organizationType,
      totalParkingSpots: totalParkingSpots ?? this.totalParkingSpots,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
