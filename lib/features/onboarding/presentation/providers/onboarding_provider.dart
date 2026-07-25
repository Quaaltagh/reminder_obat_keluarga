// Provider untuk alur onboarding: Create Circle (+ Patient Profile) dan
// Join via kode undangan. Ini lapisan yang menghubungkan UI (screens)
// dengan repository (CareCircleRepository, PatientRepository,
// UserRepository).
//
// Sengaja dipisah dari repository supaya orkestrasi lintas-repository
// (misal: buat circle -> buat patient profile -> update user.circleIds)
// tidak numpuk semua di satu repository, dan supaya UI cukup panggil
// satu provider/method tanpa perlu tahu urutan repository mana yang
// dipanggil duluan.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../auth/data/user_repository.dart';
import '../../../care_circle/data/care_circle_repository.dart';
import '../../../care_circle/domain/join_request.dart';
import '../../../patient/data/patient_repository.dart';

part 'onboarding_provider.g.dart';

/// Service yang mengorkestrasi langkah-langkah onboarding lintas
/// repository. Dipanggil dari screen lewat provider di bawah.
class OnboardingService {
  final CareCircleRepository _circleRepo;
  final PatientRepository _patientRepo;
  final UserRepository _userRepo;

  OnboardingService({
    required CareCircleRepository circleRepo,
    required PatientRepository patientRepo,
    required UserRepository userRepo,
  })  : _circleRepo = circleRepo,
        _patientRepo = patientRepo,
        _userRepo = userRepo;

  /// Alur lengkap "Buat Care Circle Baru" (Admin):
  /// 1. Buat careCircles/{circleId} + members/{adminId} (circleRole: admin)
  /// 2. Buat patientProfiles/{patientId} dengan data dari form
  /// 3. Kaitkan patientId ke circle (patientProfileIds)
  /// 4. Update users/{adminId}.circleIds supaya nambah circleId baru
  ///
  /// Mengembalikan circleId yang baru dibuat (dipakai untuk redirect
  /// ke dashboard atau layar sukses berikutnya).
  Future<String> createCircleAndPatientProfile({
    required String adminUserId,
    required String circleName,
    required String patientName,
    int? patientAge,
    String? healthConditionNotes,
    String? patientPhotoUrl,
  }) async {
    // Step 1: buat circle + daftarkan admin
    final circleId = await _circleRepo.createCircleWithAdmin(
      circleName: circleName,
      adminUserId: adminUserId,
    );

    // Step 2: buat patient profile untuk circle ini
    final patientId = await _patientRepo.createPatientProfile(
      circleId: circleId,
      name: patientName,
      age: patientAge,
      healthConditionNotes: healthConditionNotes,
      photoUrl: patientPhotoUrl,
    );

    // Step 3: kaitkan patientId ke circle
    await _circleRepo.addPatientProfileId(circleId, patientId);

    // Step 4: update users/{adminId}.circleIds
    await _userRepo.addCircleId(adminUserId, circleId);

    return circleId;
  }

  /// Alur "Saya Punya Kode Undangan" (Member):
  /// 1. Cari circle dengan inviteCode yang cocok
  /// 2. Kalau ketemu, buat joinRequests/{userId} berstatus pending
  ///    (BUKAN langsung masuk members/ — perlu approval Admin dulu)
  ///
  /// Melempar Exception kalau kode tidak ditemukan, supaya UI bisa
  /// tampilkan pesan error yang sesuai.
  ///
  /// Mengembalikan circleId yang berhasil ditemukan (dipakai untuk
  /// tahu circle mana yang harus di-watch di waiting_approval_screen).
  Future<String> submitJoinRequestByCode({
    required String inviteCode,
    required String userId,
    required String displayName,
    required String email,
  }) async {
    final circle = await _circleRepo.findCircleByInviteCode(inviteCode);
    if (circle == null) {
      throw Exception('Kode undangan tidak ditemukan. Periksa kembali kodenya.');
    }

    await _circleRepo.submitJoinRequest(
      circleId: circle.circleId,
      userId: userId,
      displayName: displayName,
      email: email,
    );

    return circle.circleId;
  }

  /// Dipanggil setelah join request di-approve oleh Admin (terdeteksi
  /// lewat watchJoinRequest). Update users/{userId}.circleIds supaya
  /// user resmi tercatat sebagai anggota circle ini.
  Future<void> finalizeApprovedJoin({
    required String userId,
    required String circleId,
  }) async {
    await _userRepo.addCircleId(userId, circleId);
  }
}

@riverpod
OnboardingService onboardingService(Ref ref) {
  return OnboardingService(
    circleRepo: ref.watch(careCircleRepositoryProvider),
    patientRepo: ref.watch(patientRepositoryProvider),
    userRepo: ref.watch(userRepositoryProvider),
  );
}

/// Stream status join request tertentu, dipakai di
/// waiting_approval_screen.dart untuk auto-redirect begitu Admin
/// approve/reject.
@riverpod
Stream<JoinRequest?> watchJoinRequestStatus(
  Ref ref, {
  required String circleId,
  required String userId,
}) {
  final repo = ref.watch(careCircleRepositoryProvider);
  return repo.watchJoinRequest(circleId, userId);
}