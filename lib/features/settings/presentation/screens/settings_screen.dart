import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/data/user_repository.dart';
import '../../../care_circle/presentation/providers/circle_management_provider.dart';
import '../../../care_circle/presentation/screens/join_requests_screen.dart';

/// Halaman "Account Settings" — Sesuai Desain Mockup Account Settings.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final appUserAsync = ref.watch(watchAppUserProvider(user.uid));
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: appUserAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
          data: (appUser) {
            final circleId = (appUser != null && appUser.circleIds.isNotEmpty)
                ? appUser.circleIds.first
                : null;

            final pendingCountAsync = circleId != null
                ? ref.watch(watchPendingJoinRequestCountProvider(circleId))
                : const AsyncValue<int>.data(0);

            final membersAsync = circleId != null
                ? ref.watch(watchFamilyMembersProvider(circleId))
                : const AsyncValue<List<FamilyMemberDisplay>>.data([]);

            final isCurrentAdmin = membersAsync.value?.any((m) => m.userId == user.uid && m.isAdmin) ?? false;

            final displayName = (appUser?.displayName != null && appUser!.displayName.isNotEmpty)
                ? appUser.displayName
                : (user.displayName != null && user.displayName!.isNotEmpty
                    ? user.displayName!
                    : (user.email != null ? user.email!.split('@').first : 'User Profile'));

            final email = user.email ?? appUser?.email ?? 'user@email.com';

            return Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // User Profile Picture Avatar Button
                      GestureDetector(
                        onTap: () {}, // Already on settings
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Obat Keluarga',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryBlue,
                            ),
                      ),
                      const Spacer(),

                      // Bell Notification Button (Khusus Admin)
                      if (isCurrentAdmin)
                        _NotificationBellButton(
                          pendingCount: pendingCountAsync.value ?? 0,
                          onTap: () {
                            if (circleId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JoinRequestsScreen(
                                    circleId: circleId,
                                    adminUserId: user.uid,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        // Profile Picture Card + Edit Pencil Badge
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFDBEAFE),
                                child: Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name & Email
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 28),

                        // PREFERENCES Section
                        _SectionHeader(title: 'PREFERENCES'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Notifications Switch (Khusus Admin)
                              if (isCurrentAdmin) ...[
                                ListTile(
                                  leading: const Icon(Icons.notifications_none_outlined, color: Color(0xFF334155)),
                                  title: const Text(
                                    'Notifications',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  trailing: Switch.adaptive(
                                    value: _notificationsEnabled,
                                    activeTrackColor: const Color(0xFF2563EB),
                                    onChanged: (val) {
                                      setState(() {
                                        _notificationsEnabled = val;
                                      });
                                    },
                                  ),
                                ),
                                const Divider(height: 1, indent: 16, endIndent: 16),
                              ],
                              // Language Selector
                              ListTile(
                                leading: const Icon(Icons.language_outlined, color: Color(0xFF334155)),
                                title: const Text(
                                  'Language',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _selectedLanguage,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                                  ],
                                ),
                                onTap: () => _showLanguageDialog(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ACCOUNT Section
                        _SectionHeader(title: 'ACCOUNT'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF334155)),
                                title: const Text(
                                  'Edit Profile',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Edit profil akan tersedia di pembaruan berikutnya')),
                                  );
                                },
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              ListTile(
                                leading: const Icon(Icons.lock_outline_rounded, color: Color(0xFF334155)),
                                title: const Text(
                                  'Change Password',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Ubah kata sandi dapat dilakukan melalui email reset')),
                                  );
                                },
                              ),
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              ListTile(
                                leading: const Icon(Icons.shield_outlined, color: Color(0xFF334155)),
                                title: const Text(
                                  'Privacy Policy',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Kebijakan Privasi Obat Keluarga')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Logout Button (Soft Red)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: () => _handleLogout(context),
                            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFEE2E2),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // App Version Text
                        const Text(
                          'App Version 2.4.0 (Build 82)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      bottomNavigationBar: _SettingsBottomNavBar(
        selectedIndex: 4,
        onTabSelected: (index) {
          if (index != 4) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, index);
            } else {
              context.go('/dashboard');
            }
          }
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Pilih Bahasa'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedLanguage = 'English');
              Navigator.pop(dialogContext);
            },
            child: const Text('English'),
          ),
          SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedLanguage = 'Bahasa Indonesia');
              Navigator.pop(dialogContext);
            },
            child: const Text('Bahasa Indonesia'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari Akun?'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi Obat Keluarga?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
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

class _SettingsBottomNavBar extends StatelessWidget {
  const _SettingsBottomNavBar({
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
      const _SettingsNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _SettingsNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Schedule'),
      const _SettingsNavItem(icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, label: 'Family'),
      const _SettingsNavItem(icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services, label: 'Medicine'),
      const _SettingsNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
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

class _SettingsNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _SettingsNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
