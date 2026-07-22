// Splash screen: init Firebase, cek auth state, cek circle membership.
// Lihat penjelasan detail 'apa yang dicek saat splash screen' di diskusi sebelumnya.

import 'package:flutter/material.dart';

/// Splash screen — tampil sebentar saat app pertama dibuka.
///
/// PENTING: Layar ini murni tampilan (visual only). Logika "mau redirect
/// ke mana setelah ini" TIDAK ditaruh di sini, melainkan di
/// core/router/app_router.dart lewat redirect logic go_router yang
/// mendengarkan authStateChangesProvider, isPatientModeDeviceProvider, dst.
///
/// Kenapa dipisah begini? Supaya splash screen tetap simpel (cuma render
/// UI) dan semua keputusan navigasi terpusat di satu tempat (router),
/// bukan tersebar di banyak screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB), // biru sangat muda, sesuai desain
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo card
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Obat Keluarga',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your family\'s trusted companion\nfor health & medication.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),

              const Spacer(flex: 4),

              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'INITIALIZING',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}