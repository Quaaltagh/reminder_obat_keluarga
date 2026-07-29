// Provider untuk layar Invite (Patient + Caregiver, satu kode circle
// yang sama). Tidak menambah method baru di CareCircleRepository —
// hanya membungkus getCircle()/regenerateInviteCode() yang sudah ada
// jadi reaktif via stream, supaya InviteScreen otomatis ter-refresh
// begitu Admin menekan "Buat Ulang Kode" tanpa perlu pop/push ulang
// layar atau refresh manual.
//
// Lokasi: lib/features/care_circle/presentation/providers/invite_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/care_circle_repository.dart';
import '../../domain/care_circle.dart';

part 'invite_provider.g.dart';

/// Stream reaktif dokumen careCircles/{circleId}, dipakai khusus di
/// InviteScreen supaya kode invite yang ditampilkan selalu sinkron
/// dengan Firestore — termasuk saat regenerate dari device lain
/// (misal 2 admin buka halaman ini di HP berbeda secara bersamaan).
///
/// CareCircleRepository sengaja tidak diubah (masih pakai getCircle()
/// yang Future-based untuk pemakaian lain yang memang tidak butuh
/// reaktif) — stream ini dibuat di layer provider saja.
@riverpod
Stream<CareCircle?> watchCareCircle(Ref ref, String circleId) {
  return FirebaseFirestore.instance
      .collection('careCircles')
      .doc(circleId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return CareCircle.fromMap(doc.id, doc.data()!);
  });
}

/// Action provider: bungkus regenerateInviteCode() dari repository
/// supaya screen tidak perlu ref.read(careCircleRepositoryProvider)
/// langsung — konsisten dengan pola OnboardingService di fitur lain.
@riverpod
class InviteActions extends _$InviteActions {
  @override
  void build() {}

  Future<void> regenerateCode(String circleId) async {
    final repo = ref.read(careCircleRepositoryProvider);
    await repo.regenerateInviteCode(circleId);
  }
}