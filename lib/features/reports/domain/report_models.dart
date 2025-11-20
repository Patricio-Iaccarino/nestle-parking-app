import 'package:cloud_firestore/cloud_firestore.dart';


///Tipos de reporte (aunque ahora usamos solo uno)

enum ReportKind {
  detailedDaily, 
  occupancyDaily,
  byDepartment,
  substitutes,
  titularReleases,
}


/// Filtro del reporte

class ReportsFilter {
  final DateRange range;
  final String? establishmentId;
  final String? departmentId;
  final String? userId;

  ReportsFilter({
    required this.range,
    this.establishmentId,
    this.departmentId,
    this.userId,
  });

  ReportsFilter copyWith({
    DateRange? range,
    String? establishmentId,
    String? departmentId,
    String? userId,
  }) {
    return ReportsFilter(
      range: range ?? this.range,
      establishmentId: establishmentId ?? this.establishmentId,
      departmentId: departmentId ?? this.departmentId,
      userId: userId ?? this.userId,
    );
  }
}


/// Rango de fechas simple

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}


/// MODELO ANTIGUO 

class DailyOccupancyPoint {
  final DateTime day;
  final int occupied;
  final int availableForSubstitutes;
  final int reservedBySubstitutes;

  DailyOccupancyPoint({
    required this.day,
    required this.occupied,
    required this.availableForSubstitutes,
    required this.reservedBySubstitutes,
  });
}



/// Cada fila representa una reserva o liberación de cochera


class DetailedReportRecord {
  final DateTime releaseDate;
  final String status; 
  final String? userId;
  final String? userName;
  final String? departmentId;
  final String? departmentName;
  final String? spotId;
  final String? spotName;
  final String? spotType;

  DetailedReportRecord({
    required this.releaseDate,
    required this.status,
    this.userId,
    this.userName,
    this.departmentId,
    this.departmentName,
    this.spotId,
    this.spotName,
    this.spotType,
  });

  /// Factory para construir desde Firestore 
  factory DetailedReportRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final ts = data['releaseDate'];
    return DetailedReportRecord(
      releaseDate: ts is Timestamp ? ts.toDate() : DateTime.now(),
      status: (data['status'] ?? '').toString(),
      userId: data['bookedByUserId']?.toString(),
      userName: data['userName']?.toString(),
      departmentId: data['departmentId']?.toString(),
      departmentName: data['departmentName']?.toString(),
      spotId: data['spotId']?.toString(),
      spotName: data['spotName']?.toString(),
      spotType: data['spotType']?.toString(), 
    );
  }

  Map<String, dynamic> toMap() => {
        'releaseDate': releaseDate,
        'status': status,
        'userId': userId,
        'userName': userName,
        'departmentId': departmentId,
        'departmentName': departmentName,
        'spotId': spotId,
        'spotName': spotName,
        'spotType': spotType,
      };
}



/// Utilidad: normalizar fecha a inicio del día

DateTime dayFloor(DateTime d) => DateTime(d.year, d.month, d.day);
