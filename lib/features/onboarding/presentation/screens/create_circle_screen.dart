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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
              _pageController.previousPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          _currentStep == 0 ? 'Buat Care Circle' : 'Create Patient Profile',
          style: const TextStyle(color: Colors.black87),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Beri nama Care Circle Anda',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Contoh: "Keluarga Santoso". Nama ini akan terlihat oleh '
            'semua anggota yang bergabung.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nama Care Circle',
              hintText: 'Keluarga Santoso',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(errorMessage!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Lanjut'),
            ),
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Setting up a profile helps us personalize medication '
            'reminders and care schedules.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),

          const Text('Patient Name', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter full name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Age', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 72',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Health Condition Notes',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: healthNotesController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Mention any chronic conditions, allergies, or '
                  'special care requirements...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This information will be visible to shared caregivers '
                    'in your family group to ensure synchronized care.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(errorMessage!,
                style: TextStyle(color: theme.colorScheme.error)),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Continue'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}