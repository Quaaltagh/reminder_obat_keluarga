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

part 'care_circle_repository.g.dart';

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

  /// Mencari circle yang inviteCode-nya cocok. Karena inviteCode
  /// disimpan sebagai field biasa (bukan document ID), pencarian
  /// dilakukan lewat query `where`.
  ///
  /// Mengembalikan null kalau tidak ada circle dengan kode tersebut.
  Future<CareCircle?> findCircleByInviteCode(String inviteCode) async {
    final query = await _circlesCollection
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return CareCircle.fromMap(doc.id, doc.data());
  }

  /// Membuat join request berstatus "pending" — BUKAN langsung menulis
  /// ke members/{userId}. Ini implementasi keputusan "join butuh
  /// approval Admin dulu", bukan auto-join.
  Future<void> submitJoinRequest({
    required String circleId,
    required String userId,
    required String displayName,
    required String email,
  }) async {
    final request = JoinRequest(
      userId: userId,
      displayName: displayName,
      email: email,
      requestedAt: DateTime.now(),
      status: JoinRequestStatus.pending,
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
    batch.update(
      circleRef.collection('joinRequests').doc(userId),
      {'status': JoinRequestStatus.approved.value},
    );
    await batch.commit();
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