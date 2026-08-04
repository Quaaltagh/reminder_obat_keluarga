// CRUD careCircles + subcollection members (Firestore).
// Sesuai security rules: hanya admin yang bisa update/delete circle & ubah role member.
// Repository untuk collection `careCircles` beserta subcollection
// `members` dan `joinRequests`.
//
// Method-method di sini SENGAJA melakukan beberapa write Firestore
// sekaligus dalam satu method (misal createCircleWithAdmin) supaya
// screen (UI layer) tidak perlu tahu detail urutan/orkestrasi —
// screen cukup panggil satu method dan dapat hasil akhirnya.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/care_circle.dart';
import '../domain/circle_member.dart';
import '../domain/join_request.dart';
import '../../auth/data/user_repository.dart';
import '../../patient/data/patient_repository.dart';

part 'care_circle_repository.g.dart';

class CircleRoleSearchResult {
  final CareCircle circle;
  final String? targetRole;

  const CircleRoleSearchResult({
    required this.circle,
    this.targetRole,
  });
}

class CareCircleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _circlesCollection =>
      _firestore.collection('careCircles');

  // ============================================================
  // CREATE CIRCLE (alur Admin: "Buat Care Circle Baru")
  // ============================================================

  /// Membuat Care Circle baru SEKALIGUS mendaftarkan pembuatnya sebagai
  /// admin di subcollection members. Dua write ini dianggap satu unit
  /// logis dari sudut pandang UI (Admin baru selesai "membuat circle"
  /// kalau kedua-duanya berhasil), jadi dibungkus di satu method.
  ///
  /// Mengembalikan circleId yang baru dibuat.
  Future<String> createCircleWithAdmin({
    required String circleName,
    required String adminUserId,
  }) async {
    final circleRef = _circlesCollection.doc(); // generate ID otomatis
    final inviteCode = _generateInviteCode();

    final circle = CareCircle(
      circleId: circleRef.id,
      name: circleName,
      createdBy: adminUserId,
      createdAt: DateTime.now(),
      patientProfileIds: const [],
      inviteCode: inviteCode,
    );

    final adminMember = CircleMember(
      userId: adminUserId,
      circleRole: CircleRole.admin,
      joinedAt: DateTime.now(),
      invitedBy: adminUserId, // diri sendiri, karena dia yang membuat
    );

    // Batch write supaya kedua dokumen tercipta bersamaan (atomic).
    final batch = _firestore.batch();
    batch.set(circleRef, circle.toMap());
    batch.set(
      circleRef.collection('members').doc(adminUserId),
      adminMember.toMap(),
    );
    await batch.commit();

    return circleRef.id;
  }

  /// Menghasilkan kode 6 digit angka polos, misal "782945".
  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  /// Admin generate ulang kode invite (misal karena kode lama bocor).
  Future<void> regenerateInviteCode(String circleId) async {
    await _circlesCollection.doc(circleId).update({
      'inviteCode': _generateInviteCode(),
    });
  }

  /// Menambahkan patientProfileId ke daftar pasien milik circle ini.
  /// Dipanggil setelah PatientRepository berhasil membuat profile baru.
  Future<void> addPatientProfileId(String circleId, String patientId) async {
    await _circlesCollection.doc(circleId).update({
      'patientProfileIds': FieldValue.arrayUnion([patientId]),
    });
  }

  Future<CareCircle?> getCircle(String circleId) async {
    final doc = await _circlesCollection.doc(circleId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CareCircle.fromMap(doc.id, doc.data()!);
  }

  // ============================================================
  // JOIN VIA KODE (alur Member: "Saya Punya Kode Undangan")
  // ============================================================

  /// Mencari circle yang inviteCode-nya cocok, sekaligus mem-parse role
  /// target jika kode memiliki prefix P-, I-, atau V-.
  Future<CircleRoleSearchResult?> findCircleAndRoleByInviteCode(String inputCode) async {
    final cleanInput = inputCode.trim().replaceAll(' ', '').replaceAll('-', '').toUpperCase();
    String? targetRole;
    String cleanBaseCode = cleanInput;

    if (cleanInput.startsWith('P')) {
      targetRole = 'patient';
      cleanBaseCode = cleanInput.substring(1);
    } else if (cleanInput.startsWith('I')) {
      targetRole = 'editor';
      cleanBaseCode = cleanInput.substring(1);
    } else if (cleanInput.startsWith('V')) {
      targetRole = 'viewer';
      cleanBaseCode = cleanInput.substring(1);
    }

    var query = await _circlesCollection
        .where('inviteCode', isEqualTo: cleanBaseCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      query = await _circlesCollection
          .where('inviteCode', isEqualTo: cleanInput)
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return CircleRoleSearchResult(
      circle: CareCircle.fromMap(doc.id, doc.data()),
      targetRole: targetRole,
    );
  }

  /// Backward compatibility wrapper
  Future<CareCircle?> findCircleByInviteCode(String inviteCode) async {
    final result = await findCircleAndRoleByInviteCode(inviteCode);
    return result?.circle;
  }

  /// Membuat join request berstatus "pending" beserta targetRole jika ada.
  Future<void> submitJoinRequest({
    required String circleId,
    required String userId,
    required String displayName,
    required String email,
    String? targetRole,
  }) async {
    final request = JoinRequest(
      userId: userId,
      displayName: displayName,
      email: email,
      requestedAt: DateTime.now(),
      status: JoinRequestStatus.pending,
      targetRole: targetRole,
    );

    await _circlesCollection
        .doc(circleId)
        .collection('joinRequests')
        .doc(userId)
        .set(request.toMap());
  }

  /// Stream status join request tertentu — dipakai di
  /// "waiting_approval_screen.dart" supaya user otomatis pindah layar
  /// begitu Admin approve/reject, tanpa perlu refresh manual.
  Stream<JoinRequest?> watchJoinRequest(String circleId, String userId) {
    return _circlesCollection
        .doc(circleId)
        .collection('joinRequests')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return JoinRequest.fromMap(doc.id, doc.data()!);
    });
  }

  /// Stream semua join request berstatus "pending" untuk circle
  /// tertentu — dipakai Admin di halaman Care Circle untuk melihat
  /// daftar permintaan yang perlu di-approve/reject.
  Stream<List<JoinRequest>> watchPendingJoinRequests(String circleId) {
    return _circlesCollection
        .doc(circleId)
        .collection('joinRequests')
        .where('status', isEqualTo: JoinRequestStatus.pending.value)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => JoinRequest.fromMap(d.id, d.data())).toList());
  }

  /// Admin approve join request: buat entry members/{userId} dengan
  /// circleRole member, DAN update status joinRequest jadi approved.
  /// Dibungkus batch supaya atomic.
  Future<void> approveJoinRequest({
    required String circleId,
    required String userId,
    required String approvedByAdminId,
  }) async {
    final circleRef = _circlesCollection.doc(circleId);
    final newMember = CircleMember(
      userId: userId,
      circleRole: CircleRole.member,
      joinedAt: DateTime.now(),
      invitedBy: approvedByAdminId,
    );

    final batch = _firestore.batch();
    batch.set(circleRef.collection('members').doc(userId), newMember.toMap());

    final reqRef = circleRef.collection('joinRequests').doc(userId);
    final reqSnap = await reqRef.get();
    if (reqSnap.exists) {
      batch.update(reqRef, {'status': JoinRequestStatus.approved.value});
    }

    await batch.commit();
  }

  /// Approve join request DAN jadikan orang tersebut Patient baru
  Future<void> approveAsNewPatient({
    required String circleId,
    required String userId,
    required String adminUserId,
    required String patientName,
    required UserRepository userRepo,
    required PatientRepository patientRepo,
    int? age,
    String? healthConditionNotes,
  }) async {
    // 1. Approve dulu supaya userId resmi jadi member circle.
    await approveJoinRequest(
      circleId: circleId,
      userId: userId,
      approvedByAdminId: adminUserId,
    );

    // 2. Update users/{userId}.circleIds
    await userRepo.addCircleId(userId, circleId);

    // 3. Jika circle sudah punya PatientProfile yang belum terhubung, hubungkan!
    final circle = await getCircle(circleId);
    if (circle != null && circle.patientProfileIds.isNotEmpty) {
      for (final pid in circle.patientProfileIds) {
        final profile = await patientRepo.getPatientProfile(pid);
        if (profile != null && (profile.linkedUserId == null || profile.linkedUserId!.isEmpty)) {
          await patientRepo.linkUserToPatientProfile(patientId: pid, userId: userId);
          return;
        }
      }
    }

    // 4. Jika belum ada profil pasien yang cocok/kosong, buat PatientProfile baru.
    final patientId = await patientRepo.createPatientProfile(
      circleId: circleId,
      name: patientName,
      linkedUserId: userId,
      age: age,
      healthConditionNotes: healthConditionNotes,
    );

    await addPatientProfileId(circleId, patientId);
  }

  /// Admin reject join request: HANYA update status, tidak pernah
  /// membuat entry di members/.
  Future<void> rejectJoinRequest({
    required String circleId,
    required String userId,
  }) async {
    await _circlesCollection
        .doc(circleId)
        .collection('joinRequests')
        .doc(userId)
        .update({'status': JoinRequestStatus.rejected.value});
  }

  /// User membatalkan join request
  Future<void> cancelJoinRequest({
    required String circleId,
    required String userId,
  }) async {
    await _circlesCollection
        .doc(circleId)
        .collection('joinRequests')
        .doc(userId)
        .delete();
  }

  // ============================================================
  // MEMBERS
  // ============================================================

  Stream<List<CircleMember>> watchMembers(String circleId) {
    return _circlesCollection
        .doc(circleId)
        .collection('members')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CircleMember.fromMap(d.id, d.data())).toList());
  }

  Future<CircleMember?> getMember(String circleId, String userId) async {
    final doc = await _circlesCollection
        .doc(circleId)
        .collection('members')
        .doc(userId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return CircleMember.fromMap(doc.id, doc.data()!);
  }
}

@riverpod
CareCircleRepository careCircleRepository(Ref ref) {
  return CareCircleRepository();
}