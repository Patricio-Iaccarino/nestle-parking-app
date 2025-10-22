// spot_release_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SpotRelease {
  final String id;
  final String parkingSpotId;
  final String spotNumber;
  final String establishmentId;
  final String departmentId;
  final DateTime releaseDate;
  final String status; // 'AVAILABLE' o 'BOOKED'
  final String releasedByUserId; // ID del Titular
  final String? bookedByUserId; // ID del Suplente

  SpotRelease({
    required this.id,
    required this.parkingSpotId,
    required this.spotNumber,
    required this.establishmentId,
    required this.departmentId,
    required this.releaseDate,
    required this.status,
    required this.releasedByUserId,
    this.bookedByUserId,
  });

  // ✨ ¡AQUÍ ESTÁ EL MÉTODO QUE FALTA! ✨
  // Sigue el mismo patrón que tus otros modelos (Establishment.fromMap, etc.)
  factory SpotRelease.fromMap(Map<String, dynamic> data, String id) {
    return SpotRelease(
      id: id,
      parkingSpotId: data['parkingSpotId'] ?? '',
      spotNumber: data['spotNumber'] ?? '',
      establishmentId: data['establishmentId'] ?? '',
      departmentId: data['departmentId'] ?? '',
      releaseDate: (data['releaseDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'AVAILABLE',
      releasedByUserId: data['releasedByUserId'] ?? '',
      bookedByUserId: data['bookedByUserId'], // Ya es nullable
    );
  }

  // (Opcional pero recomendado) Añade un toMap por si lo necesitas
  Map<String, dynamic> toMap() {
    return {
      'parkingSpotId': parkingSpotId,
      'spotNumber': spotNumber,
      'establishmentId': establishmentId,
      'departmentId': departmentId,
      'releaseDate': Timestamp.fromDate(releaseDate),
      'status': status,
      'releasedByUserId': releasedByUserId,
      'bookedByUserId': bookedByUserId,
    };
  }
}