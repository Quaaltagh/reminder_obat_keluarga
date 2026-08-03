// Model domain BARU untuk dokumen
// `careCircles/{circleId}/joinRequests/{userId}`.
//
// Ini bagian dari alur "join butuh approval Admin" — bukan auto-join.
// Ketika seseorang memasukkan kode invite yang valid, sistem TIDAK
// langsung menulis ke `members/{userId}`. Sebaliknya, sistem membuat
// dokumen di sini dengan status "pending", lalu menunggu Admin
// approve/reject dari halaman Care Circle.
//
// Alur lengkap:
// 1. User masukkan kode -> dicari circle yang cocok
// 2. Buat joinRequests/{userId} dengan status: pending
// 3. User lihat layar "Menunggu persetujuan Admin..."
// 4. Admin approve -> buat members/{userId} (circleRole: member),
//    lalu update status di sini jadi "approved"
//    Admin reject -> update status jadi "rejected" saja

enum JoinRequestStatus { pending, approved, rejected }

extension JoinRequestStatusX on JoinRequestStatus {
  String get value => switch (this) {
        JoinRequestStatus.pending => 'pending',
        JoinRequestStatus.approved => 'approved',
        JoinRequestStatus.rejected => 'rejected',
      };

  static JoinRequestStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return JoinRequestStatus.approved;
      case 'rejected':
        return JoinRequestStatus.rejected;
      case 'pending':
      default:
        return JoinRequestStatus.pending;
    }
  }
}

class JoinRequest {
  final String userId;
  final String displayName;
  final String email;
  final DateTime requestedAt;
  final JoinRequestStatus status;

  /// Role target yang diminta dari kode invite ('patient' | 'editor' | 'viewer').
  final String? targetRole;

  const JoinRequest({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
    this.targetRole,
  });

  factory JoinRequest.fromMap(String userId, Map<String, dynamic> map) {
    return JoinRequest(
      userId: userId,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      requestedAt: _parseDate(map['requestedAt']),
      status: JoinRequestStatusX.fromString(map['status'] as String?),
      targetRole: map['targetRole'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'requestedAt': requestedAt.toIso8601String(),
      'status': status.value,
      if (targetRole != null) 'targetRole': targetRole,
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