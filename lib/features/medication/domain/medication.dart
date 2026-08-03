import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String patientId;
  final String name;
  final String dosage;
  final String instruction;
  final String scheduledTime;
  final String iconType; // 'pill' | 'bottle' | 'injection'
  final DateTime createdAt;
  final bool isActive;

  const Medication({
    required this.id,
    required this.patientId,
    required this.name,
    required this.dosage,
    required this.instruction,
    required this.scheduledTime,
    this.iconType = 'pill',
    required this.createdAt,
    this.isActive = true,
  });

  factory Medication.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseCreatedAt(dynamic val) {
      if (val is Timestamp) {
        return val.toDate();
      }
      return DateTime.now();
    }

    return Medication(
      id: id,
      patientId: map['patientId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      instruction: map['instruction'] as String? ?? '',
      scheduledTime: map['scheduledTime'] as String? ?? '08:00 AM',
      iconType: map['iconType'] as String? ?? 'pill',
      createdAt: parseCreatedAt(map['createdAt']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'name': name,
      'dosage': dosage,
      'instruction': instruction,
      'scheduledTime': scheduledTime,
      'iconType': iconType,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
