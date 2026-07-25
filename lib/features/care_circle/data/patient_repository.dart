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
}

@riverpod
PatientRepository patientRepository(Ref ref) {
  return PatientRepository();
}