// Form buat Care Circle baru + Patient Profile pertama.
// Layar alur Admin: "Buat Care Circle Baru" -> "Create Patient Profile".
// Digabung jadi 1 screen dengan 2 langkah (PageView), karena keduanya
// bagian dari satu alur onboarding yang berurutan sesuai desain Figma.
//
// Langkah 1: input nama Care Circle (misal "Keluarga Santoso")
// Langkah 2: form Create Patient Profile (nama, usia, catatan kesehatan)
//
// Setelah kedua langkah selesai, panggil
// OnboardingService.createCircleAndPatientProfile() yang mengurus
// SEMUA write Firestore (circle, admin member, patient profile,
// update user.circleIds) dalam satu orkestrasi.

// ──────────────────────────────────────────────────────────────
// REDESIGN: mengikuti design system yang sama dengan screen lain
// (login_screen, invite_screen, family_list_screen):
//   • Background  : Color(0xFFF8FAFC)
//   • Primary     : Color(0xFF0F4C81)
//   • Card        : putih, radius 20, shadow halus
//   • TextField   : border radius 12, focused border biru 1.5px
//   • Button      : ElevatedButton biru, radius 14, tinggi 52px
// ──────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

const _primaryBlue = Color(0xFF0F4C81);
const _bgColor = Color(0xFFF8FAFC);

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() =>
      _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _pageController = PageController();
  final _circleNameController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _patientAgeController = TextEditingController();
  final _healthNotesController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    _circleNameController.dispose();
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _healthNotesController.dispose();
    super.dispose();
  }

  void _goToPatientStep() {
    if (_circleNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Nama Care Circle tidak boleh kosong.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _currentStep = 1;
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitAll() async {
    if (_patientNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Nama pasien tidak boleh kosong.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Ambil provider & data form sebelum await, mengikuti pola yang
    // sudah terbukti aman dari race condition di register_screen.dart
    // (baca komentar di sana untuk penjelasan lengkap kenapa ini penting
    // ketika ada kemungkinan redirect terjadi di tengah proses async).
    final onboardingService = ref.read(onboardingServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final adminUserId = currentUser?.uid;

    final circleName = _circleNameController.text.trim();
    final patientName = _patientNameController.text.trim();
    final ageText = _patientAgeController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    final healthNotes = _healthNotesController.text.trim().isEmpty
        ? null
        : _healthNotesController.text.trim();

    if (adminUserId == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    try {
      debugPrint('🔵 [ONBOARDING] Membuat circle + patient profile...');
      await onboardingService.createCircleAndPatientProfile(
        adminUserId: adminUserId,
        circleName: circleName,
        patientName: patientName,
        patientAge: age,
        healthConditionNotes: healthNotes,
      );
      debugPrint('✅ [ONBOARDING] Circle + patient profile berhasil dibuat.');

      // Redirect ke dashboard ditangani otomatis oleh app_router.dart
      // (nanti setelah poin 6: cek circle membership di redirect logic).
      // Untuk sekarang, redirect manual dulu supaya alur tetap jalan.
      if (mounted) context.goNamed('dashboard');
    } catch (e, stackTrace) {
      debugPrint('🔴 [ONBOARDING] Gagal: $e');
      debugPrint('🔴 [ONBOARDING] StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal membuat Care Circle. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryBlue),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _currentStep == 0 ? 'Buat Care Circle' : 'Profil Pasien',
          style: const TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFE2E8F0),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _currentStep == 0 ? 0.5 : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _primaryBlue,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CircleNameStep(
              controller: _circleNameController,
              errorMessage: _currentStep == 0 ? _errorMessage : null,
              onContinue: _goToPatientStep,
            ),
            _PatientProfileStep(
              nameController: _patientNameController,
              ageController: _patientAgeController,
              healthNotesController: _healthNotesController,
              errorMessage: _currentStep == 1 ? _errorMessage : null,
              isSubmitting: _isSubmitting,
              onSubmit: _submitAll,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleNameStep extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;
  final VoidCallback onContinue;

  const _CircleNameStep({
    required this.controller,
    required this.errorMessage,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 38,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Subtitle
          const Text(
            'Beri nama Care Circle Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contoh: "Keluarga Santoso". Nama ini akan terlihat oleh semua anggota yang bergabung.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // White Card Form
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nama Care Circle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Keluarga Santoso',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.groups_outlined, color: Color(0xFF64748B), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 15, color: Colors.red),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Lanjut Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Lanjut',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatientProfileStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController healthNotesController;
  final String? errorMessage;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _PatientProfileStep({
    required this.nameController,
    required this.ageController,
    required this.healthNotesController,
    required this.errorMessage,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Icon
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 38,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Subtitle
          const Text(
            'Profil Pasien',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informasi ini membantu menyesuaikan pengingat obat dan jadwal perawatan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // White Card Form
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nama Pasien
                const Text(
                  'Nama Pasien',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Masukkan nama lengkap',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Usia
                const Text(
                  'Usia',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'cth. 72',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.cake_outlined, color: Color(0xFF64748B), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Catatan Kondisi Kesehatan
                const Text(
                  'Catatan Kondisi Kesehatan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: healthNotesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Sebutkan kondisi kronis, alergi, atau kebutuhan perawatan khusus...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 15, color: Colors.red),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Info Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1D4ED8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Informasi ini akan terlihat oleh caregiver yang ada di grup keluarga untuk memastikan perawatan yang terkoordinasi.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Continue Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 1,
                disabledBackgroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Selesai & Buka Dashboard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}