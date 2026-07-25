// Model CircleMember: userId, circleRole (admin/member), joinedAt.
// Model domain untuk dokumen `careCircles/{circleId}/members/{userId}`.
// circleRole di sini TIDAK ADA HUBUNGANNYA dengan status pasien —
// lihat catatan di Skema_Firestore_CareCircle.md bagian 2.

enum CircleRole { admin, member }

extension CircleRoleX on CircleRole {
  String get value => switch (this) {
        CircleRole.admin => 'admin',
        CircleRole.member => 'member',
      };

  static CircleRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return CircleRole.admin;
      case 'member':
      default:
        return CircleRole.member;
    }
  }
}

class CircleMember {
  final String userId;
  final CircleRole circleRole;
  final DateTime joinedAt;
  final String invitedBy;

  const CircleMember({
    required this.userId,
    required this.circleRole,
    required this.joinedAt,
    required this.invitedBy,
  });

  factory CircleMember.fromMap(String userId, Map<String, dynamic> map) {
    return CircleMember(
      userId: userId,
      circleRole: CircleRoleX.fromString(map['circleRole'] as String?),
      joinedAt: _parseDate(map['joinedAt']),
      invitedBy: map['invitedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'circleRole': circleRole.value,
      'joinedAt': joinedAt.toIso8601String(),
      'invitedBy': invitedBy,
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