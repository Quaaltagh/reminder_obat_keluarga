// Layar "Approval Join Request" — daftar permintaan bergabung yang
// masih pending, dengan aksi Approve (pilih jadi Pasien baru ATAU
// Caregiver dengan role Editor/Viewer) atau Reject.
//
// Dibuka dari ikon lonceng di FamilyListScreen.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Permintaan Bergabung')),
      body: StreamBuilder<List<JoinRequest>>(
        stream: repo.watchPendingJoinRequests(circleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tidak ada permintaan bergabung yang menunggu saat ini.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              return _JoinRequestTile(
                request: request,
                onApprove: () => _showApproveDialog(context, ref, request),
                onReject: () => _handleReject(context, ref, request),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleReject(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tolak Permintaan?'),
        content: Text('${request.displayName} tidak akan bisa bergabung ke circle ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
        SnackBar(content: Text('${request.displayName} ditolak')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak: $e')),
      );
    }
  }

  Future<void> _showApproveDialog(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ApproveBottomSheet(
        circleId: circleId,
        adminUserId: adminUserId,
        request: request,
      ),
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            request.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onApprove,
                  child: const Text('Setujui'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet muncul saat Admin menekan "Setujui": pilih apakah orang
/// ini jadi Pasien baru atau Caregiver, lalu isi detail sesuai pilihan.
class _ApproveBottomSheet extends ConsumerStatefulWidget {
  const _ApproveBottomSheet({
    required this.circleId,
    required this.adminUserId,
    required this.request,
  });

  final String circleId;
  final String adminUserId;
  final JoinRequest request;

  @override
  ConsumerState<_ApproveBottomSheet> createState() => _ApproveBottomSheetState();
}

enum _ApproveAs { newPatient, caregiver }

class _ApproveBottomSheetState extends ConsumerState<_ApproveBottomSheet> {
  _ApproveAs _approveAs = _ApproveAs.caregiver;
  CaregiverRole _selectedRole = CaregiverRole.viewer;

  final _patientNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_approveAs == _ApproveAs.newPatient && _patientNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama pasien wajib diisi')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final actions = ref.read(circleManagementActionsProvider.notifier);

      if (_approveAs == _ApproveAs.newPatient) {
        await actions.approveAsNewPatient(
          circleId: widget.circleId,
          userId: widget.request.userId,
          adminUserId: widget.adminUserId,
          patientName: _patientNameController.text.trim(),
          age: int.tryParse(_ageController.text.trim()),
          healthConditionNotes:
              _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
      } else {
        await actions.approveAsCaregiver(
          circleId: widget.circleId,
          userId: widget.request.userId,
          adminUserId: widget.adminUserId,
          role: _selectedRole,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.request.displayName} berhasil ditambahkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyetujui: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Setujui ${widget.request.displayName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tentukan peran orang ini di dalam Care Circle.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            SegmentedButton<_ApproveAs>(
              segments: const [
                ButtonSegment(
                  value: _ApproveAs.caregiver,
                  label: Text('Jadi Caregiver'),
                  icon: Icon(Icons.people_outline_rounded),
                ),
                ButtonSegment(
                  value: _ApproveAs.newPatient,
                  label: Text('Pasien Baru'),
                  icon: Icon(Icons.personal_injury_outlined),
                ),
              ],
              selected: {_approveAs},
              onSelectionChanged: (selection) {
                setState(() => _approveAs = selection.first);
              },
            ),
            const SizedBox(height: 20),

            if (_approveAs == _ApproveAs.caregiver) ...[
              Text('Tingkat Akses', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioListTile<CaregiverRole>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Input Member'),
                subtitle: const Text('Bisa mencatat konsumsi obat & menambah obat baru'),
                value: CaregiverRole.editor,
                groupValue: _selectedRole,
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
              RadioListTile<CaregiverRole>(
                contentPadding: EdgeInsets.zero,
                title: const Text('View Only'),
                subtitle: const Text('Hanya bisa melihat jadwal, tidak bisa mengubah'),
                value: CaregiverRole.viewer,
                groupValue: _selectedRole,
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
            ] else ...[
              TextField(
                controller: _patientNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pasien',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Usia (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan Kondisi Kesehatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Setujui & Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}