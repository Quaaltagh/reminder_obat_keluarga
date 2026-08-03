import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/medication.dart';
import '../domain/medication_log.dart';

class MedicationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _medicationsColl(String patientId) =>
      _firestore.collection('patientProfiles').doc(patientId).collection('medications');

  CollectionReference<Map<String, dynamic>> _medicationLogsColl(String patientId) =>
      _firestore.collection('patientProfiles').doc(patientId).collection('medicationLogs');

  CollectionReference<Map<String, dynamic>> get _topMedicationsColl =>
      _firestore.collection('medications');

  CollectionReference<Map<String, dynamic>> get _topMedicationLogsColl =>
      _firestore.collection('medicationLogs');

  /// Stream daftar obat aktif milik pasien (Mendukung subcollection & top-level fallback)
  Stream<List<Medication>> watchMedications(String patientId) {
    if (patientId.isEmpty) return Stream.value([]);

    late StreamController<List<Medication>> controller;
    StreamSubscription? subSub;
    StreamSubscription? topSub;

    void listenToTopLevel() {
      topSub = _topMedicationsColl
          .where('patientId', isEqualTo: patientId)
          .snapshots()
          .listen(
        (topSnap) {
          final topList = topSnap.docs
              .map((d) => Medication.fromMap(d.id, d.data()))
              .where((m) => m.isActive)
              .toList();
          if (!controller.isClosed) controller.add(topList);
        },
        onError: (e) {
          if (!controller.isClosed) controller.add([]);
        },
      );
    }

    controller = StreamController<List<Medication>>.broadcast(
      onListen: () {
        subSub = _medicationsColl(patientId).snapshots().listen(
          (snap) {
            final subList = snap.docs
                .map((d) => Medication.fromMap(d.id, d.data()))
                .where((m) => m.isActive)
                .toList();

            if (subList.isEmpty) {
              _topMedicationsColl
                  .where('patientId', isEqualTo: patientId)
                  .get()
                  .then((topSnap) {
                final topList = topSnap.docs
                    .map((d) => Medication.fromMap(d.id, d.data()))
                    .where((m) => m.isActive)
                    .toList();
                if (!controller.isClosed) {
                  controller.add(topList.isNotEmpty ? topList : subList);
                }
              }).catchError((_) {
                if (!controller.isClosed) controller.add(subList);
              });
            } else {
              if (!controller.isClosed) controller.add(subList);
            }
          },
          onError: (err) {
            listenToTopLevel();
          },
        );
      },
      onCancel: () {
        subSub?.cancel();
        topSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Stream logs minum obat tanggal tertentu (default hari ini)
  Stream<List<MedicationLog>> watchMedicationLogsForDate(
      String patientId, String dateString) {
    if (patientId.isEmpty) return Stream.value([]);

    late StreamController<List<MedicationLog>> controller;
    StreamSubscription? subSub;
    StreamSubscription? topSub;

    void listenToTopLevel() {
      topSub = _topMedicationLogsColl
          .where('patientId', isEqualTo: patientId)
          .snapshots()
          .listen(
        (topSnap) {
          final topList = topSnap.docs
              .map((d) => MedicationLog.fromMap(d.id, d.data()))
              .where((l) => l.dateString == dateString)
              .toList();
          if (!controller.isClosed) controller.add(topList);
        },
        onError: (e) {
          if (!controller.isClosed) controller.add([]);
        },
      );
    }

    controller = StreamController<List<MedicationLog>>.broadcast(
      onListen: () {
        subSub = _medicationLogsColl(patientId).snapshots().listen(
          (snap) {
            final subList = snap.docs
                .map((d) => MedicationLog.fromMap(d.id, d.data()))
                .where((l) => l.dateString == dateString)
                .toList();

            if (subList.isEmpty) {
              _topMedicationLogsColl
                  .where('patientId', isEqualTo: patientId)
                  .get()
                  .then((topSnap) {
                final topList = topSnap.docs
                    .map((d) => MedicationLog.fromMap(d.id, d.data()))
                    .where((l) => l.dateString == dateString)
                    .toList();
                if (!controller.isClosed) {
                  controller.add(topList.isNotEmpty ? topList : subList);
                }
              }).catchError((_) {
                if (!controller.isClosed) controller.add(subList);
              });
            } else {
              if (!controller.isClosed) controller.add(subList);
            }
          },
          onError: (err) {
            listenToTopLevel();
          },
        );
      },
      onCancel: () {
        subSub?.cancel();
        topSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Tambah obat baru untuk pasien
  Future<String> addMedication({
    required String patientId,
    required String name,
    required String dosage,
    required String instruction,
    required String scheduledTime,
    String iconType = 'pill',
  }) async {
    final medData = {
      'patientId': patientId,
      'name': name,
      'dosage': dosage,
      'instruction': instruction,
      'scheduledTime': scheduledTime,
      'iconType': iconType,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    try {
      final docRef = _medicationsColl(patientId).doc();
      await docRef.set(medData);
      return docRef.id;
    } catch (e) {
      // Fallback ke top-level 'medications' collection jika subcollection permission denied
      final topDocRef = _topMedicationsColl.doc();
      await topDocRef.set(medData);
      return topDocRef.id;
    }
  }

  /// Tandai obat sudah diminum (Mark as TAKEN)
  Future<void> markAsTaken({
    required String patientId,
    required Medication medication,
    required String dateString,
    required String userId,
    String? photoUrl,
  }) async {
    final logData = {
      'medicationId': medication.id,
      'patientId': patientId,
      'medicationName': medication.name,
      'dosage': medication.dosage,
      'instruction': medication.instruction,
      'scheduledTime': medication.scheduledTime,
      'iconType': medication.iconType,
      'status': MedicationStatus.taken.name,
      'takenAt': FieldValue.serverTimestamp(),
      'takenByUserId': userId,
      'photoUrl': photoUrl,
      'dateString': dateString,
    };

    try {
      final logDocRef = _medicationLogsColl(patientId).doc('${medication.id}_$dateString');
      await logDocRef.set(logData, SetOptions(merge: true));
    } catch (e) {
      final topLogDocRef = _topMedicationLogsColl.doc('${medication.id}_$dateString');
      await topLogDocRef.set(logData, SetOptions(merge: true));
    }
  }

  /// Hapus/Nonaktifkan obat
  Future<void> deleteMedication(String patientId, String medicationId) async {
    try {
      await _medicationsColl(patientId).doc(medicationId).update({
        'isActive': false,
      });
    } catch (e) {
      await _topMedicationsColl.doc(medicationId).update({
        'isActive': false,
      });
    }
  }
}

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return MedicationRepository();
});

final watchPatientMedicationsProvider =
    StreamProvider.family<List<Medication>, String>((ref, patientId) {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.watchMedications(patientId);
});

final watchPatientMedicationLogsProvider =
    StreamProvider.family<List<MedicationLog>, ({String patientId, String dateString})>(
        (ref, arg) {
  final repo = ref.watch(medicationRepositoryProvider);
  return repo.watchMedicationLogsForDate(arg.patientId, arg.dateString);
});
