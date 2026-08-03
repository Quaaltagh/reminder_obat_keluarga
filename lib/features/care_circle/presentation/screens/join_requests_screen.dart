// Layar "Approval Join Request" — daftar permintaan bergabung yang
// masih pending, dengan aksi Approve (pilih jadi Pasien baru ATAU
// Caregiver dengan role Editor/Viewer) atau Reject.
//
// Lokasi: lib/features/care_circle/presentation/screens/join_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/care_circle_repository.dart';
import '../../domain/join_request.dart';
import '../providers/circle_management_provider.dart';

class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({
    super.key,
    required this.circleId,
    required this.adminUserId,
  });

  final String circleId;
  final String adminUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(careCircleRepositoryProvider);
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Permintaan Bergabung',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<JoinRequest>>(
        stream: repo.watchPendingJoinRequests(circleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString();
            final isPermissionDenied = errorStr.contains('permission-denied');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 48, color: Colors.amber),
                    const SizedBox(height: 12),
                    Text(
                      isPermissionDenied
                          ? 'Izin Akses Firestore Ditolak'
                          : 'Gagal Memuat Permintaan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPermissionDenied
                          ? 'Pastikan aturan (Security Rules) sub-collection "joinRequests" di Firebase Console sudah diizinkan (allow read, write: if request.auth != null).'
                          : 'Error: $errorStr',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            );
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 48,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Permintaan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tidak ada permintaan bergabung yang menunggu persetujuan saat ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _JoinRequestTile(
                request: request,
                onApprove: () => _handleApprove(context, ref, request),
                onReject: () => _handleReject(context, ref, request),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    final targetRole = request.targetRole;
    String roleName = 'Anggota Input';
    if (targetRole == 'patient') roleName = 'Pasien';
    if (targetRole == 'viewer') roleName = 'View Only';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Setujui Permintaan?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Setujui ${request.displayName} untuk bergabung sebagai $roleName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final actions = ref.read(circleManagementActionsProvider.notifier);

      if (targetRole == 'patient') {
        await actions.approveAsNewPatient(
          circleId: circleId,
          userId: request.userId,
          adminUserId: adminUserId,
          patientName: request.displayName,
        );
      } else if (targetRole == 'viewer') {
        await actions.approveAsCaregiver(
          circleId: circleId,
          userId: request.userId,
          adminUserId: adminUserId,
          role: CaregiverRole.viewer,
        );
      } else {
        // default or 'editor'
        await actions.approveAsCaregiver(
          circleId: circleId,
          userId: request.userId,
          adminUserId: adminUserId,
          role: CaregiverRole.editor,
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.displayName} berhasil disetujui sebagai $roleName.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyetujui: $e')),
      );
    }
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tolak Permintaan?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${request.displayName} tidak akan bisa bergabung ke Care Circle ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(circleManagementActionsProvider.notifier)
          .reject(circleId: circleId, userId: request.userId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.displayName} telah ditolak.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak: $e')),
      );
    }
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final JoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);
    final initial = request.displayName.isNotEmpty ? request.displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: primaryBlue, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge Role Target
              if (request.targetRole != null)
                _TargetRoleBadge(targetRole: request.targetRole!),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons: [Tolak] [Setujui]
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TargetRoleBadge extends StatelessWidget {
  const _TargetRoleBadge({required this.targetRole});

  final String targetRole;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bgColor;
    final Color fgColor;

    if (targetRole == 'patient') {
      label = 'Pasien';
      bgColor = const Color(0xFFE0E7FF);
      fgColor = const Color(0xFF4338CA);
    } else if (targetRole == 'editor') {
      label = 'Anggota Input';
      bgColor = const Color(0xFFEFF6FF);
      fgColor = const Color(0xFF0F4C81);
    } else {
      label = 'View Only';
      bgColor = const Color(0xFFF1F5F9);
      fgColor = const Color(0xFF475569);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}