// Layar "Daftar Family (Admin)" — sesuai desain Figma yang diberikan.
// Menampilkan semua member circle beserta role tampilannya (Admin /
// Input Member / View Only), tombol untuk mengundang anggota baru, dan
// ikon lonceng dengan badge jumlah join request yang masih pending.
//
// Lokasi: lib/features/care_circle/presentation/screens/family_list_screen.dart
//
// Cara membuka (contoh dari dashboard / bottom nav "Family"):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => FamilyListScreen(circleId: circle.circleId),
//   ));

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/circle_management_provider.dart';
import 'invite_screen.dart';
import 'join_requests_screen.dart';

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({
    super.key,
    required this.circleId,
    required this.currentUserId,
  });

  final String circleId;

  /// UID user yang sedang login — dipakai supaya Admin tidak bisa
  /// menghapus dirinya sendiri dari daftar (lihat _handleRemove).
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(watchFamilyMembersProvider(circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(circleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Family (Admin)'),
        actions: [
          _NotificationBell(
            pendingCount: pendingCountAsync.value ?? 0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JoinRequestsScreen(
                    circleId: circleId,
                    adminUserId: currentUserId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal memuat data keluarga: $error'),
          ),
        ),
        data: (members) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Family Circle',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kelola anggota dan tingkat akses pengingat obat.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InviteScreen(circleId: circleId),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Undang Anggota Baru'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              if (members.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Belum ada anggota lain di circle ini.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FamilyMemberTile(
                      member: member,
                      isSelf: member.userId == currentUserId,
                      onRemove: () => _handleRemove(context, ref, member),
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              _RoleInfoCard(theme: Theme.of(context)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleRemove(
    BuildContext context,
    WidgetRef ref,
    FamilyMemberDisplay member,
  ) async {
    if (member.userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamu tidak bisa menghapus dirimu sendiri.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: const Text(
          'Anggota ini akan kehilangan akses ke Care Circle. Data medis '
          'pasien yang sudah tercatat tidak akan terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(circleManagementActionsProvider.notifier).removeMember(
            circleId: circleId,
            userId: member.userId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anggota berhasil dihapus')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus anggota: $e')),
      );
    }
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.pendingCount, required this.onTap});

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: onTap,
        ),
        if (pendingCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, height: 1),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _FamilyMemberTile extends StatelessWidget {
  const _FamilyMemberTile({
    required this.member,
    required this.isSelf,
    required this.onRemove,
  });

  final FamilyMemberDisplay member;
  final bool isSelf;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Warna aksen kiri: biru untuk Admin, abu untuk lainnya — meniru
    // border kiri berwarna di desain Figma.
    final accentColor = member.isAdmin ? colorScheme.primary : colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              member.userId.isNotEmpty ? member.userId[0].toUpperCase() : '?',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        // Placeholder: idealnya nama diambil dari
                        // AppUser (users/{uid}.displayName), bukan
                        // userId mentah. Screen ini menerima
                        // FamilyMemberDisplay apa adanya dari provider;
                        // lihat catatan di bagian akhir jawaban.
                        member.userId,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(Kamu)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _RoleBadge(member: member),
              ],
            ),
          ),
          if (!isSelf)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: colorScheme.error,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.member});

  final FamilyMemberDisplay member;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Warna badge dibedakan sedikit: Admin lebih tegas (primary),
    // caregiver role dengan warna netral (secondary container).
    final Color bgColor;
    final Color fgColor;
    if (member.isAdmin) {
      bgColor = colorScheme.primaryContainer;
      fgColor = colorScheme.onPrimaryContainer;
    } else if (member.caregiverRole == CaregiverRole.editor) {
      bgColor = colorScheme.secondaryContainer;
      fgColor = colorScheme.onSecondaryContainer;
    } else {
      bgColor = colorScheme.surfaceContainerHighest;
      fgColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(
        member.roleLabel,
        style: TextStyle(color: fgColor, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _RoleInfoCard extends StatelessWidget {
  const _RoleInfoCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primaryContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Role Access Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: const [
                TextSpan(text: 'Admin ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'dapat mengubah jadwal dan mengelola anggota. '),
                TextSpan(text: 'Input Member ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'dapat mencatat konsumsi obat dan menambah obat baru. '),
                TextSpan(text: 'View Only ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: 'hanya dapat melihat jadwal tanpa mengubah apa pun.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}