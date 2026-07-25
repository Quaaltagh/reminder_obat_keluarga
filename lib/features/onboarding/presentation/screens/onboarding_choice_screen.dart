// Pilihan: 'Buat Care Circle Baru' atau 'Gabung via Kode Undangan'.
// Layar pertama alur onboarding, sesuai desain Figma:
// "Choose Admin or Member" — pilihan "Buat Care Circle Baru" (Admin)
// vs "Saya Punya Kode Undangan" (Member).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingChoiceScreen extends StatelessWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medical_services_outlined,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 24),
              Text(
                'Apa yang ingin kamu lakukan?',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih langkah pertama untuk mulai mengelola kesehatan '
                'keluarga Anda bersama Obat Keluarga.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              _OnboardingOptionCard(
                icon: Icons.home_outlined,
                title: 'Buat Care Circle Baru',
                subtitle: 'Untuk keluarga yang baru mulai memantau '
                    'kesehatan pasien',
                onTap: () => context.pushNamed('create-circle'),
              ),
              const SizedBox(height: 16),
              _OnboardingOptionCard(
                icon: Icons.vpn_key_outlined,
                title: 'Saya Punya Kode Undangan',
                subtitle: 'Untuk bergabung ke Care Circle yang sudah '
                    'dibuat keluarga',
                onTap: () => context.pushNamed('join-circle'),
              ),

              const Spacer(),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Butuh bantuan? ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                    children: [
                      TextSpan(
                        text: 'Pusat Bantuan',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OnboardingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}