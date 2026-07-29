// CRUD patientProfiles (Firestore, top-level collection).
// create/delete: admin only. update: admin atau editor caregiver.
// Repository untuk collection `patientProfiles/{patientId}`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/patient_profile.dart';

part 'patient_repository.g.dart';

class PatientRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _patientsCollection =>
      _firestore.collection('patientProfiles');

  /// Membuat Patient Profile baru. Dipanggil dari form "Create Patient
  /// Profile" di alur onboarding Admin, SETELAH Care Circle berhasil
  /// dibuat (perlu circleId dari langkah sebelumnya).
  ///
  /// Mengembalikan patientId yang baru dibuat.
  Future<String> createPatientProfile({
    required String circleId,
    required String name,
    String? linkedUserId,
    int? age,
    String? healthConditionNotes,
    String? photoUrl,
  }) async {
    final patientRef = _patientsCollection.doc();

    final profile = PatientProfile.newProfile(
      patientId: patientRef.id,
      circleId: circleId,
      name: name,
      linkedUserId: linkedUserId,
      age: age,
      healthConditionNotes: healthConditionNotes,
      photoUrl: photoUrl,
    );

    await patientRef.set(profile.toMap());
    return patientRef.id;
  }

  Future<PatientProfile?> getPatientProfile(String patientId) async {
    final doc = await _patientsCollection.doc(patientId).get();
    if (!doc.exists || doc.data() == null) return null;
    return PatientProfile.fromMap(doc.id, doc.data()!);
  }

  /// Stream satu Patient Profile secara reaktif — dipakai di Daftar
  /// Family screen supaya badge role caregiver (editor/viewer) otomatis
  /// ter-update kalau careGivers map berubah, tanpa perlu refresh manual.
  /// Berbeda dari getPatientProfile() (Future, sekali ambil) yang sudah
  /// ada di atas.
  Stream<PatientProfile?> watchPatient(String patientId) {
    return _patientsCollection.doc(patientId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return PatientProfile.fromMap(doc.id, doc.data()!);
    });
  }

  /// Stream semua Patient Profile aktif untuk satu circle — dipakai
  /// nanti untuk dashboard gabungan multi-pasien (poin 7 roadmap).
  Stream<List<PatientProfile>> watchActivePatientsInCircle(String circleId) {
    return _patientsCollection
        .where('circleId', isEqualTo: circleId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PatientProfile.fromMap(d.id, d.data())).toList());
  }

  /// Menetapkan atau mengubah role caregiver ("editor" | "viewer") untuk
  /// satu userId di dalam field careGivers milik pasien tertentu.
  ///
  /// Dipanggil saat Admin approve join request sebagai Caregiver (lihat
  /// CircleManagementActions.approveAsCaregiver di
  /// circle_management_provider.dart), dan bisa dipakai juga nanti kalau
  /// ada fitur "ubah role caregiver yang sudah ada".
  ///
  /// Memakai dot-notation field path (`careGivers.$userId`) dengan
  /// `.set(merge: true)` — bukan `.update()` — supaya tetap aman kalau
  /// suatu saat dipanggil sebelum dokumen pasien benar-benar ter-set
  /// (lihat catatan bug NOT_FOUND di UserRepository.addCircleId()).
  Future<void> setCaregiverRole({
    required String patientId,
    required String userId,
    required String role, // "editor" | "viewer"
  }) async {
    await _patientsCollection.doc(patientId).set({
      'careGivers': {userId: role},
    }, SetOptions(merge: true));
  }

  /// Mencabut akses caregiver (menghapus entry-nya dari careGivers map).
  /// Dipakai kalau nanti Admin ingin "downgrade" caregiver jadi tanpa
  /// akses tanpa menghapusnya dari circle sepenuhnya. FieldValue.delete()
  /// memakai dot-notation supaya hanya key userId itu yang terhapus, map
  /// lain tetap utuh.
  Future<void> removeCaregiverRole({
    required String patientId,
    required String userId,
  }) async {
    await _patientsCollection.doc(patientId).update({
      'careGivers.$userId': FieldValue.delete(),
    });
  }
}

@riverpod
PatientRepository patientRepository(Ref ref) {
  return PatientRepository();
}