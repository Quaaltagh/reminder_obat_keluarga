import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/circle_management_provider.dart';
import 'invite_screen.dart';
import 'join_requests_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Layar "Daftar Family (Admin)" — Presisi Sesuai Gambar 2.
class FamilyListScreen extends ConsumerStatefulWidget {
  const FamilyListScreen({
    super.key,
    required this.circleId,
    required this.currentUserId,
  });

  final String circleId;
  final String currentUserId;

  @override
  ConsumerState<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends ConsumerState<FamilyListScreen> {
  int _selectedIndex = 2; // Default active tab: "Family" (index 2)

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(watchFamilyMembersProvider(widget.circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(widget.circleId));

    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // User Profile Picture Avatar Button (Directs to Settings)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const SettingsScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 19,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.person, color: Color(0xFF0F4C81), size: 22),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Obat Keluarga',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F4C81),
                    ),
                  ),
                  const Spacer(),
                  _NotificationBellButton(
                    pendingCount: pendingCountAsync.value ?? 0,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JoinRequestsScreen(
                            circleId: widget.circleId,
                            adminUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(watchFamilyMembersProvider(widget.circleId));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Circle',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage members and medication access levels.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InviteScreen(circleId: widget.circleId),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 22),
                          label: const Text(
                            'Invite New Member',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBlue,
                            side: const BorderSide(color: primaryBlue, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      membersAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Gagal memuat anggota: $e'),
                        ),
                        data: (members) {
                          if (members.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Belum ada anggota di circle ini.',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: members.map((member) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _FamilyMemberTileCard(
                                  member: member,
                                  isSelf: member.userId == widget.currentUserId,
                                  onRemove: () => _handleRemove(context, ref, member),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      const _RoleInfoBox(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: _BottomNavBarPill(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
      ),
    );
  }

  Future<void> _handleRemove(
    BuildContext context,
    WidgetRef ref,
    FamilyMemberDisplay member,
  ) async {
    if (member.userId == widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamu tidak bisa menghapus dirimu sendiri.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: Text(
          'Apakah kamu yakin ingin menghapus ${member.displayName} dari Care Circle?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
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
            circleId: widget.circleId,
            userId: member.userId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anggota berhasil dihapus.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus anggota: $e')),
      );
    }
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF0F4C81),
            size: 26,
          ),
          onPressed: onTap,
        ),
        if (pendingCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _FamilyMemberTileCard extends StatelessWidget {
  const _FamilyMemberTileCard({
    required this.member,
    required this.isSelf,
    required this.onRemove,
  });

  final FamilyMemberDisplay member;
  final bool isSelf;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);
    final isDarkAccent = member.isAdmin;
    final accentBorderColor = isDarkAccent ? primaryBlue : const Color(0xFFCBD5E1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accentBorderColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE2E8F0),
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Color(0xFF0F4C81),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
                        member.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(Kamu)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _RoleBadge(roleLabel: member.roleLabel, isAdmin: member.isAdmin),
              ],
            ),
          ),
          if (!isSelf)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8)),
              onPressed: onRemove,
              tooltip: 'Hapus Anggota',
            ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.roleLabel,
    required this.isAdmin,
  });

  final String roleLabel;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isAdmin ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0);
    final Color fgColor = isAdmin ? const Color(0xFF1E40AF) : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        roleLabel,
        style: TextStyle(
          color: fgColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoleInfoBox extends StatelessWidget {
  const _RoleInfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
              SizedBox(width: 8),
              Text(
                'Role Access Information',
                style: TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.5),
              children: const [
                TextSpan(
                  text: 'Admins ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can edit schedules and manage members.\n'),
                TextSpan(
                  text: 'Input Members ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can log medication intake and add new medications.\n'),
                TextSpan(
                  text: 'View Only ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                TextSpan(text: 'can see the schedule but cannot make changes.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavBarPill extends StatelessWidget {
  const _BottomNavBarPill({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    const activeBluePill = Color(0xFF0F4C81);
    const inactiveIconColor = Color(0xFF334155);
    const inactiveTextColor = Color(0xFF475569);

    final items = [
      const _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _NavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Schedule'),
      const _NavItem(icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, label: 'Family'),
      const _NavItem(icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services, label: 'Medicine'),
      const _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == selectedIndex;

            return InkWell(
              onTap: () => onTabSelected(index),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? activeBluePill : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : inactiveIconColor,
                      size: 22,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : inactiveTextColor,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}