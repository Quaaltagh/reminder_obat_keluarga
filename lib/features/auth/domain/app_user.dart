// Model User (akun login). Sesuai skema: uid, displayName, email, circleIds, dst.


// Model domain untuk dokumen `users/{userId}` di Firestore.
// Lihat Skema_Firestore_CareCircle.md bagian 1 untuk referensi skema.
//
// Ini BUKAN objek Firebase Auth (User dari package:firebase_auth).
// AppUser adalah representasi dokumen profil di Firestore, yang dibuat
// terpisah setelah proses registrasi Firebase Auth berhasil.

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final List<String> circleIds;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.fcmToken,
    required this.createdAt,
    this.circleIds = const [],
  });

  /// Dipakai saat pertama kali membuat dokumen user baru di Firestore,
  /// segera setelah Firebase Auth registration sukses.
  factory AppUser.newUser({
    required String uid,
    required String displayName,
    required String email,
    String? phoneNumber,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      fcmToken: null,
      createdAt: DateTime.now(),
      circleIds: const [],
    );
  }

  /// Membaca dokumen dari Firestore (Map hasil `doc.data()`).
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      fcmToken: map['fcmToken'] as String?,
      createdAt: _parseCreatedAt(map['createdAt']),
      circleIds: (map['circleIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Dikirim ke Firestore lewat `.set()` / `.update()`.
  /// Catatan: createdAt disimpan sebagai ISO 8601 string agar konsisten
  /// dengan contoh di Skema_Firestore_CareCircle.md. Kalau nanti mau
  /// pakai Firestore Timestamp asli, ganti bagian ini ke
  /// `Timestamp.fromDate(createdAt)` dan sesuaikan _parseCreatedAt.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
      'circleIds': circleIds,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? fcmToken,
    List<String>? circleIds,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      circleIds: circleIds ?? this.circleIds,
    );
  }

  static DateTime _parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    // Menangani baik Firestore Timestamp (kalau suatu saat dipakai)
    // maupun String ISO 8601 (format default saat ini).
    if (value is String) return DateTime.parse(value);
    // Firestore Timestamp punya method toDate() — dicek via dynamic
    // supaya file ini tidak perlu import cloud_firestore langsung.
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }
}