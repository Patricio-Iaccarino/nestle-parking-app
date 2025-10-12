// lib/features/garages/providers/garage_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/garage_repository.dart';
import '../domain/models/garage_location_model.dart';

final garageRepositoryProvider = Provider<GarageRepository>((ref) {
  return GarageRepository(FirebaseFirestore.instance);
});

final garageLocationsProvider = FutureProvider<List<GarageLocation>>((
  ref,
) async {
  final repo = ref.watch(garageRepositoryProvider);
  return repo.getAllGarageLocations();
});


