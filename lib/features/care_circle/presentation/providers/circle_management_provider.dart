// Provider untuk "Daftar Family (Admin)" dan "Approval Join Request".
//
// CATATAN DESAIN PENTING (lihat CHECKLIST_PROGRESS.md & keputusan sesi ini):
// - Untuk versi ini, circle diasumsikan hanya punya SATU pasien aktif
//   (patientProfileIds.first). Kalau nanti circle mendukung multi-pasien
//   penuh, bagian yang mengambil "patient pertama" di bawah ini adalah
//   satu-satunya tempat yang perlu diperluas (jadi picker per-pasien).
// - Role "editor"/"viewer" adalah milik PatientProfile.careGivers, BUKAN
//   milik CircleMember. Provider ini menggabungkan keduanya jadi satu
//   model tampilan (FamilyMemberDisplay) supaya screen tidak perlu tahu
//   soal penggabungan dua sumber data.
// - Admin (circleRole == admin) tidak dianggap "caregiver dengan role" —
//   admin selalu tampil dengan badge "Admin" saja, sesuai desain Figma.
//
// Lokasi: lib/features/care_circle/presentation/providers/circle_management_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/care_circle_repository.dart';
import '../../domain/care_circle.dart';
import '../../domain/circle_member.dart';
import '../../domain/join_request.dart';
// PatientRepository & PatientProfile sengaja BUKAN di dalam
// features/care_circle/ — keduanya feature terpisah karena
// patientProfiles adalah top-level collection di Firestore, bukan
// sub-konsep dari careCircles. Sesuaikan path relatif ini kalau lokasi
// folder "patient" kamu berbeda dari lib/features/patient/.
import '../../../patient/data/patient_repository.dart';
import '../../../patient/domain/patient_profile.dart';

part 'circle_management_provider.g.dart';

/// Role caregiver untuk ditampilkan/dipilih di UI. Terpisah dari string
/// mentah "editor"/"viewer" yang dipakai di Firestore supaya UI type-safe.
enum CaregiverRole {
  editor,
  viewer;

  String get value => name; // "editor" | "viewer"

  String get label => switch (this) {
        CaregiverRole.editor => 'Input Member',
        CaregiverRole.viewer => 'View Only',
      };

  static CaregiverRole? fromValue(String? value) {
    return switch (value) {
      'editor' => CaregiverRole.editor,
      'viewer' => CaregiverRole.viewer,
      _ => null,
    };
  }
}

/// Model gabungan untuk satu baris di Daftar Family: identitas member +
/// role tampilan (Admin, atau Input Member/View Only kalau caregiver).
class FamilyMemberDisplay {
  const FamilyMemberDisplay({
    required this.userId,
    required this.circleRole,
    required this.caregiverRole,
    required this.joinedAt,
  });

  final String userId;
  final CircleRole circleRole;

  /// Null kalau member ini admin, atau kalau dia caregiver tapi entah
  /// kenapa belum punya entry di careGivers (data tidak konsisten —
  /// screen sebaiknya tetap menampilkan sesuatu, bukan crash).
  final CaregiverRole? caregiverRole;

  final DateTime joinedAt;

  bool get isAdmin => circleRole == CircleRole.admin;

  String get roleLabel => isAdmin ? 'Admin' : (caregiverRole?.label ?? 'Belum diatur');
}

/// Menggabungkan watchMembers() (CareCircleRepository) dengan
/// watchPatient() dari pasien pertama circle (PatientRepository), supaya
/// Daftar Family dapat badge role yang benar tanpa screen perlu
/// menggabungkan dua stream sendiri.
@riverpod
Stream<List<FamilyMemberDisplay>> watchFamilyMembers(Ref ref, String circleId) {
  final careCircleRepo = ref.watch(careCircleRepositoryProvider);
  final patientRepo = ref.watch(patientRepositoryProvider);

  final circleDoc = FirebaseFirestore.instance.collection('careCircles').doc(circleId);

  return circleDoc.snapshots().asyncExpand((circleSnap) {
    final circle = circleSnap.exists && circleSnap.data() != null
        ? CareCircle.fromMap(circleSnap.id, circleSnap.data()!)
        : null;

    final firstPatientId =
        (circle != null && circle.patientProfileIds.isNotEmpty) ? circle.patientProfileIds.first : null;

    final membersStream = careCircleRepo.watchMembers(circleId);
    final patientStream = firstPatientId != null
        ? patientRepo.watchPatient(firstPatientId)
        : Stream<PatientProfile?>.value(null);

    return membersStream.asyncMap((members) async {
      final patient = await patientStream.first;
      return members.map((member) {
        final roleValue = patient?.careGivers[member.userId];
        return FamilyMemberDisplay(
          userId: member.userId,
          circleRole: member.circleRole,
          caregiverRole: CaregiverRole.fromValue(roleValue),
          joinedAt: member.joinedAt,
        );
      }).toList();
    });
  });
}

