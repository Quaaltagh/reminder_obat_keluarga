import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OnboardingChoiceScreen extends ConsumerStatefulWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  ConsumerState<OnboardingChoiceScreen> createState() =>
      _OnboardingChoiceScreenState();
}

class _OnboardingChoiceScreenState
    extends ConsumerState<OnboardingChoiceScreen> {
  bool _isCheckingApprovedJoin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSyncApprovedJoin();
    });
  }

  Future<void> _checkAndSyncApprovedJoin() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      if (mounted) setState(() => _isCheckingApprovedJoin = false);
      return;
    }

    try {
      final userRepo = ref.read(userRepositoryProvider);

      // 1. Pembersihan otomatis: Jika user punya circleId di profilnya tapi sudah dihapus dari members oleh Admin
      final appUser = await userRepo.getUser(currentUser.uid);
      if (appUser != null && appUser.circleIds.isNotEmpty) {
        for (final cid in List<String>.from(appUser.circleIds)) {
          final mDoc = await FirebaseFirestore.instance
              .collection('careCircles')
              .doc(cid)
              .collection('members')
              .doc(currentUser.uid)
              .get();
          if (!mDoc.exists) {
            debugPrint('🧹 [AUTO-CLEANUP] Menghapus circleId $cid dari profil user karena sudah dihapus Admin');
            await userRepo.removeCircleId(currentUser.uid, cid);
          }
        }
      }

      // 2. Cek apakah ada circle di mana user menjadi member resmi di subcollection members
      final circlesSnap = await FirebaseFirestore.instance.collection('careCircles').get();
      for (final circleDoc in circlesSnap.docs) {
        final circleId = circleDoc.id;

        final memberDoc = await circleDoc.reference.collection('members').doc(currentUser.uid).get();
        if (memberDoc.exists) {
          debugPrint('✅ [AUTO-SYNC] Ditemukan member aktif di circle: $circleId');
          await userRepo.addCircleId(currentUser.uid, circleId);
          if (mounted) context.go('/dashboard');
          return;
        } else {
          // Jika memberDoc tidak ada tapi ada sisa joinRequest lama, bersihkan agar tidak menyebabkan siklus pengulangan
          final reqDoc = await circleDoc.reference.collection('joinRequests').doc(currentUser.uid).get();
          if (reqDoc.exists) {
            debugPrint('🧹 [AUTO-CLEANUP] Menghapus sisa joinRequest lama untuk user ${currentUser.uid}');
            await reqDoc.reference.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AUTO-SYNC] Error checking approved join: $e');
    }

    if (mounted) {
      setState(() => _isCheckingApprovedJoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingApprovedJoin) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF1D68B4);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
            tooltip: 'Keluar / Logout',
            onPressed: () async {
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icon Medis Biru (Briefcase)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(height: 24),

              // 2. Judul & Subjudul
              Text(
                'Apa yang ingin kamu lakukan?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih langkah pertama untuk mulai mengelola kesehatan keluarga Anda bersama Obat Keluarga.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              // 3. Option Card 1: Buat Care Circle Baru
              _OnboardingOptionCard(
                icon: Icons.home_outlined,
                iconBgColor: const Color(0xFFEBF3FC),
                iconColor: primaryBlue,
                title: 'Buat Care Circle Baru',
                subtitle: 'Untuk keluarga yang baru mulai memantau kesehatan pasien',
                onTap: () => context.pushNamed('create-circle'),
              ),

              const SizedBox(height: 16),

              // 4. Option Card 2: Saya Punya Kode Undangan
              _OnboardingOptionCard(
                icon: Icons.vpn_key_outlined,
                iconBgColor: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF475569),
                title: 'Saya Punya Kode Undangan',
                subtitle: 'Untuk bergabung ke Care Circle yang sudah dibuat keluarga',
                onTap: () => context.pushNamed('join-circle'),
              ),

              const SizedBox(height: 28),

              // 5. Banner Ilustrasi Keluarga (Bottom Banner)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/family_illustration.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback ilustrasi jika asset belum siap
                      return Container(
                        height: 140,
                        color: const Color(0xFFE2E8F0),
                        child: const Center(
                          child: Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 6. Footer Bantuan
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Butuh bantuan? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Pusat Bantuan
                      },
                      child: const Text(
                        'Pusat Bantuan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OnboardingOptionCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}