// Model domain untuk dokumen `patientProfiles/{patientId}` di Firestore.
// Lihat Skema_Firestore_CareCircle.md bagian 3 untuk skema & prinsip
// desain lengkap (kenapa "pasien" adalah entitas terpisah, bukan role
// akun permanen).

class PatientProfile {
  final String patientId;
  final String circleId;
  final String name;
  final String? linkedUserId;
  final int? age;
  final String? healthConditionNotes;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  /// Map userId -> "editor" | "viewer". Independen dari circleRole.
  final Map<String, String> careGivers;

  const PatientProfile({
    required this.patientId,
    required this.circleId,
    required this.name,
    this.linkedUserId,
    this.age,
    this.healthConditionNotes,
    this.photoUrl,
    this.isActive = true,
    required this.createdAt,
    this.careGivers = const {},
  });

  /// Dipakai saat Admin mengisi form "Create Patient Profile" di alur
  /// onboarding (screenshot: Patient Name, Age, Health Condition Notes).
  factory PatientProfile.newProfile({
    required String patientId,
    required String circleId,
    required String name,
    String? linkedUserId,
    int? age,
    String? healthConditionNotes,
    String? photoUrl,
  }) {
    return PatientProfile(
      patientId: patientId,
      circleId: circleId,
      name: name,
      linkedUserId: linkedUserId,
      age: age,
      healthConditionNotes: healthConditionNotes,
      photoUrl: photoUrl,
      isActive: true,
      createdAt: DateTime.now(),
      careGivers: const {},
    );
  }

  factory PatientProfile.fromMap(String patientId, Map<String, dynamic> map) {
    return PatientProfile(
      patientId: patientId,
      circleId: map['circleId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      linkedUserId: map['linkedUserId'] as String?,
      age: map['age'] as int?,
      healthConditionNotes: map['healthConditionNotes'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseDate(map['createdAt']),
      careGivers: (map['careGivers'] as Map<dynamic, dynamic>?)?.map(
            (key, value) => MapEntry(key as String, value as String),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'circleId': circleId,
      'name': name,
      'linkedUserId': linkedUserId,
      'age': age,
      'healthConditionNotes': healthConditionNotes,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'careGivers': careGivers,
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