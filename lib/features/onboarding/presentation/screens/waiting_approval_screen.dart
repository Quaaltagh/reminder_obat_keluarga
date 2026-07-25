// Layar BARU (belum ada di desain Figma yang ditunjukkan) — dibutuhkan
// karena keputusan alur join "butuh approval Admin dulu" (bukan
// auto-join). Layar ini menampilkan status "menunggu persetujuan" dan
// otomatis pindah begitu Admin approve/reject, lewat
// watchJoinRequestStatusProvider (stream real-time ke Firestore).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../care_circle/domain/join_request.dart';
import '../providers/onboarding_provider.dart';

class WaitingApprovalScreen extends ConsumerStatefulWidget {
  final String circleId;

  const WaitingApprovalScreen({super.key, required this.circleId});

  @override
  ConsumerState<WaitingApprovalScreen> createState() =>
      _WaitingApprovalScreenState();
}

class _WaitingApprovalScreenState
    extends ConsumerState<WaitingApprovalScreen> {
  bool _isFinalizing = false;

  Future<void> _handleApproved(String userId) async {
    if (_isFinalizing) return; // cegah double-trigger dari stream
    setState(() => _isFinalizing = true);

    final onboardingService = ref.read(onboardingServiceProvider);
    try {
      await onboardingService.finalizeApprovedJoin(
        userId: userId,
        circleId: widget.circleId,
      );
      debugPrint('✅ [JOIN] Approved & finalized untuk circle: ${widget.circleId}');
      if (mounted) context.goNamed('dashboard');
    } catch (e) {
      debugPrint('🔴 [JOIN] Gagal finalize setelah approved: $e');
      // Tetap di layar ini; stream akan tetap menunjukkan status
      // approved, user bisa coba lagi atau hubungi admin kalau stuck.
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final userId = currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sesi login tidak ditemukan.')),
      );
    }

    final joinRequestAsync = ref.watch(
      watchJoinRequestStatusProvider(circleId: widget.circleId, userId: userId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: joinRequestAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text(
                'Gagal memuat status permintaan.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              data: (joinRequest) {
                if (joinRequest == null) {
                  return Text(
                    'Permintaan tidak ditemukan.',
                    style: theme.textTheme.bodyMedium,
                  );
                }

                switch (joinRequest.status) {
                  case JoinRequestStatus.pending:
                    return _PendingView(circleId: widget.circleId);
                  case JoinRequestStatus.approved:
                    // Trigger finalize sekali saat status jadi approved.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _handleApproved(userId);
                    });
                    return const _ApprovedView();
                  case JoinRequestStatus.rejected:
                    return const _RejectedView();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  final String circleId;

  const _PendingView({required this.circleId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 24),
        Text(
          'Menunggu Persetujuan',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Permintaan bergabungmu sudah terkirim. Admin Care Circle '
          'perlu menyetujui sebelum kamu bisa mengakses data keluarga.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _ApprovedView extends StatelessWidget {
  const _ApprovedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade600, size: 56),
        const SizedBox(height: 24),
        Text(
          'Disetujui!',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Mengarahkan ke dashboard...'),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cancel_outlined, color: theme.colorScheme.error, size: 56),
        const SizedBox(height: 24),
        Text(
          'Permintaan Ditolak',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Admin Care Circle menolak permintaan bergabungmu. Hubungi '
          'admin untuk info lebih lanjut, atau coba kode lain.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => context.goNamed('onboarding-choice'),
          child: const Text('Kembali'),
        ),
      ],
    );
  }
}