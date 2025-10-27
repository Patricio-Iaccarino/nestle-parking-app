class ParkingSpot {
  final String id;
  final String spotNumber;
  final int floor;
  final String type;
  final String establishmentId;
  final String departmentId;
  final String? assignedUserId;
  final String? assignedUserName;
  ParkingSpot({
    required this.id,
    required this.spotNumber,
    required this.floor,
    required this.type,
    required this.establishmentId,
    required this.departmentId,
    this.assignedUserId,
    this.assignedUserName,
  });

  factory ParkingSpot.fromMap(Map<String, dynamic> data, String documentId) {
    return ParkingSpot(
      id: documentId,
      spotNumber: data['spotNumber'] ?? '',
      floor: data['floor'] ?? 0,
      type: data['type'] ?? 'SIMPLE',
      establishmentId: data['establishmentId'] ?? '',
      departmentId: data['departmentId'] ?? '',
      assignedUserId: data['assignedUserId'],
      assignedUserName: data['assignedUserName'], // permite null
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotNumber': spotNumber,
      'floor': floor,
      'type': type,
      'establishmentId': establishmentId,
      'departmentId': departmentId,
      'assignedUserId': assignedUserId,
      'assignedUserName': assignedUserName,
    };
  }

  ParkingSpot copyWith({
    String? id,
    String? spotNumber, 
    int? floor,
    String? type,
    String? establishmentId,
    String? departmentId,
    String? assignedUserId,
    String? assignedUserName,
    bool clearAssignedUser = false,
  }) {
    return ParkingSpot(
      id: id ?? this.id,
      spotNumber: spotNumber ?? this.spotNumber,
      floor: floor ?? this.floor,
      type: type ?? this.type,
      establishmentId: establishmentId ?? this.establishmentId,
      departmentId: departmentId ?? this.departmentId,
      assignedUserId: clearAssignedUser
          ? null
          : (assignedUserId ?? this.assignedUserId),
      assignedUserName: assignedUserName ?? this.assignedUserName,
    );
  }
}