/// Stream jumlah join request pending — dipakai untuk badge notifikasi
/// di icon lonceng pada Daftar Family screen.
@riverpod
Stream<int> watchPendingJoinRequestCount(Ref ref, String circleId) {
  final repo = ref.watch(careCircleRepositoryProvider);
  return repo.watchPendingJoinRequests(circleId).map((list) => list.length);
}

/// Actions untuk approve/reject join request dan remove member. Semua
/// method di sini adalah orkestrasi 2 repository (CareCircle + Patient),
/// jadi ditaruh di provider layer ini — bukan di masing-masing
/// repository — supaya masing-masing repository tetap fokus ke satu
/// collection saja (konsisten dengan pola OnboardingService).
@riverpod
class CircleManagementActions extends _$CircleManagementActions {
  @override
  void build() {}

  /// Approve join request DAN jadikan orang tersebut Patient baru:
  /// membuat PatientProfile baru yang linked ke userId ini.
  ///
  /// Dipanggil dari layar approval saat Admin memilih "Jadi Pasien Baru".
  Future<void> approveAsNewPatient({
    required String circleId,
    required String userId,
    required String adminUserId,
    required String patientName,
    int? age,
    String? healthConditionNotes,
  }) async {
    final careCircleRepo = ref.read(careCircleRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    // 1. Approve dulu supaya userId resmi jadi member circle (role member).
    await careCircleRepo.approveJoinRequest(
      circleId: circleId,
      userId: userId,
      approvedByAdminId: adminUserId,
    );

    // 2. Buat PatientProfile baru, linked ke user yang baru approve.
    final patientId = await patientRepo.createPatientProfile(
      circleId: circleId,
      name: patientName,
      linkedUserId: userId,
      age: age,
      healthConditionNotes: healthConditionNotes,
    );

    // 3. Daftarkan patientId baru ke careCircles.patientProfileIds.
    await careCircleRepo.addPatientProfileId(circleId, patientId);
  }

  /// Approve join request DAN jadikan orang tersebut Caregiver dengan
  /// role tertentu (editor/viewer) untuk pasien PERTAMA di circle.
  ///
  /// Dipanggil dari layar approval saat Admin memilih
  /// "Jadi Caregiver" + pilih role.
  Future<void> approveAsCaregiver({
    required String circleId,
    required String userId,
    required String adminUserId,
    required CaregiverRole role,
  }) async {
    final careCircleRepo = ref.read(careCircleRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);

    final circle = await careCircleRepo.getCircle(circleId);
    if (circle == null || circle.patientProfileIds.isEmpty) {
      throw StateError(
        'Circle belum punya Patient Profile — buat profil pasien '
        'terlebih dahulu sebelum menambahkan caregiver.',
      );
    }
    final firstPatientId = circle.patientProfileIds.first;

    // 1. Approve dulu supaya userId resmi jadi member circle (role member).
    await careCircleRepo.approveJoinRequest(
      circleId: circleId,
      userId: userId,
      approvedByAdminId: adminUserId,
    );

    // 2. Set role caregiver di careGivers map milik pasien pertama.
    await patientRepo.setCaregiverRole(
      patientId: firstPatientId,
      userId: userId,
      role: role.value,
    );
  }

  Future<void> reject({required String circleId, required String userId}) async {
    final repo = ref.read(careCircleRepositoryProvider);
    await repo.rejectJoinRequest(circleId: circleId, userId: userId);
  }

  /// Menghapus anggota dari circle (tombol tempat sampah di Daftar Family).
  /// TIDAK menghapus PatientProfile terkait meski member itu linkedUserId
  /// suatu pasien — itu keputusan terpisah yang sengaja tidak
  /// diotomatisasi (menghapus akses ≠ menghapus data medis pasien).
  Future<void> removeMember({required String circleId, required String userId}) async {
    await FirebaseFirestore.instance
        .collection('careCircles')
        .doc(circleId)
        .collection('members')
        .doc(userId)
        .delete();
  }
}