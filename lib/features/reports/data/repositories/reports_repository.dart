import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/report_models.dart';

class ReportsRepository {
  final FirebaseFirestore _db;
  ReportsRepository(this._db);

  final releasesCol = "spotReleases";
  final spotsCol = "parkingSpots";
  final usersCol = "users";
  final departmentsCol = "departments";

  final Map<String, Map<String, dynamic>?> _spotCache = {};
  final Map<String, Map<String, dynamic>?> _userCache = {};
  final Map<String, Map<String, dynamic>?> _deptCache = {};

  Future<List<DetailedReportRecord>> fetchDetailedDailyReport({
    required DateTime start,
    required DateTime end,
    required String? establishmentId,
    required String? departmentId,
    required String? userId,
  }) async {
    print("📌 FETCH REPORT");
    print("   Range: $start → $end | Est: $establishmentId | Dept: $departmentId | User: $userId");

    Query<Map<String, dynamic>> q = _db
        .collection(releasesCol)
        .where('releaseDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('releaseDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .where('establishmentId', isEqualTo: establishmentId);

    // 📦 Query a Firestore
    final snap = await q.get();
    print("📦 Firestore docs encontrados: ${snap.size}");

    List<DetailedReportRecord> results = [];

    for (final doc in snap.docs) {
      final data = doc.data();

      final spotId = data['parkingSpotId']?.toString() ?? "";
      final bookedBy = data['bookedByUserId']?.toString() ?? "";
      final releaseDept = data['departmentId']?.toString() ?? "";

      // ✅ Obtener spot
      final spot = await _getSpot(spotId);
      final spotDeptId = spot?['departmentId']?.toString() ?? "";

      // ✅ Obtener user solo si existe
      final user = bookedBy.isNotEmpty ? await _getUser(bookedBy) : null;

      // ✅ Determinar deptId final
      final deptId = user?['departmentId']?.toString()
    ?? (releaseDept.isNotEmpty ? releaseDept : spotDeptId);

      final dept = await _getDept(deptId);

      // ✅ Filtros manuales
      if (departmentId != null && departmentId.isNotEmpty && deptId != departmentId) continue;
      if (userId != null && bookedBy != userId) continue;

      results.add(
        DetailedReportRecord(
          releaseDate: (data['releaseDate'] as Timestamp).toDate(),
          status: (data['status'] ?? "").toString(),
          userId: bookedBy.isEmpty ? null : bookedBy,
          userName: user?['displayName'] ?? "Titular",
          departmentId: deptId.isEmpty ? null : deptId,
          departmentName: dept?['name'] ?? "",
          spotId: spotId,
          spotName: spot?['spotNumber']?.toString() ?? "",
        ),
      );
    }

    print("✅ Filas finales: ${results.length}");
    return results;
  }

  // ------- DROPDOWNS ---------

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final snap = await _db.collection(departmentsCol).get();
    return snap.docs.map((e) => {
      "id": e.id,
      "name": e.data()['name'] ?? "",
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final snap = await _db.collection(usersCol).get();
    return snap.docs.map((e) => {
      "id": e.id,
      "name": e.data()['displayName'] ?? "",
    }).toList();
  }

  // ------- CACHES ---------

  Future<Map<String, dynamic>?> _getSpot(String id) async {
    if (id.isEmpty) return null;
    if (_spotCache.containsKey(id)) return _spotCache[id];
    final doc = await _db.collection(spotsCol).doc(id).get();
    return _spotCache[id] = doc.data();
  }

  Future<Map<String, dynamic>?> _getUser(String id) async {
    if (id.isEmpty) return null;
    if (_userCache.containsKey(id)) return _userCache[id];
    final doc = await _db.collection(usersCol).doc(id).get();
    return _userCache[id] = doc.data();
  }

  Future<Map<String, dynamic>?> _getDept(String id) async {
    if (id.isEmpty) return null;
    if (_deptCache.containsKey(id)) return _deptCache[id];
    final doc = await _db.collection(departmentsCol).doc(id).get();
    return _deptCache[id] = doc.data();
  }

Future<int> countTotalSpots(String establishmentId) async {
  final snap = await _db
      .collection(spotsCol)
      .where('establishmentId', isEqualTo: establishmentId)
      .get();

  return snap.size;
}


}
