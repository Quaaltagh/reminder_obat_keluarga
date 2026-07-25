// Model CareCircle: circleId, name, createdBy, patientProfileIds.
// Model domain untuk dokumen `careCircles/{circleId}` di Firestore.
// Lihat Skema_Firestore_CareCircle.md bagian 2 untuk referensi awal skema.
//
// Catatan penyesuaian dari skema awal: `inviteCode` disimpan sebagai field
// LANGSUNG di dokumen ini (bukan collection `invites` terpisah), karena
// kode bersifat multi-use dan melekat ke circle (Admin bisa generate ulang
// kapan saja). Lihat join_request.dart untuk alur approval join.

class CareCircle {
  final String circleId;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final List<String> patientProfileIds;

  /// Kode 6 digit untuk join circle ini. Multi-use — tetap berlaku sampai
  /// di-generate ulang oleh admin (lihat CareCircleRepository.regenerateInviteCode).
  final String inviteCode;

  const CareCircle({
    required this.circleId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.patientProfileIds = const [],
    required this.inviteCode,
  });

  factory CareCircle.fromMap(String circleId, Map<String, dynamic> map) {
    return CareCircle(
      circleId: circleId,
      name: map['name'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']),
      patientProfileIds: (map['patientProfileIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      inviteCode: map['inviteCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'patientProfileIds': patientProfileIds,
      'inviteCode': inviteCode,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}