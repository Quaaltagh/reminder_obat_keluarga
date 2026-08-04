import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../care_circle/data/care_circle_repository.dart';
import '../../../care_circle/presentation/providers/circle_management_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';
import '../../../patient/data/patient_repository.dart';

/// Halaman "Pasang Perangkat Pasien" (Sesuai Gambar 3)
class PatientLinkDeviceScreen extends ConsumerStatefulWidget {
  const PatientLinkDeviceScreen({super.key});

  @override
  ConsumerState<PatientLinkDeviceScreen> createState() => _PatientLinkDeviceScreenState();
}

class _PatientLinkDeviceScreenState extends ConsumerState<PatientLinkDeviceScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleLinkDevice() async {
    final rawCode = _codeController.text.trim();
    if (rawCode.isEmpty) {
      setState(() => _errorMessage = 'Harap masukkan kode undangan dari aplikasi keluarga.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final patientRepo = ref.read(patientRepositoryProvider);
      final careCircleRepo = ref.read(careCircleRepositoryProvider);

      var currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        final anonCred = await authRepo.signInAnonymously();
        currentUser = anonCred.user;
        if (currentUser != null) {
          await userRepo.createUserDocument(
            uid: currentUser.uid,
            displayName: 'Pasien',
            email: '',
          );
        }
      }

      if (currentUser == null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Gagal menginisialisasi sesi pasien. Silakan coba lagi.';
        });
        return;
      }

      final appUser = await userRepo.getUser(currentUser.uid);
      final displayName = (appUser?.displayName != null && appUser!.displayName.isNotEmpty)
          ? appUser.displayName
          : 'Pasien';

      // 1. Submit join request menggunakan kode undangan (diizinkan oleh Firebase Security Rules)
      final onboardingService = ref.read(onboardingServiceProvider);
      final circleId = await onboardingService.submitJoinRequestByCode(
        inviteCode: rawCode,
        userId: currentUser.uid,
        displayName: displayName,
        email: currentUser.email ?? '',
      );

      // 2. Simpan mode perangkat ini sebagai "patient" secara permanen
      final deviceService = ref.read(deviceModeServiceProvider);
      await deviceService.setPatientMode(currentUser.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan pasang perangkat pasien terkirim! Menunggu persetujuan Admin.'),
            backgroundColor: Color(0xFF0F4C81),
          ),
        );
        context.go('/onboarding/waiting-approval?circleId=$circleId');
      }
    } catch (e) {
      debugPrint('🔴 [PATIENT-LINK] Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryBlue = Color(0xFF0F4C81);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pasang perangkat pasien',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Subtitle Text
              Text(
                'Minta anggota keluarga untuk memindai kode QR atau memasukkan kode manual untuk menghubungkan perangkat ini.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.45,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 28),

              // Card Scanner QR Visual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Visual QR Frame Box
                    Container(
                      width: 180,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 72,
                            color: primaryBlue.withValues(alpha: 0.4),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.crop_free_rounded, color: primaryBlue, size: 28),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Button Arahkan Kamera ke Kode QR
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pemindaian kamera diaktifkan. Atau gunakan kode manual di bawah.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 20, color: primaryBlue),
                      label: const Text(
                        'Arahkan Kamera ke Kode QR',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Divider "Atau"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Atau',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 24),

              // Section Masukkan Kode Manual
              const Text(
                'Masukkan Kode Manual',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),

              const SizedBox(height: 14),

              // Text Field Kode 6-Digit
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: primaryBlue,
                ),
                decoration: InputDecoration(
                  hintText: 'P - X X X X X X',
                  hintStyle: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.normal,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),

              Text(
                'Dapatkan kode dari aplikasi keluarga',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Button "✓ Pasang Perangkat Ini"
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleLinkDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.check_circle_outline_rounded, size: 22),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Pasang Perangkat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
