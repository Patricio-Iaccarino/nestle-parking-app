class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String role;
  final String establishmentId;
  final String establishmentName;
  final String departmentId;
  final List<String> vehiclePlates;

  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.establishmentId,
    required this.departmentId,
    required this.establishmentName,
    required this.vehiclePlates,
  });

  factory AppUser.empty() {
    return AppUser(
      id: '',
      displayName: 'Usuario Desconocido',
      email: '',
      role: '',
      establishmentId: '',
      departmentId: '',
      establishmentName: '',
      vehiclePlates: [],
    );
  }

  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    // --- Normalizamos el campo role (puede ser String o List) ---
    String normalizeRole(dynamic rawRole) {
      if (rawRole is String) return rawRole.trim();
      if (rawRole is List && rawRole.isNotEmpty) {
        final first = rawRole.first;
        if (first is String) return first.trim();
      }
      return 'TITULAR';
    }

    // --- Normalizamos el campo establishmentId (puede ser String o List) ---
    String normalizeEstablishment(dynamic rawEst) {
      if (rawEst is String) return rawEst.trim();
      if (rawEst is List) {
        return rawEst.map((e) => e.toString()).join(','); // concatenamos IDs
      }
      return '';
    }

    return AppUser(
      id: documentId,
      email: (data['email'] ?? '').toString().trim(),
      displayName: (data['displayName'] ?? '').toString().trim(),
      role: normalizeRole(data['role']),
      establishmentId: normalizeEstablishment(data['establishmentId']),
      departmentId: (data['departmentId'] ?? '').toString(),
      establishmentName: data['establishmentName'] ?? 'Establecimiento Desconocido',
      vehiclePlates: List<String>.from(data['vehiclePlates'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      'establishmentId': establishmentId,
      'establishmentName': establishmentName,
      'departmentId': departmentId,
      'vehiclePlates': vehiclePlates,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? role,
    String? establishmentId,
    String? establishmentName,
    String? departmentId,
    List<String>? vehiclePlates,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      establishmentId: establishmentId ?? this.establishmentId,
      establishmentName: establishmentName ?? this.establishmentName,
      departmentId: departmentId ?? this.departmentId,
      vehiclePlates: vehiclePlates ?? this.vehiclePlates,
    );
  }
}
