// Dashboard utama: card ringkasan per pasien (scroll vertikal) + section aktivitas terbaru.
// Sesuai keputusan: dashboard GABUNGAN, bukan single-patient switcher.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../../care_circle/presentation/screens/family_list_screen.dart';
import '../../../care_circle/presentation/screens/invite_screen.dart';

/// Dashboard utama — TAHAP INI baru versi dasar untuk memastikan alur
/// splash -> login -> dashboard berfungsi end-to-end.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Care Circle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle,
                  size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Selamat datang${user?.email != null ? ',\n${user!.email}' : ''}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Alur login berhasil.\nDashboard gabungan multi-pasien '
                'akan dibangun di tahap berikutnya.',
                textAlign: TextAlign.center,
              ),

              // ================================================
              // 🧪 BLOK SEMENTARA UNTUK TES MANUAL — HAPUS SETELAH
              // FamilyListScreen/InviteScreen punya jalur navigasi
              // permanen (misal lewat bottom nav "Family").
              // ================================================
              if (user != null) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  '🧪 Area Tes Sementara',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 12),
                _DebugTestButtons(uid: user.uid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget terpisah supaya bisa watch watchAppUserProvider(uid) sendiri
/// tanpa bikin build() utama di atas jadi kepanjangan.
class _DebugTestButtons extends ConsumerWidget {
  const _DebugTestButtons({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(watchAppUserProvider(uid));

    return appUserAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Gagal load AppUser: $e'),
      data: (appUser) {
        if (appUser == null) {
          return const Text('Dokumen users/{uid} belum ada di Firestore.');
        }
        if (appUser.circleIds.isEmpty) {
          return const Text(
            'User ini belum punya circleId — selesaikan alur '
            'Onboarding (Create Circle) dulu.',
            textAlign: TextAlign.center,
          );
        }

        // Asumsi versi ini: pakai circle PERTAMA saja untuk tes.
        final circleId = appUser.circleIds.first;

        return Column(
          children: [
            Text(
              'circleId: $circleId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyListScreen(
                    circleId: circleId,
                    currentUserId: uid,
                  ),
                ),
              ),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Buka Daftar Family'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InviteScreen(circleId: circleId),
                ),
              ),
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('Buka Invite Screen'),
            ),
          ],
        );
      },
    );
  }
}