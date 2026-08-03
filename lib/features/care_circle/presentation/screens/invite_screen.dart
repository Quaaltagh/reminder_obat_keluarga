import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/invite_provider.dart';
import '../providers/circle_management_provider.dart';
import 'join_requests_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

/// Layar "Invite Screen" — Sesuai Desain "Invite Patient" dan "Invite Caregiver".
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.circleId});

  final String circleId;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  int _mainTabIndex = 0; // 0 = Patient (Default), 1 = Family Member (Caregiver)
  int _subRoleIndex = 0; // 0 = Anggota Input, 1 = View Only
  int _bottomNavIndex = 2; // Tab aktif: "Family" (index 2)

  Future<void> _handleCopy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode undangan berhasil disalin ke clipboard!'),
        backgroundColor: Color(0xFF0F4C81),
      ),
    );
  }

  Future<void> _handleShareLink(String code, String circleName) async {
    final roleText = _mainTabIndex == 0
        ? 'Pasien'
        : (_subRoleIndex == 0 ? 'Anggota Input' : 'View Only');

    await SharePlus.instance.share(
      ShareParams(
        text: 'Gabung ke Care Circle "$circleName" sebagai $roleText di aplikasi Obat Keluarga. '
            'Gunakan kode undangan ini: $code',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(watchCareCircleProvider(widget.circleId));
    final pendingCountAsync = ref.watch(watchPendingJoinRequestCountProvider(widget.circleId));
    final user = ref.watch(currentUserProvider);
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0F4C81)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Obat Keluarga',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                  ),
                  const Spacer(),

                  // User Profile Picture Avatar Button (Directs to Settings)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0xFFDBEAFE),
                      child: Icon(Icons.person, color: Color(0xFF0F4C81), size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _NotificationBellButton(
                    pendingCount: pendingCountAsync.value ?? 0,
                    onTap: () {
                      if (user != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JoinRequestsScreen(
                              circleId: widget.circleId,
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
              child: circleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Gagal memuat data circle: $error'),
                  ),
                ),
                data: (circle) {
                  if (circle == null) {
                    return const Center(child: Text('Care Circle tidak ditemukan.'));
                  }

                  final baseCode = circle.inviteCode;
                  final roleCode = _getRoleCode(baseCode);
                  final formattedCode = _formatCode(roleCode);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        // Main Segmented Control: [Patient | Family Member]
                        _MainTabToggle(
                          selectedIndex: _mainTabIndex,
                          onTabSelected: (index) {
                            setState(() {
                              _mainTabIndex = index;
                            });
                          },
                        ),

                        const SizedBox(height: 20),

                        // Section Title & Subtitle
                        const Text(
                          'Set Up Patient Device',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scan this code on the patient\'s device to link their profile and enable medication reminders.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),

                        // Sub-Segmented Control (Hanya Tampil Jika Tab "Family Member" (index 1) Aktif)
                        if (_mainTabIndex == 1) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Pilih Peran Anggota',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SubRoleToggle(
                            selectedIndex: _subRoleIndex,
                            onRoleSelected: (index) {
                              setState(() {
                                _subRoleIndex = index;
                              });
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Unique Family Code Box Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'UNIQUE FAMILY CODE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Dashed / Dotted Code Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    formattedCode,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F4C81),
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Copy Code Action Button
                              InkWell(
                                onTap: () => _handleCopy(roleCode),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0F4C81)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Copy Code',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F4C81),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // QR Code Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 2,
                                  ),
                                ),
                                child: QrImageView(
                                  data: roleCode,
                                  size: 180,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Or scan this QR code directly',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Copy Invite Link Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => _handleShareLink(roleCode, circle.name),
                            icon: const Icon(Icons.link_rounded, size: 20),
                            label: const Text(
                              'Copy Invite Link',
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

                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: _InviteBottomNavBar(
        selectedIndex: _bottomNavIndex,
        onTabSelected: (index) {
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          } else {
            setState(() => _bottomNavIndex = index);
          }
        },
      ),
    );
  }

  String _getRoleCode(String baseCode) {
    final clean = baseCode.replaceAll(' ', '').toUpperCase();
    if (_mainTabIndex == 0) {
      return 'P-$clean';
    } else if (_subRoleIndex == 0) {
      return 'I-$clean';
    } else {
      return 'V-$clean';
    }
  }

  String _formatCode(String roleCode) {
    if (roleCode.isEmpty) return 'P - ------';
    if (roleCode.contains('-')) {
      final parts = roleCode.split('-');
      final prefix = parts[0];
      final code = parts[1];
      if (code.length == 6) {
        return '$prefix - ${code.substring(0, 3)} ${code.substring(3)}';
      }
      return '$prefix - $code';
    }
    return roleCode;
  }
}

class _MainTabToggle extends StatelessWidget {
  const _MainTabToggle({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);

    return Container(
      width: double.infinity,
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Patient',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selectedIndex == 0 ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabSelected(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Family Member',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selectedIndex == 1 ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubRoleToggle extends StatelessWidget {
  const _SubRoleToggle({
    required this.selectedIndex,
    required this.onRoleSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0F4C81);

    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onRoleSelected(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Anggota Input',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selectedIndex == 0 ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onRoleSelected(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'View Only',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: selectedIndex == 1 ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteBottomNavBar extends StatelessWidget {
  const _InviteBottomNavBar({
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
      const _InviteNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _InviteNavItem(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Schedule'),
      const _InviteNavItem(icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, label: 'Family'),
      const _InviteNavItem(icon: Icons.medical_services_outlined, activeIcon: Icons.medical_services, label: 'Medicine'),
      const _InviteNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
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

class _InviteNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _InviteNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
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