// Dashboard utama: card ringkasan per pasien (scroll vertikal) + section aktivitas terbaru.
// Sesuai keputusan: dashboard GABUNGAN, bukan single-patient switcher.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

/// Dashboard utama — TAHAP INI baru versi dasar untuk memastikan alur
/// splash -> login -> dashboard berfungsi end-to-end.
///
/// TODO (tahap berikutnya): ganti body ini dengan dashboard gabungan
/// multi-pasien (card per patientProfile aktif) sesuai desain yang
/// sudah dirancang — butuh patient_list_provider.dart dan
/// patient_summary_card.dart terlebih dahulu.
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
              // Tidak perlu navigasi manual — redirect logic di
              // app_router.dart otomatis mendeteksi authState berubah
              // jadi null dan mengarahkan balik ke /login.
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
            ],
          ),
        ),
      ),
    );
  }
}