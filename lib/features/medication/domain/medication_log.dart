import 'package:cloud_firestore/cloud_firestore.dart';

enum MedicationStatus {
  taken,
  scheduled,
  missed,
}

class MedicationLog {
  final String id;
  final String medicationId;
  final String patientId;
  final String medicationName;
  final String dosage;
  final String instruction;
  final String scheduledTime;
  final String iconType;
  final MedicationStatus status;
  final DateTime? takenAt;
  final String? takenByUserId;
  final String? photoUrl;
  final String dateString; // Format: YYYY-MM-DD

  const MedicationLog({
    required this.id,
    required this.medicationId,
    required this.patientId,
    required this.medicationName,
    required this.dosage,
    required this.instruction,
    required this.scheduledTime,
    this.iconType = 'pill',
    required this.status,
    this.takenAt,
    this.takenByUserId,
    this.photoUrl,
    required this.dateString,
  });

  factory MedicationLog.fromMap(String id, Map<String, dynamic> map) {
    MedicationStatus parseStatus(String? val) {
      switch (val) {
        case 'taken':
          return MedicationStatus.taken;
        case 'missed':
          return MedicationStatus.missed;
        default:
          return MedicationStatus.scheduled;
      }
    }

    DateTime? parseDateTime(dynamic val) {
      if (val is Timestamp) {
        return val.toDate();
      }
      return null;
    }

    return MedicationLog(
      id: id,
      medicationId: map['medicationId'] as String? ?? '',
      patientId: map['patientId'] as String? ?? '',
      medicationName: map['medicationName'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      instruction: map['instruction'] as String? ?? '',
      scheduledTime: map['scheduledTime'] as String? ?? '08:00 AM',
      iconType: map['iconType'] as String? ?? 'pill',
      status: parseStatus(map['status'] as String?),
      takenAt: parseDateTime(map['takenAt']),
      takenByUserId: map['takenByUserId'] as String?,
      photoUrl: map['photoUrl'] as String?,
      dateString: map['dateString'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicationId': medicationId,
      'patientId': patientId,
      'medicationName': medicationName,
      'dosage': dosage,
      'instruction': instruction,
      'scheduledTime': scheduledTime,
      'iconType': iconType,
      'status': status.name,
      'takenAt': takenAt != null ? Timestamp.fromDate(takenAt!) : null,
      'takenByUserId': takenByUserId,
      'photoUrl': photoUrl,
      'dateString': dateString,
    };
  }
}
