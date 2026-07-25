// Repository untuk collection `users/{userId}` di Firestore.
// Terpisah dari AuthRepository (yang urus Firebase Auth) — repository ini
// murni urusan dokumen profil user di Firestore.
//
// Dipanggil secara terpisah dari register_screen.dart, SETELAH
// AuthRepository.registerWithEmail() berhasil. Contoh pemakaian di
// register_screen.dart:
//
//   final credential = await authRepository.registerWithEmail(email, password);
//   await userRepository.createUserDocument(
//     uid: credential.user!.uid,
//     displayName: nameController.text.trim(),
//     email: email,
//   );

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/app_user.dart';

part 'user_repository.g.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Membuat dokumen `users/{uid}` baru di Firestore.
  /// Dipanggil sekali, tepat setelah registrasi Firebase Auth berhasil.
  ///
  /// Memakai `.set()` (bukan `.add()`) karena kita ingin document ID
  /// SAMA PERSIS dengan Firebase Auth UID — supaya lookup `users/{uid}`
  /// selalu konsisten dan bisa dipakai langsung sebagai referensi di
  /// careCircles/members, patientProfiles.careGivers, dst.
  Future<void> createUserDocument({
    required String uid,
    required String displayName,
    required String email,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    final appUser = AppUser.newUser(
      uid: uid,
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
    );

    await _usersCollection.doc(uid).set(appUser.toMap());
  }

  /// Mengambil dokumen user sekali (bukan stream). Berguna untuk cek
  /// keberadaan dokumen atau ambil data profil di tempat non-reactive.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!);
  }

  /// Stream dokumen user — dipakai kalau ada layar yang perlu update
  /// reaktif (misal displayName berubah di tempat lain lalu ter-refresh
  /// otomatis di sini).
  Stream<AppUser?> watchUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.data()!);
    });
  }

  /// Menambahkan circleId ke field `circleIds` milik user. Dipanggil
  /// saat user berhasil create/join sebuah Care Circle (dipakai nanti
  /// di onboarding flow — poin 4 di roadmap).
  Future<void> addCircleId(String uid, String circleId) async {
    await _usersCollection.doc(uid).update({
      'circleIds': FieldValue.arrayUnion([circleId]),
    });
  }

  /// Update token FCM (dipanggil saat app dapat/refresh token push
  /// notification). Tidak dipakai sekarang, disiapkan untuk fase FCM.
  Future<void> updateFcmToken(String uid, String token) async {
    await _usersCollection.doc(uid).update({'fcmToken': token});
  }
}

@riverpod
UserRepository userRepository(Ref ref) {
  return UserRepository();
}

/// Provider stream untuk memantau dokumen user yang sedang login secara
/// reaktif. uid diberikan dari luar (biasanya dari currentUserProvider
/// atau authStateChanges di auth_provider.dart).
@riverpod
Stream<AppUser?> watchAppUser(Ref ref, String uid) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.watchUser(uid);
}