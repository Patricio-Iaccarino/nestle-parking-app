import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String ownerId;
  final String brand;
  final String model;
  final String plate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.brand,
    required this.model,
    required this.plate,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromMap(Map<String, dynamic> data, String documentId) {
    return Vehicle(
      id: documentId,
      ownerId: (data['ownerId'] ?? '').toString(),
      brand: (data['brand'] ?? '').toString(),
      model: (data['model'] ?? '').toString(),
      plate: (data['plate'] ?? '').toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
