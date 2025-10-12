import 'package:cloud_firestore/cloud_firestore.dart';

class GarageLocation {
  final String id;
  final String name;
  final String address;
  final int capacity;
  final double lat;
  final double lng;
  final String? adminId; // un solo admin asignado
  final List<String> adminIds; // varios admins posibles
  final DateTime createdAt;
  final DateTime updatedAt;
  final int currentReservations;
  final List<String> assignedUsers;
  final List<String> assignedSectors;

  GarageLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.capacity,
    required this.lat,
    required this.lng,
    required this.createdAt,
    required this.updatedAt,
    this.adminId,
    this.adminIds = const [],
    this.currentReservations = 0,
    this.assignedUsers = const [],
    this.assignedSectors = const [],
  });

  factory GarageLocation.fromMap(Map<String, dynamic> data, String id) {
    final location = data['location'] as Map<String, dynamic>? ?? {};

    return GarageLocation(
      id: id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      adminId: data['adminId'],
      adminIds: List<String>.from(data['adminIds'] ?? []),
      capacity: data['capacity'] ?? 0,
      lat: (location['lat'] ?? 0).toDouble(),
      lng: (location['lng'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentReservations: data['currentReservations'] ?? 0,
      assignedUsers: List<String>.from(data['assignedUsers'] ?? []),
      assignedSectors: List<String>.from(data['assignedSectors'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'capacity': capacity,
      'adminId': adminId,
      'adminIds': adminIds,
      'location': {'lat': lat, 'lng': lng},
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'currentReservations': currentReservations,
      'assignedUsers': assignedUsers,
      'assignedSectors': assignedSectors,
    };
  }
}
