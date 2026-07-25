// Input kode undangan untuk join circle existing. Pakai invites/{inviteCode}.
// Layar alur Member: "Saya Punya Kode Undangan" -> input 6 digit kode.
// Setelah submit, TIDAK langsung masuk circle — dibuat join request
// berstatus pending, lalu redirect ke waiting_approval_screen.dart
// untuk menunggu persetujuan Admin.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextEditingController> _digitControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _digitControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // refresh tombol Join Group (enabled/disabled)
  }

  Future<void> _handleJoin() async {
    final code = _enteredCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode undangan.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Ambil provider & data sebelum operasi async, mengikuti pola aman
    // yang sama seperti register_screen.dart dan create_circle_screen.dart.
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
      debugPrint('🔵 [JOIN] Mencari circle dengan kode: $code');

      // Ambil displayName dari Firestore (users/{uid}), bukan dari
      // Firebase Auth, karena Firebase Auth displayName biasanya null
      // untuk akun yang daftar via email/password (nama disimpan
      // terpisah di dokumen users/{uid} lewat UserRepository).
      final userRepo = ref.read(userRepositoryProvider);
      final appUser = await userRepo.getUser(userId);
      final displayName = appUser?.displayName ?? email;

      final circleId = await onboardingService.submitJoinRequestByCode(
        inviteCode: code,
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
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Connect with your family to coordinate medication and '
                'care. Stay updated on doses and wellness together.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),

              const Text('Enter Invite Code',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    height: 52,
                    child: TextField(
                      controller: _digitControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: theme.textTheme.titleLarge,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _onDigitChanged(index, value),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                'Ask the group administrator for the 6-digit invitation code.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleJoin,
                  style: ElevatedButton.styleFrom(
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
                      : const Text('Join Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}