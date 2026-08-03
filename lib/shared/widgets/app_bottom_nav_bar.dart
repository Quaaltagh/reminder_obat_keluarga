import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/screens/settings_screen.dart';

/// AppBottomNavBar — Navigation Bar Universal Presisi Sesuai Gambar Mockup.
///
/// Tampilan:
/// - Background bar: Putih (Colors.white) dengan bayangan halus di atas.
/// - Item Aktif: Latar belakang kapsul/pill berwarna Biru Gelap (0xFF2B70C9),
///   dengan ikon & teks berwarna Putih.
/// - Item Non-aktif: Background transparan, ikon & teks berwarna abu-abu gelap.
/// - Posisi Tetap: Kelima item dibungkus dalam Expanded (lebar sama),
///   sehingga posisi masing-masing ikon TIDAK BERGESER saat tab berganti.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    this.circleId,
    this.currentUserId,
    this.onTabSelected,
  });

  final int selectedIndex;
  final String? circleId;
  final String? currentUserId;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    const activeBluePill = Color(0xFF0F4C81); // Biru tua khas tema utama
    const inactiveIconColor = Color(0xFF334155);
    const inactiveTextColor = Color(0xFF475569);

    final items = const [
      _NavItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      _NavItemData(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: 'Schedule',
      ),
      _NavItemData(
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt_rounded,
        label: 'Family',
      ),
      _NavItemData(
        icon: Icons.medical_services_outlined,
        activeIcon: Icons.medical_services_rounded,
        label: 'Medicine',
      ),
      _NavItemData(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () {
                      if (onTabSelected != null) {
                        onTabSelected!(index);
                        return;
                      }

                      _defaultNavigationHandler(context, index);
                    },
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _defaultNavigationHandler(BuildContext context, int index) {
    if (index == 4) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SettingsScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else if (index == 1) {
      context.go('/schedule');
    } else if (index == 2 || index == 0) {
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        context.go('/dashboard');
      }
    }
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
