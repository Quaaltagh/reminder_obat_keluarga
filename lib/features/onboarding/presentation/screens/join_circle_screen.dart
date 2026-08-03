// Input kode undangan untuk join circle existing.
// Layar alur Member: "Saya Punya Kode Undangan" -> input kode (contoh: P-217264 atau 217264).
// Setelah submit, TIDAK langsung masuk circle — dibuat join request
// berstatus pending, lalu redirect ke waiting_approval_screen.dart
// untuk menunggu persetujuan Admin.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/user_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final rawCode = _codeController.text.trim();
    final cleanCode = rawCode.replaceAll(' ', '').replaceAll('-', '');

    if (cleanCode.length < 6) {
      setState(() => _errorMessage = 'Masukkan kode undangan yang valid (minimal 6 karakter).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final onboardingService = ref.read(onboardingServiceProvider);
    final currentUser = ref.read(currentUserProvider);

    if (currentUser == null) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Sesi login tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    final userId = currentUser.uid;
    final email = currentUser.email ?? '';

    try {
      debugPrint('🔵 [JOIN] Mencari circle dengan kode: $rawCode');

      final userRepo = ref.read(userRepositoryProvider);
      final appUser = await userRepo.getUser(userId);
      final displayName = appUser?.displayName ?? email;

      final circleId = await onboardingService.submitJoinRequestByCode(
        inviteCode: rawCode,
        userId: userId,
        displayName: displayName,
        email: email,
      );

      debugPrint('✅ [JOIN] Join request terkirim untuk circle: $circleId');

      if (mounted) {
        context.pushReplacementNamed(
          'waiting-approval',
          queryParameters: {'circleId': circleId},
        );
      }
    } catch (e) {
      debugPrint('🔴 [JOIN] Gagal: $e');
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
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Family Group',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect with your family to coordinate medication and '
                'care. Stay updated on doses and wellness together.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              const Text(
                'Enter Invite Code',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),

              // Code Input Field
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: primaryBlue,
                ),
                decoration: InputDecoration(
                  hintText: 'Contoh: P-217264 atau 217264',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 0,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: const Icon(Icons.qr_code_rounded, color: primaryBlue),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 8),
              Text(
                'Masukkan kode 6 digit atau kode berawalan P-/I-/V- dari Admin.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
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

              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}