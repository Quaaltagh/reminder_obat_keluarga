import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../care_circle/data/care_circle_repository.dart';
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
    if (_isFinalizing) return;
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => context.goNamed('onboarding-choice'),
        ),
        title: const Text(
          'Status Permintaan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: joinRequestAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Text(
                'Gagal memuat status permintaan.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            data: (joinRequest) {
              if (joinRequest == null) {
                return _NoRequestView(circleId: widget.circleId, userId: userId);
              }

              switch (joinRequest.status) {
                case JoinRequestStatus.pending:
                  return _PendingView(circleId: widget.circleId, userId: userId);
                case JoinRequestStatus.approved:
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
    );
  }
}

class _PendingView extends ConsumerStatefulWidget {
  final String circleId;
  final String userId;

  const _PendingView({required this.circleId, required this.userId});

  @override
  ConsumerState<_PendingView> createState() => _PendingViewState();
}

class _PendingViewState extends ConsumerState<_PendingView> {
  bool _isCancelling = false;

  Future<void> _cancelRequest() async {
    setState(() => _isCancelling = true);
    try {
      final repo = ref.read(careCircleRepositoryProvider);
      await repo.cancelJoinRequest(circleId: widget.circleId, userId: widget.userId);
      if (mounted) {
        context.goNamed('onboarding-choice');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan permintaan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Status Card Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Icon Badge Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 48,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Menunggu Persetujuan Admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              // Status Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Status: Pending',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Friendly explanation
              const Text(
                'Permintaan bergabung Anda sudah berhasil terkirim. Admin Care Circle perlu menyetujui sebelum Anda bisa mengakses data obat keluarga.\n\n'
                '💡 Anda tidak wajib menunggu di halaman ini. Begitu Admin menyetujui, akun Anda akan otomatis diaktifkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Action 1: Back to Onboarding Choice
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => context.goNamed('onboarding-choice'),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            label: const Text('Kembali ke Menu Utama', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Action 2: Cancel Join Request & try another code
        TextButton(
          onPressed: _isCancelling ? null : _cancelRequest,
          child: _isCancelling
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Batalkan Permintaan & Coba Kode Lain',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoRequestView extends StatelessWidget {
  final String circleId;
  final String userId;

  const _NoRequestView({required this.circleId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 56, color: Color(0xFF94A3B8)),
        const SizedBox(height: 16),
        const Text(
          'Permintaan Tidak Ditemukan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Permintaan bergabung Anda tidak ditemukan atau sudah dibatalkan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.goNamed('onboarding-choice'),
          child: const Text('Kembali ke Menu Utama'),
        ),
      ],
    );
  }
}

class _ApprovedView extends StatelessWidget {
  const _ApprovedView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 64),
        const SizedBox(height: 20),
        const Text(
          'Permintaan Disetujui!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text('Selamat datang! Mengarahkan Anda ke Dashboard...'),
      ],
    );
  }
}

class _RejectedView extends StatelessWidget {
  const _RejectedView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 64),
        const SizedBox(height: 20),
        const Text(
          'Permintaan Ditolak',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Admin Care Circle menolak permintaan bergabung Anda. Silakan hubungi Admin atau gunakan kode lainnya.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), height: 1.4),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.goNamed('onboarding-choice'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F4C81),
            foregroundColor: Colors.white,
          ),
          child: const Text('Kembali ke Menu Utama'),
        ),
      ],
    );
  }
}