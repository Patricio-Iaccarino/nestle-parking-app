import 'package:cloud_firestore/cloud_firestore.dart';

class Establishment {
  final String id;
  final String name;
  final String address;
  final String organizationType;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  Establishment({
    required this.id,
    required this.name,
    required this.address,
    required this.organizationType,
    required this.createdAt,
    this.latitude,
    this.longitude,
    required this.totalParkingSpots,
  });

  final int totalParkingSpots;

  // --- 👇 CAMBIO 1: Añadir un constructor 'empty' ---
  factory Establishment.empty() {
    return Establishment(
      id: '',
      name: 'No asignado', // Un valor por defecto es útil
      address: '',
      organizationType: 'UNIFICADO',
      createdAt: DateTime.now(),
      latitude: null,
      longitude: null,
      totalParkingSpots: 0,
    );
  }

  // --- 👇 CAMBIO 2: Actualizar 'fromMap' ---
  factory Establishment.fromMap(Map<String, dynamic> data, String documentId) {
    return Establishment(
      id: documentId,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      organizationType: data['organizationType'] ?? 'UNIFICADO',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      // Añadir los campos de coordenadas (como double nulables)
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      totalParkingSpots: (data['totalParkingSpots'] as num?)?.toInt() ?? 0,
    );
  }

  // --- 👇 CAMBIO 3: Actualizar 'toMap' ---
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'organizationType': organizationType,
      'createdAt': Timestamp.fromDate(createdAt), // Mejor guardar como Timestamp
      // Añadir los campos de coordenadas
      'latitude': latitude,
      'longitude': longitude,
      'totalParkingSpots': totalParkingSpots,
    };
  }

  // --- 👇 CAMBIO 4: Actualizar 'copyWith' ---
  Establishment copyWith({
    String? id,
    String? name,
    String? address,
    String? organizationType,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    int? totalParkingSpots,
  }) {
    return Establishment(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      organizationType: organizationType ?? this.organizationType,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalParkingSpots: totalParkingSpots ?? this.totalParkingSpots,
    );
  }
}